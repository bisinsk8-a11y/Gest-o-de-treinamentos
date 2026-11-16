# Publicar no GitHub Pages

O GitHub Pages publica os arquivos estáticos do site e não lê o `.env`. O workflow `.github/workflows/pages.yml` cria `config.js` durante a publicação usando variáveis do repositório.

## Publicar o site

1. Envie o projeto ao GitHub sem incluir `.env` (ele já está no `.gitignore`).
2. Em **Settings → Secrets and variables → Actions → Variables**, crie `SUPABASE_URL` com a URL do projeto e `SUPABASE_ANON_KEY` com a chave pública `anon` ou `publishable`.
3. Em **Settings → Pages**, escolha **GitHub Actions** como origem.
4. Em **Actions**, execute **Publicar no GitHub Pages**.
5. No Supabase Auth, adicione o endereço do Pages às URLs permitidas de redirecionamento.

A URL e a chave `anon`/publishable são públicas e ficam visíveis no navegador; use somente a chave pública. Nunca coloque `service_role` ou uma chave `secret` no Pages ou no código do navegador.

## Habilitar criação de usuários

O cadastro usa a Supabase Edge Function `create-user`, então não é preciso hospedar `server.js` no Render. A função valida a sessão e o perfil SST e usa as políticas RLS ao vincular o perfil do novo usuário. A verificação JWT da função deve permanecer ativada.

### Publicar a função pelo painel do Supabase

1. No seu computador, envie ao GitHub o arquivo `supabase/functions/create-user/index.ts`.
2. No Supabase, abra **Edge Functions** e crie uma função chamada `create-user`.
3. Cole o conteúdo de `supabase/functions/create-user/index.ts` no editor e clique em **Deploy updates**.
4. Confirme que o cadastro por e-mail e senha está habilitado em **Authentication → Sign In / Providers → Email**.
5. Teste a criação de um usuário pelo app, autenticado com uma conta SST.

O editor do painel serve para publicação rápida e não sincroniza automaticamente as alterações com o GitHub. Se o código da função mudar no repositório, publique a versão atualizada novamente pelo painel.

### Alternativa: publicar usando o Supabase CLI

Com Node.js 20 ou mais recente, abra o PowerShell na pasta do projeto e execute:

```powershell
npx supabase login
npx supabase link --project-ref SEU_PROJECT_REF
npx supabase functions deploy create-user
```

Encontre `SEU_PROJECT_REF` na URL do projeto Supabase: é a parte entre `https://` e `.supabase.co`. O deploy não exige chave `service_role` no navegador. A função recebe a chave pública e o JWT da sessão SST.

O Supabase inclui 500.000 invocações de Edge Functions no plano Free; excedentes não são cobrados nesse plano, conforme os limites atuais. [Cotas e cobrança de Edge Functions](https://supabase.com/docs/guides/functions/pricing). Instruções oficiais: [criar pelo painel](https://supabase.com/docs/guides/functions/quickstart-dashboard), [publicar pelo CLI](https://supabase.com/docs/guides/functions/deploy).

## Limite do cadastro de usuários

O cadastro seguro só funciona após implantar a Edge Function `create-user`. Não é preciso preencher `API_BASE` nem configurar um serviço externo de Node. A função usa o Supabase Auth para criar a conta e a sessão do SST, junto com RLS, para associar o perfil. Não substitua esse fluxo por cadastro direto no navegador: isso pode trocar a sessão do SST pela do novo usuário e impedir a associação protegida do perfil.

Para desenvolvimento local, configure `.env.example` em `.env` e execute `node server.js`.
