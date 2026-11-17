# Gestão de Treinamentos

## 1. Nome do projeto

**Gestão de Treinamentos** — aplicação web para acompanhar treinamentos obrigatórios e certificados dos colaboradores.

## 2. Problema identificado

O controle de treinamentos feito sem uma ferramenta central dificulta acompanhar quem concluiu cada capacitação e quando ela vence. Isso pode atrasar renovações, dificultar a conferência de certificados e deixar supervisores e SST sem uma visão clara das pendências.

## 3. Objetivo da aplicação

Centralizar os dados de colaboradores, treinamentos, conclusões e certificados; calcular a validade das capacitações; e organizar o acompanhamento de vencimentos e as solicitações de atualização entre supervisores e a equipe de Segurança e Saúde do Trabalho (SST).

## 4. Integrantes do grupo

- **Gabriel Bisin Stecca**
- **Gabriel de Lima Fusquini**
- **Joel Gonçalves Pereira**
- **Paulo Ricardo Fogaça Proença**

## 5. Tecnologias utilizadas

- HTML5, CSS3 e JavaScript (Vanilla).
- Tailwind CSS para estilos e layout responsivo.
- Supabase: PostgreSQL, Auth, políticas de segurança RLS, Storage e Edge Functions.
- Supabase JavaScript Client para autenticação e acesso aos serviços.
- SweetAlert2 para alertas e confirmações.
- Lucide para ícones.
- Node.js para executar o servidor local.
- GitHub Actions e GitHub Pages para publicação.

## 6. Principais funcionalidades

- Login, sessão, recuperação de senha e encerramento de sessão pelo Supabase Auth.
- Painel com totais, conclusões recentes e treinamentos próximos do vencimento ou vencidos.
- Cadastro e consulta de colaboradores, treinamentos, cargos, setores e conclusões, conforme o perfil de acesso.
- Cálculo da validade de cada treinamento a partir da data de conclusão e do período de validade cadastrado.
- Criação de contas pelo SST, associadas a um cargo, setor e perfil de colaborador.
- Solicitação de atualização de treinamento pelo supervisor, com envio de certificado PDF ou JPG.
- Análise, aprovação ou reprovação das solicitações pelo SST, com registro da decisão.
- Notificações internas sobre solicitações e vencimentos.
- Armazenamento privado de certificados e links temporários para consulta autorizada.
- Interface responsiva e opção de tema claro ou escuro.

## 7. Instruções básicas de utilização

### Acessar a aplicação

Abra o [site publicado no GitHub Pages](https://bisinsk8-a11y.github.io/Gest-o-de-treinamentos/). Entre com uma conta previamente criada e vinculada a um perfil no Supabase. O acesso não é aberto para cadastro público.

### Utilizar as funções principais

1. Entre com seu e-mail e senha.
2. No painel, consulte os indicadores e navegue pelas opções disponíveis ao seu perfil.
3. O SST pode gerenciar cadastros e, em **Colaboradores → Criar usuário**, criar contas para novos usuários.
4. O supervisor pode acompanhar treinamentos da sua responsabilidade e solicitar ao SST a atualização de um treinamento, anexando o certificado.
5. O SST analisa as solicitações e aprova ou reprova os certificados enviados.

As permissões são aplicadas pelas políticas RLS do Supabase. Para habilitar a criação de contas, a Edge Function de cadastro também precisa estar publicada no Supabase. Consulte [docs/PUBLICAR_GITHUB_PAGES.md](docs/PUBLICAR_GITHUB_PAGES.md) para configurar e publicar o projeto.

Não envie `.env` ao GitHub. Nunca use uma chave `service_role` ou `secret` no navegador.

## 8. Links

- [Aplicação publicada no GitHub Pages](https://bisinsk8-a11y.github.io/Gest-o-de-treinamentos/)
- [Repositório no GitHub](https://github.com/bisinsk8-a11y/Gest-o-de-treinamentos)
