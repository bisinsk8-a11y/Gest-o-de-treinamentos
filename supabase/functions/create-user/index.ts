const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Max-Age": "86400",
}

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  })
}

function authHeaders(apiKey: string, token: string, extra: Record<string, string> = {}) {
  return { apikey: apiKey, Authorization: `Bearer ${token}`, ...extra }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return reply(405, { error: "Método não permitido." })

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const apiKey = req.headers.get("apikey")
  const token = req.headers.get("Authorization")?.match(/^Bearer\s+(.+)$/i)?.[1]
  if (!supabaseUrl || !apiKey) return reply(503, { error: "Configuração do Supabase indisponível." })
  if (!token) return reply(401, { error: "Sessão ausente. Entre novamente." })

  try {
    const payload = await req.json()
    const nome = String(payload.nome || "").trim()
    const email = String(payload.email || "").trim().toLowerCase()
    const senha = String(payload.senha || "")
    const cargoId = String(payload.cargo_id || "")
    const setorId = String(payload.setor_id || "")
    if (!nome || nome.length > 50 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 255 || senha.length < 8 || senha.length > 128 || !cargoId || !setorId) {
      return reply(400, { error: "Informe nome, e-mail válido, senha com pelo menos 8 caracteres, cargo e setor." })
    }

    const authUserResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: authHeaders(apiKey, token),
    })
    if (!authUserResponse.ok) return reply(401, { error: "Sessão inválida ou expirada. Entre novamente." })

    const rlsHeaders = authHeaders(apiKey, token, { "Content-Type": "application/json" })
    const roleResponse = await fetch(`${supabaseUrl}/rest/v1/rpc/usuario_e_sst`, {
      method: "POST",
      headers: rlsHeaders,
      body: "{}",
    })
    if (!roleResponse.ok || await roleResponse.json() !== true) {
      return reply(403, { error: "Somente um usuário SST pode criar contas." })
    }

    for (const [table, id, label] of [["cargos", cargoId, "cargo"], ["setores", setorId, "setor"]]) {
      const query = new URLSearchParams({ id: `eq.${id}`, select: "id" })
      const response = await fetch(`${supabaseUrl}/rest/v1/${table}?${query}`, {
        headers: authHeaders(apiKey, token),
      })
      if (!response.ok) return reply(502, { error: "Não foi possível validar cargo e setor no Supabase." })
      if (!(await response.json()).length) return reply(400, { error: `O ${label} selecionado não existe.` })
    }

    const existingQuery = new URLSearchParams({ email: `eq.${email}`, select: "id" })
    const existingResponse = await fetch(`${supabaseUrl}/rest/v1/colaboradores?${existingQuery}`, {
      headers: authHeaders(apiKey, token),
    })
    if (!existingResponse.ok) return reply(502, { error: "Não foi possível verificar se o e-mail já está vinculado a um colaborador." })
    if ((await existingResponse.json()).length) return reply(409, { error: "Este e-mail já está cadastrado entre os colaboradores." })

    const signupUrl = new URL("/auth/v1/signup", supabaseUrl)
    const origin = req.headers.get("origin")
    if (origin) signupUrl.searchParams.set("redirect_to", origin)
    const createResponse = await fetch(signupUrl, {
      method: "POST",
      headers: { apikey: apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email, password: senha, data: { name: nome } }),
    })
    const created = await createResponse.json().catch(() => ({}))
    const createdUser = created.user || created
    if (!createResponse.ok || !createdUser.id || (Array.isArray(createdUser.identities) && createdUser.identities.length === 0)) {
      const text = [created.msg, created.message, created.error_description, created.error]
        .filter((value) => typeof value === "string").join(" ")
      const code = String(created.error_code || created.code || "")
      let message = text || "O Supabase recusou o cadastro sem informar o motivo. Confira os logs de Auth do projeto."
      if (/already|registered|exists/i.test(text) || /user_already_exists|email_exists/i.test(code) || (Array.isArray(createdUser.identities) && createdUser.identities.length === 0)) {
        message = "Este e-mail já está cadastrado no Supabase Auth."
      } else if (/signup.*disabled|registration.*disabled|not allowed for this instance/i.test(`${text} ${code}`)) {
        message = "O cadastro por e-mail e senha está desativado no Supabase. Ative-o em Authentication → Sign In / Providers → Email."
      } else if (/weak_password|password.*(weak|short|least)|password.*contain/i.test(`${text} ${code}`)) {
        message = `A senha não atende aos requisitos configurados no Supabase${text ? `: ${text}` : "."}`
      } else if (/invalid.*email|email.*invalid/i.test(`${text} ${code}`)) {
        message = "O Supabase considerou o endereço de e-mail inválido. Confira o formato e o domínio informado."
      } else if (/email_provider_disabled|provider.*disabled/i.test(`${text} ${code}`)) {
        message = "O provedor Email está desativado em Authentication → Sign In / Providers no Supabase."
      } else if (/over_email_send_rate_limit|email.*rate.?limit/i.test(`${text} ${code}`)) {
        message = "O limite de envio de e-mails do Supabase Auth foi atingido. Aguarde ou configure SMTP próprio em Authentication → SMTP Settings."
      } else if (createResponse.status === 429 || /over_request_rate_limit|rate.?limit|too many requests/i.test(`${text} ${code}`)) {
        message = "O limite de requisições do Supabase Auth foi atingido. Aguarde alguns minutos e confira Authentication → Rate Limits."
      } else if (text) {
        message = `O Supabase recusou o cadastro: ${text}`
      }
      return reply(createResponse.status === 429 ? 429 : createResponse.status === 422 ? 409 : 400, { error: message, code: code || undefined })
    }

    const profileResponse = await fetch(`${supabaseUrl}/rest/v1/colaboradores`, {
      method: "POST",
      headers: authHeaders(apiKey, token, { "Content-Type": "application/json", Prefer: "return=minimal" }),
      body: JSON.stringify({ auth_user_id: createdUser.id, nome, email, cargo_id: cargoId, setor_id: setorId }),
    })
    if (!profileResponse.ok) {
      const failure = await profileResponse.json().catch(() => ({}))
      const message = failure.code === "23505"
        ? "Este e-mail já está cadastrado entre os colaboradores."
        : "A conta Auth foi criada, mas o perfil não pôde ser vinculado. O SST deverá excluir a conta sem vínculo no painel Auth e tentar novamente."
      return reply(400, { error: message })
    }

    return reply(201, { ok: true, emailConfirmationRequired: !created.session })
  } catch (error) {
    return reply(400, { error: error instanceof Error ? error.message : "Não foi possível processar o cadastro." })
  }
})
