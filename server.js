// Servidor estatico e endpoints protegidos para provisionamento de contas.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
try {
  for (const line of fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
  }
} catch {}

const mime = { '.html':'text/html; charset=utf-8', '.css':'text/css; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.json':'application/json; charset=utf-8', '.svg':'image/svg+xml' };
const config = () => ({ url:process.env.SUPABASE_URL || '', anonKey:process.env.SUPABASE_ANON_KEY || '' });
function send(res, status, body) { res.writeHead(status, { 'Content-Type':'application/json; charset=utf-8', 'Cache-Control':'no-store' }); res.end(JSON.stringify(body)); }
const allowedOrigins = () => (process.env.CORS_ALLOWED_ORIGINS || '')
  .split(',').map(value => value.trim().replace(/\/$/, '')).filter(Boolean);
function applyCors(req, res) {
  const origin = req.headers.origin;
  if (!origin) return true;
  let normalized;
  try { normalized = new URL(origin).origin; } catch { return false; }
  const scheme = req.socket.encrypted ? 'https' : 'http';
  const sameOrigin = req.headers.host && normalized === `${scheme}://${req.headers.host}`;
  if (!sameOrigin && !allowedOrigins().includes(normalized)) return false;
  res.setHeader('Access-Control-Allow-Origin', normalized);
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');
  return true;
}
function userHeaders(anonKey, token, extra = {}) { return { apikey:anonKey, Authorization:`Bearer ${token}`, ...extra }; }
async function readJson(req) {
  let raw = '';
  for await (const chunk of req) { raw += chunk; if (raw.length > 12000) throw new Error('A requisição excede o limite permitido.'); }
  try { return JSON.parse(raw); } catch { throw new Error('Dados inválidos.'); }
}
async function createAppUser(req, res) {
  const base = config();
  if (!base.url || !base.anonKey) return send(res, 503, { error:'Configure SUPABASE_URL e SUPABASE_ANON_KEY no ambiente do servidor.' });
  const origin = req.headers.origin;
  const token = (req.headers.authorization || '').match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return send(res, 401, { error:'Sessão ausente. Entre novamente.' });
  try {
    const payload = await readJson(req);
    const nome = String(payload.nome || '').trim();
    const email = String(payload.email || '').trim().toLowerCase();
    const senha = String(payload.senha || '');
    const cargo_id = String(payload.cargo_id || '');
    const setor_id = String(payload.setor_id || '');
    if (!nome || nome.length > 50 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 255 || senha.length < 8 || senha.length > 128 || !cargo_id || !setor_id) {
      return send(res, 400, { error:'Informe nome, e-mail válido, senha com pelo menos 8 caracteres, cargo e setor.' });
    }

    const authUserRes = await fetch(`${base.url}/auth/v1/user`, { headers:{ apikey:base.anonKey, Authorization:`Bearer ${token}` } });
    if (!authUserRes.ok) return send(res, 401, { error:'Sessão inválida ou expirada. Entre novamente.' });
    const authUser = await authUserRes.json();
    const rlsHeaders = { apikey:base.anonKey, Authorization:`Bearer ${token}`, 'Content-Type':'application/json' };
    const roleRes = await fetch(`${base.url}/rest/v1/rpc/usuario_e_sst`, { method:'POST', headers:rlsHeaders, body:'{}' });
    if (!roleRes.ok || (await roleRes.json()) !== true) return send(res, 403, { error:'Somente um usuário SST pode criar contas.' });

    for (const [table, id] of [['cargos', cargo_id], ['setores', setor_id]]) {
      const check = await fetch(`${base.url}/rest/v1/${table}?id=eq.${encodeURIComponent(id)}&select=id`, { headers:userHeaders(base.anonKey, token) });
      if (!check.ok) return send(res, 502, { error:'Não foi possível validar cargo e setor no Supabase.' });
      const rows = await check.json();
      if (!rows.length) return send(res, 400, { error:`O ${table === 'cargos' ? 'cargo' : 'setor'} selecionado não existe.` });
    }
    const existingRes = await fetch(`${base.url}/rest/v1/colaboradores?email=eq.${encodeURIComponent(email)}&select=id`, { headers:userHeaders(base.anonKey, token) });
    if (!existingRes.ok) return send(res, 502, { error:'Não foi possível verificar se o e-mail já está vinculado a um colaborador.' });
    if ((await existingRes.json()).length) return send(res, 409, { error:'Este e-mail já está cadastrado entre os colaboradores.' });

    // Cadastro público padrão do Auth: sem chave administrativa e sem sessão para o SST.
    const signupUrl = new URL('/auth/v1/signup', base.url);
    if (origin) signupUrl.searchParams.set('redirect_to', origin);
    const createRes = await fetch(signupUrl, {
      method:'POST', headers:{ apikey:base.anonKey, 'Content-Type':'application/json' },
      body:JSON.stringify({ email, password:senha, data:{ name:nome } })
    });
    const created = await createRes.json().catch(() => ({}));
    const createdUser = created.user || created;
    if (!createRes.ok || !createdUser.id || (Array.isArray(createdUser.identities) && createdUser.identities.length === 0)) {
      const text = [created.msg, created.message, created.error_description, created.error]
        .filter(value => typeof value === 'string').join(' ');
      const errorCode = String(created.error_code || created.code || '');
      const message = /already|registered|exists|already been registered/i.test(text) || /user_already_exists|email_exists/i.test(errorCode) || (Array.isArray(createdUser.identities) && createdUser.identities.length === 0)
        ? 'Este e-mail já está cadastrado no Supabase Auth.'
        : /signup.*disabled|registration.*disabled|not allowed for this instance/i.test(`${text} ${errorCode}`)
          ? 'O cadastro por e-mail e senha está desativado no Supabase. Ative-o em Authentication → Sign In / Providers → Email.'
          : /weak_password|password.*(weak|short|least)|password.*contain/i.test(`${text} ${errorCode}`)
            ? `A senha não atende aos requisitos configurados no Supabase${text ? `: ${text}` : '.'}`
            : /invalid.*email|email.*invalid/i.test(`${text} ${errorCode}`)
              ? 'O Supabase considerou o endereço de e-mail inválido. Confira o formato e o domínio informado.'
              : /email_provider_disabled|provider.*disabled/i.test(`${text} ${errorCode}`)
                ? 'O provedor Email está desativado em Authentication → Sign In / Providers no Supabase.'
                : /over_email_send_rate_limit|email.*rate.?limit/i.test(`${text} ${errorCode}`)
                  ? 'O limite de envio de e-mails do Supabase Auth foi atingido. Aguarde a renovação do limite ou configure um SMTP próprio em Authentication → SMTP Settings.'
                  : createRes.status === 429 || /over_request_rate_limit|rate.?limit|too many requests/i.test(`${text} ${errorCode}`)
                    ? 'O limite de requisições do Supabase Auth foi atingido. Aguarde alguns minutos antes de criar outra conta e confira Authentication → Rate Limits.'
                  : text
                    ? `O Supabase recusou o cadastro: ${text}`
                    : 'O Supabase recusou o cadastro sem informar o motivo. Confira os logs de Auth do projeto.';
      const responseStatus = createRes.status === 429 ? 429 : createRes.status === 422 ? 409 : 400;
      return send(res, responseStatus, { error:message, code:errorCode || undefined });
    }

    const profileRes = await fetch(`${base.url}/rest/v1/colaboradores`, {
      method:'POST', headers:userHeaders(base.anonKey, token, { 'Content-Type':'application/json', Prefer:'return=minimal' }),
      body:JSON.stringify({ auth_user_id:createdUser.id, nome, email, cargo_id, setor_id })
    });
    if (!profileRes.ok) {
      const failure = await profileRes.json().catch(() => ({}));
      const message = failure.code === '23505' ? 'Este e-mail já está cadastrado entre os colaboradores.' : 'A conta Auth foi criada, mas o perfil não pôde ser vinculado. O SST deverá excluir a conta sem vínculo no painel Auth e tentar novamente.';
      return send(res, 400, { error:message });
    }
    return send(res, 201, { ok:true, emailConfirmationRequired:!created.session });
  } catch (error) {
    return send(res, 400, { error:error.message || 'Não foi possível processar o cadastro.' });
  }
}

