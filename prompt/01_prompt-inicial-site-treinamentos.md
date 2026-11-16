# Prompt inicial — site de finanças pessoais

Crie neste repositório um site funcional de gestão de treinamentos , usando como fontes de verdade:

- `docs/DESIGN_SISTEM.MD` — identidade visual, tipografia, espaçamento, componentes e temas.
- `supabase/schema.sql` — tabelas, colunas, regras de acesso, categorias iniciais e políticas RLS.

Antes de implementar, leia esses dois arquivos e inspecione a estrutura existente do projeto. Preserve os arquivos e decisões já existentes que forem compatíveis. Faça a implementação nos diretórios atuais (`index.html`, `css/`, `js/` e outros arquivos necessários), sem introduzir frameworks de aplicação ou ferramentas de build.

## Tecnologias e limites

- HTML semântico, CSS e JavaScript Vanilla.
- Tailwind CSS para a estilização, usando uma forma compatível com este projeto estático e documentando qualquer configuração necessária.
- Supabase JavaScript Client para autenticação e acesso ao banco.
- SweetAlert2 para confirmações, avisos e mensagens de sucesso ou erro.
- Lucide Icons para ícones; use a integração oficial apropriada para uma página estática e não use emojis como ícones.
- Não use React, Vue, Angular, TypeScript, jQuery ou bibliotecas de gráficos pesadas.
- Mantenha o código organizado em módulos/arquivos pequenos, com responsabilidades claras.

## Funcionalidades

o site deve funcionar como controle para os treinamentos legais dos colaboradores, deve indicar a validade verificando se a data em que o colaborador concluiu o treinamento esta dentro do periodo de validade estipulado para o treianemtno, se a data de conclusão for menor que a data de vencimento deve mostrar "Válido", quando faltar 60 dias ou menos para vencer deve indicar como "Á vencer" e quando ultrapasar a data deve indicar como "Vencido", para os status vencido e á vencer o sistema deve enviar uma notificação automatica ao supervisor responsavel por esse colaborador, a noticifação deve conter o nome do colaorador, os treinamentos que estao vencidos e qual a data em que venceram ou irão vencer, caso haja mais de um colaborador vencido o sistema deve indicar todos os vencidos na mesma notificação ao supervisor responsavel, os treinamentos vencidos e a vencer devem ser agrupados por supervisor, quando o treinamento estiver no status "Á vencer" enviar as notificações a cada 15 dias, uando um treinamento passar de "A vencer" para "Vencido", o ciclo de notificações deve mudar de 15 para 7 dias, as notificações devem ser enviadas ao email cadastrado do supervisor, caso o envio falhe, o sistema deverá registrar o erro e tentar enviar novamente, sem perder a notificação.
O sistema deve possuir funcionalidades como, caso um treinamento de um colaborador esteja vencido, o supervisor responsavel pode solicitar a atualização ao SST, na solicitação deve indicar qual o treinamento e o colaborador e anexar um arquivo PFD o JPG com o certificado do colaborador que deseja atualizar, o SST recebe a solicitação e verifica, o supervisor não deve conseguir alterar diretamente a validade do treinamento, o fluxo para atualização de um treinamento é essa (Supervisor identifica o treinamento vencido, Supervisor solicita  atualização, Anexa o certificado em PDF ou JPG e identifica o coalborador e treinamento vencido, SST recebe a solicitação, SST analisa o certificado, SST aprova ou reprova, Se aprovado, o treinamento é atualizado, Quando o SST aprovar um certificado, o sistema deverá registrar a nova data de conclusão informada no certificado e recalcular automaticamente o vencimento, se reprovado, o supervisor recebe uma notificação com o motivo da reprovação), quando um treinamento for atualizado, o sistema deverá manter o certificado anterior, sem apagá-lo, registrando o histórico de atualizações. 
Os usuarios devem ter pemissão para executar ação de acordo com seu nivel de authenticação (SST, Supervisor, RH e colaborador).
SST - pode criar treinamentos e definir o periodo de validade de cada um deles, lançar novos colaboradores, modificar todos independente do setor, deve receber as solicitações de atualização de treinamento enviada pelo supervisor e verificar os certificados enviados para analise, caso esteja valido o treinamento do colaborador sera atualizado para valido, caso o cerficado nao esteja conforme o certificado sera negado e enviado notificação ao supervisor responsavel, SST é o unico com permissão para criar novos usuarios.
Supervisores - os usuarios supervisores podem possuir mais de um setor, lançar novos colaboradores de sua responsabilidade (só pode cadastrar colaboradores nos setores pelos quais é responsável), solicitar atualização de treinamentos vencidos e receber notificação de colaboradors com treinamento vencido, cada supervisor recebe somente notificações dos colaboradores sob sua responsabilidade,  um supervisor não pode modificar um treinamento acessando diretamente uma URL ou tentando executar uma ação reservada ao SST
RH - pode visualizar os colaboradores e treinamentos de todos os setores mas nao pode alterar nada
Colaborador - pode visualizar os colaboradores e treinamentos de seu setor mas nao pode alterar nada


