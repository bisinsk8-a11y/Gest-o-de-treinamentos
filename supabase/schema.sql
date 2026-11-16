-- Estrutura e controle de acesso do sistema de treinamentos.
-- Execute em um projeto Supabase novo ou adapte os dados existentes antes de aplicar.

create table public.cargos (
    id uuid primary key default gen_random_uuid(),
    nome varchar(50) not null unique,
    supervisor boolean not null default false,
    criado_em timestamptz not null default now()
);

insert into public.cargos (nome, supervisor) values
    ('Analista', false),
    ('Coordenador', true),
    ('Gerente', true),
    ('Diretor', true)
on conflict (nome) do update set supervisor = excluded.supervisor;

create table public.setores (
    id uuid primary key default gen_random_uuid(),
    nome varchar(50) not null unique,
    criado_em timestamptz not null default now()
);

insert into public.setores (nome) values
    ('SST'),
    ('Recursos Humanos'),
    ('Tecnologia da Informação'),
    ('Produção IPG'),
    ('Produção RCH'),
    ('ADM RCH'),
    ('ADM IPG'),
    ('Elétrica'),
    ('Manutenção'),
    ('Expedição'),
    ('Logística'),
    ('Uilidades'),
    ('Facilite');

on conflict (nome) do nothing;

create table public.colaboradores (
    id uuid primary key default gen_random_uuid(),
    auth_user_id uuid unique references auth.users(id) on delete set null,
    nome varchar(50) not null,
    email varchar(255) unique not null,
    cargo_id uuid not null references public.cargos(id),
    setor_id uuid not null references public.setores(id),
    criado_em timestamptz not null default now()
);

create table public.treinamentos (
    id uuid primary key default gen_random_uuid(),
    treinamento varchar(50) not null,
    validade_meses integer not null check (validade_meses >= 0),
    criado_em timestamptz not null default now()
);

create table public.colaboradores_treinamentos (
    id uuid primary key default gen_random_uuid(),
    colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
    treinamento_id uuid not null references public.treinamentos(id) on delete cascade,
    data_conclusao date,
    criado_em timestamptz not null default now(),
    unique (colaborador_id, treinamento_id)
);

-- Vincula a conta existente do Supabase Auth ao setor SST.
-- Nome e e-mail são obtidos do cadastro Auth; o cargo inicial é Analista.
insert into public.colaboradores (
    auth_user_id,
    nome,
    email,
    cargo_id,
    setor_id
)
select
    u.id,
    coalesce(
        nullif(u.raw_user_meta_data ->> 'name', ''),
        nullif(u.raw_user_meta_data ->> 'full_name', ''),
        split_part(coalesce(u.email, u.raw_user_meta_data ->> 'email'), '@', 1)
    ),
    coalesce(u.email, u.raw_user_meta_data ->> 'email'),
    ca.id,
    s.id
from auth.users as u
join public.cargos as ca on ca.nome = 'Analista'
join public.setores as s on s.nome = 'SST'
where u.id = '5be40e12-577c-4a09-a9d2-e8edc41c5faf'::uuid
on conflict (auth_user_id) do update
set setor_id = excluded.setor_id,
    cargo_id = excluded.cargo_id;

-- Estas funções consultam o perfil do usuário sem depender das políticas RLS
-- das tabelas de cadastro. O search_path fixo evita resolução insegura de objetos.
create or replace function public.usuario_setor_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select c.setor_id
    from public.colaboradores as c
    where c.auth_user_id = (select auth.uid())
    limit 1
$$;

create or replace function public.usuario_e_sst()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.colaboradores as c
        join public.setores as s on s.id = c.setor_id
        where c.auth_user_id = (select auth.uid())
          and s.nome = 'SST'
    )
$$;

create or replace function public.usuario_e_rh()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.colaboradores as c
        join public.setores as s on s.id = c.setor_id
        where c.auth_user_id = (select auth.uid())
          and s.nome = 'Recursos Humanos'
    )
$$;