const server = http.createServer(async (req, res) => {
  if (req.url === '/api/users' && (req.method === 'POST' || req.method === 'OPTIONS')) {
    if (!applyCors(req, res)) return send(res, 403, { error:'Origem não permitida.' });
    if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
  }
  if (req.url === '/config.js') { res.writeHead(200, { 'Content-Type':'text/javascript; charset=utf-8', 'Cache-Control':'no-store' }); return res.end(`window.APP_CONFIG=${JSON.stringify(config())};`); }
  if (req.url === '/api/users' && req.method === 'POST') return createAppUser(req, res);
  if (req.url.startsWith('/api/')) return send(res, 404, { error:'Endpoint não encontrado.' });
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405); return res.end('Método não permitido'); }
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); } catch { res.writeHead(400); return res.end('Requisição inválida'); }
  const target = path.resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
  if (!target.startsWith(root + path.sep) && target !== path.join(root, 'index.html')) { res.writeHead(403); return res.end('Acesso negado'); }
  fs.readFile(target, (err, data) => {
    if (err) { res.writeHead(404); return res.end('Arquivo não encontrado'); }
    res.writeHead(200, { 'Content-Type':mime[path.extname(target)] || 'application/octet-stream' });
    res.end(req.method === 'HEAD' ? undefined : data);
  });
});
const port = Number(process.env.PORT || 4173);
server.listen(port, () => console.log(`Gestão de Treinamentos disponível em http://localhost:${port}`));