### Acesso e sessão

- Criar uma tela de login com email e senha, além de opção para criar conta e recuperar senha.
- Usar Supabase Auth. Manter a sessão com o cliente oficial e permitir sair da conta.
- Exibir erros de autenticação em português, de forma clara e acessível.
- Enquanto não houver sessão, mostrar apenas a área de acesso; após autenticar, abrir o dashboard.
- Não inventar autenticação local nem armazenar senhas manualmente.

### colaboradores

- Consultar, cadastrar, editar e excluir colaboradores da tabela `public.colaboradores`.
- Campos: tipo (`nome` ,`email`, `cargo_id` e `setor_id`), descrição, emails, qual cargo e qual o setor
- Filtrar a lista por período, tipo e categoria; ordenar pela data mais recente e oferecer estados vazios e de carregamento.
- Exibir datas em formato brasileiro, sem perder a precisão decimal dos valores persistidos.
- Validar os dados no formulário antes de enviar e confirmar exclusões com SweetAlert2.
- Atualizar os dados visíveis após criar, editar ou excluir um lançamento.

### Categorias

- Listar categorias visíveis por nivel de segurança definidos em `supabase/schema.sql`
- Permitir cadastrar, editar e excluir categorias por nivel de segurança definidos em `supabase/schema.sql`
- Validar nome não vazio e tipo nome, email, cargo_id e setor_id. Tratar nomes duplicados e erros de restrição com mensagens amigáveis.
- Ao cadastrar ou editar um lançamento, permitir somente categorias compatíveis com o seu tipo.
- Se uma categoria for excluída, respeitar o comportamento do schema: o lançamento relacionado pode ficar com `categoria_id` nula.

### Dashboard

- Criar uma visão inicial com colaboradores que realizaram treinamentos, total de validos, total de vencidos e total de a vencer.
- Permitir selecionar mês/período e calcular os indicadores de vencidos, a vencer e validos.
- Mostrar lançamentos recentes e um resumo de por categoria de treinamento. O resumo deve ter alternativa textual acessível e se adaptar quando não houver dados.
- Explicitar o período selecionado e definir com clareza quais tabelas estão sendo comparadas.

## Design e experiência

- Siga `docs/DESIGN_SISTEM.MD`: paleta vermelho e preto, Poppins para títulos, Inter para textos, grid de 8 px, raios, cartões e contraste definidos.
- Implementar modo claro e escuro aplicando/removendo `dark` no elemento `<html>`, guardar a preferência do usuário e aplicar o mesmo tema ao SweetAlert2.
- Criar layout responsivo para celular e desktop, com navegação clara entre Dashboard, Lançamentos e Categorias.
- Usar rótulos visíveis, foco de teclado, estados de foco/erro, mensagens compreensíveis e estrutura semântica. Não depender só de cor para transmitir estado.
- Usar Lucide Icons com rótulo acessível ou `aria-hidden="true"` quando decorativos.
- Evitar conteúdo de demonstração disfarçado de dado real. Se usar dados de exemplo durante o desenvolvimento, isolá-los e deixar claro como removê-los.