create or replace function public.usuario_e_supervisor()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.colaboradores as c
        join public.cargos as ca on ca.id = c.cargo_id
        where c.auth_user_id = (select auth.uid())
          and ca.supervisor
    )
$$;

revoke all on function public.usuario_setor_id() from public;
revoke all on function public.usuario_e_sst() from public;
revoke all on function public.usuario_e_rh() from public;
revoke all on function public.usuario_e_supervisor() from public;
grant execute on function public.usuario_setor_id() to authenticated;
grant execute on function public.usuario_e_sst() to authenticated;
grant execute on function public.usuario_e_rh() to authenticated;
grant execute on function public.usuario_e_supervisor() to authenticated;

alter table public.cargos enable row level security;
alter table public.setores enable row level security;
alter table public.colaboradores enable row level security;
alter table public.treinamentos enable row level security;
alter table public.colaboradores_treinamentos enable row level security;

-- Leitura dos cadastros de apoio para usuários autenticados; somente SST grava.
create policy "Usuarios autenticados podem ler cargos"
on public.cargos for select to authenticated
using (true);

create policy "SST gerencia cargos"
on public.cargos for all to authenticated
using ((select public.usuario_e_sst()))
with check ((select public.usuario_e_sst()));

create policy "Usuarios autenticados podem ler setores"
on public.setores for select to authenticated
using (true);

create policy "SST gerencia setores"
on public.setores for all to authenticated
using ((select public.usuario_e_sst()))
with check ((select public.usuario_e_sst()));

-- Colaboradores: SST tem acesso total; RH e demais perfis vinculados podem ler.
create policy "Usuarios autorizados podem visualizar colaboradores"
on public.colaboradores for select to authenticated
using (
    (select public.usuario_e_sst())
    or (select public.usuario_e_rh())
    or (select public.usuario_setor_id()) is not null
);

create policy "SST ou supervisor pode incluir colaborador"
on public.colaboradores for insert to authenticated
with check (
    (select public.usuario_e_sst())
    or (
        (select public.usuario_e_supervisor())
        and setor_id = (select public.usuario_setor_id())
        and auth_user_id is null
        and not coalesce((
            select ca.supervisor
            from public.cargos as ca
            where ca.id = cargo_id
        ), true)
    )
);

create policy "Somente SST pode alterar colaboradores"
on public.colaboradores for update to authenticated
using ((select public.usuario_e_sst()))
with check ((select public.usuario_e_sst()));

create policy "Somente SST pode excluir colaboradores"
on public.colaboradores for delete to authenticated
using ((select public.usuario_e_sst()));

-- Treinamentos: leitura para todos os usuários com perfil; escrita somente SST.
create policy "Usuarios vinculados podem visualizar treinamentos"
on public.treinamentos for select to authenticated
using (
    (select public.usuario_e_sst())
    or (select public.usuario_e_rh())
    or (select public.usuario_setor_id()) is not null
);

create policy "SST gerencia treinamentos"
on public.treinamentos for all to authenticated
using ((select public.usuario_e_sst()))
with check ((select public.usuario_e_sst()));

-- Registros de conclusão seguem as mesmas permissões de leitura e escrita.
create policy "Usuarios vinculados podem visualizar conclusoes"
on public.colaboradores_treinamentos for select to authenticated
using (
    (select public.usuario_e_sst())
    or (select public.usuario_e_rh())
    or (select public.usuario_setor_id()) is not null
);

create policy "SST gerencia conclusoes"
on public.colaboradores_treinamentos for all to authenticated
using ((select public.usuario_e_sst()))
with check ((select public.usuario_e_sst()));

-- O app precisa conceder privilégios SQL além das políticas RLS.
grant select on public.cargos, public.setores, public.colaboradores,
    public.treinamentos, public.colaboradores_treinamentos to authenticated;
grant insert, update, delete on public.cargos, public.setores,
    public.colaboradores, public.treinamentos,
    public.colaboradores_treinamentos to authenticated;