# Instruções para o site de gestão de treinamentos

## Supabase e segurança

- Leia `supabase/schema.sql` antes de implementar consultas ou mutações. Use o schema como fonte de verdade para tabelas, colunas, tipos e regras de acesso.
- Use apenas a URL do projeto Supabase e a chave pública `anon`/publishable no frontend. Nunca exponha `service_role`, segredos ou credenciais privilegiadas.
- Não enfraqueça nem contorne as políticas RLS. Faça operações com o usuário autenticado e trate falhas de rede, sessão expirada e permissões negadas.
- A conta autenticada é associada ao registro em `public.colaboradores` pela coluna `auth_user_id`. Não use `usuario_id`: essa coluna não existe neste schema.
- Não confie em valores enviados pelo navegador para determinar setor, cargo ou permissão. A RLS aplica a autorização no banco; não tente contorná-la com credenciais privilegiadas.

## Tabelas e permissões

- Use estas tabelas: `cargos`, `setores`, `colaboradores`, `treinamentos` e `colaboradores_treinamentos`.
- As colunas disponíveis estão definidas em `supabase/schema.sql`. Entre elas estão `colaboradores.auth_user_id`, `colaboradores.cargo_id`, `colaboradores.setor_id`, `treinamentos.treinamento`, `treinamentos.validade_meses`, `colaboradores_treinamentos.colaborador_id`, `colaboradores_treinamentos.treinamento_id` e `colaboradores_treinamentos.data_conclusao`. Não invente colunas como `categoria_id`, `usuario_id`, `carga_inicial`, `tipo`, `descricao`, `valor` ou `data_lancamento`.
- Usuários do setor SST podem consultar, incluir, alterar e excluir registros em todas as tabelas.
- Supervisores podem incluir colaboradores somente no próprio setor. A política também impede que atribuam cargo de supervisor nessa inclusão. Supervisores não podem alterar nem excluir registros.
- Usuários não supervisores podem consultar colaboradores, treinamentos e conclusões, sem incluí-los, alterá-los ou excluí-los.
- Usuários do setor Recursos Humanos podem consultar colaboradores, treinamentos e conclusões de qualquer setor, sem permissão de escrita por essa função.
- Cargos e setores podem ser consultados por usuários autenticados; somente SST pode alterá-los.
- Em operações de alteração e exclusão, filtre também pelo ID do registro pretendido. Deixe a autorização final para a RLS.
- Para associar um novo usuário Auth a um colaborador, use `auth_user_id` correspondente ao ID de `auth.users`. Não permita que o usuário escolha ou altere o vínculo de outra conta pelo frontend.

## Configuração do frontend

- Centralize a inicialização e a configuração do Supabase. Use `SUPABASE_URL` e `SUPABASE_ANON_KEY` em um `.env` local, forneça um `.env.example` sem valores reais e garanta que `.env` esteja no `.gitignore`.
- O navegador não lê arquivos `.env`. Não tente carregá-lo com `fetch` nem inclua os valores diretamente no JavaScript versionado. Sem adicionar framework ou ferramenta de build, disponibilize a configuração pública em tempo de execução por um mecanismo simples, como um servidor local que leia o `.env` e entregue um `config.js` gerado.
- Documente como fornecer as mesmas variáveis no ambiente de hospedagem.
- A URL e a chave `anon`/publishable são públicas por definição e ficarão visíveis no navegador. O `.env` organiza a configuração, mas não torna essas variáveis secretas. Nunca exponha a chave `service_role` ou qualquer segredo no cliente.

## Entrega

Implemente a aplicação completa, não apenas um mockup. Inclua instruções para copiar `.env.example` para `.env`, configurar `SUPABASE_URL` e `SUPABASE_ANON_KEY`, aplicar o schema no projeto Supabase e iniciar o servidor local necessário para servir a página e sua configuração pública. Ao concluir, resuma os arquivos criados/alterados, as funcionalidades entregues e qualquer configuração manual ainda necessária. Não altere o schema ou crie tabelas/políticas adicionais sem uma necessidade concreta identificada na implementação.