-- Fluxo de solicitacao, analise de certificado e alertas de validade.
-- Requer as tabelas e funcoes de supabase/schema.sql e o bucket privado "certificados".

create table public.supervisores_setores (
    supervisor_id uuid not null references public.colaboradores(id) on delete cascade,
    setor_id uuid not null references public.setores(id) on delete cascade,
    criado_em timestamptz not null default now(),
    primary key (supervisor_id, setor_id)
);

create table public.solicitacoes_treinamento (
    id uuid primary key default gen_random_uuid(),
    colaborador_id uuid not null references public.colaboradores(id) on delete cascade,
    treinamento_id uuid not null references public.treinamentos(id) on delete cascade,
    supervisor_id uuid not null references public.colaboradores(id),
    certificado_path text not null,
    data_conclusao_informada date not null,
    status text not null default 'rascunho' check (status in ('rascunho','pendente','aprovada','reprovada')),
    motivo_reprovacao text,
    analisado_por uuid references public.colaboradores(id),
    analisado_em timestamptz,
    criado_em timestamptz not null default now(),
    constraint motivo_reprovacao_obrigatorio check (status <> 'reprovada' or nullif(trim(motivo_reprovacao),'') is not null),
    constraint caminho_certificado_da_solicitacao check (certificado_path in (id::text || '/certificado.pdf', id::text || '/certificado.jpg'))
);
create unique index uma_solicitacao_aberta_por_treinamento
    on public.solicitacoes_treinamento (colaborador_id, treinamento_id)
    where status in ('rascunho','pendente');
create index solicitacoes_status_criado_idx on public.solicitacoes_treinamento (status, criado_em desc);
create index solicitacoes_supervisor_idx on public.solicitacoes_treinamento (supervisor_id, criado_em desc);

create table public.notificacoes (
    id uuid primary key default gen_random_uuid(),
    destinatario_id uuid not null references public.colaboradores(id) on delete cascade,
    tipo text not null check (tipo in ('vencimentos','solicitacao','resultado')),
    titulo text not null,
    mensagem text not null,
    dados jsonb not null default '[]'::jsonb,
    chave_deduplicacao text unique,
    lida_em timestamptz,
    criado_em timestamptz not null default now()
);
create index notificacoes_destinatario_criado_idx on public.notificacoes (destinatario_id, criado_em desc);

create or replace function public.usuario_colaborador_id()
returns uuid language sql stable security definer set search_path = ''
as $$ select c.id from public.colaboradores c where c.auth_user_id = (select auth.uid()) limit 1 $$;

create or replace function public.supervisor_responde_setor(p_setor_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from public.supervisores_setores ss
        join public.colaboradores c on c.id = ss.supervisor_id
        join public.cargos ca on ca.id = c.cargo_id
        where ss.supervisor_id = (select public.usuario_colaborador_id())
          and ss.setor_id = p_setor_id and ca.supervisor
    )
$$;

revoke all on function public.usuario_colaborador_id() from public;
revoke all on function public.supervisor_responde_setor(uuid) from public;
grant execute on function public.usuario_colaborador_id() to authenticated;
grant execute on function public.supervisor_responde_setor(uuid) to authenticated;

alter table public.supervisores_setores enable row level security;
alter table public.solicitacoes_treinamento enable row level security;
alter table public.notificacoes enable row level security;

create policy "SST gerencia responsaveis por setor"
on public.supervisores_setores for all to authenticated
using ((select public.usuario_e_sst()))
with check (
    (select public.usuario_e_sst())
    and exists (
        select 1 from public.colaboradores c join public.cargos ca on ca.id = c.cargo_id
        where c.id = supervisor_id and ca.supervisor
    )
);
create policy "Supervisor consulta seus setores"
on public.supervisores_setores for select to authenticated
using (supervisor_id = (select public.usuario_colaborador_id()));

create policy "SST consulta todas as solicitacoes"
on public.solicitacoes_treinamento for select to authenticated
using ((select public.usuario_e_sst()));
create policy "Supervisor consulta suas solicitacoes"
on public.solicitacoes_treinamento for select to authenticated
using (supervisor_id = (select public.usuario_colaborador_id()));
create policy "Supervisor abre solicitacao no setor responsavel"
on public.solicitacoes_treinamento for insert to authenticated
with check (
    supervisor_id = (select public.usuario_colaborador_id())
    and status = 'rascunho'
    and exists (
        select 1 from public.colaboradores c
        join public.colaboradores_treinamentos ct on ct.colaborador_id = c.id and ct.treinamento_id = solicitacoes_treinamento.treinamento_id
        join public.treinamentos t on t.id = ct.treinamento_id
        where c.id = solicitacoes_treinamento.colaborador_id and (select public.supervisor_responde_setor(c.setor_id))
          and ct.data_conclusao is not null and t.validade_meses > 0
          and (ct.data_conclusao + make_interval(months => t.validade_meses))::date < current_date
    )
);
create policy "Supervisor envia sua solicitacao"
on public.solicitacoes_treinamento for update to authenticated
using (supervisor_id = (select public.usuario_colaborador_id()) and status = 'rascunho')
with check (supervisor_id = (select public.usuario_colaborador_id()) and status = 'pendente');
create policy "SST analisa solicitacoes"
on public.solicitacoes_treinamento for update to authenticated
using ((select public.usuario_e_sst()))
with check ((select public.usuario_e_sst()));
create policy "Supervisor descarta rascunho"
on public.solicitacoes_treinamento for delete to authenticated
using (supervisor_id = (select public.usuario_colaborador_id()) and status = 'rascunho');

create policy "Usuario consulta suas notificacoes"
on public.notificacoes for select to authenticated
using (destinatario_id = (select public.usuario_colaborador_id()));
grant select, insert, update, delete on public.supervisores_setores to authenticated;
grant select, insert, update, delete on public.solicitacoes_treinamento to authenticated;
grant select on public.notificacoes to authenticated;

create or replace function public.marcar_notificacao_lida(p_notificacao_id uuid)
returns void language sql security definer set search_path = ''
as $$
    update public.notificacoes
       set lida_em = now()
     where id = p_notificacao_id
       and destinatario_id = (select public.usuario_colaborador_id())
       and lida_em is null
$$;
revoke all on function public.marcar_notificacao_lida(uuid) from public;
grant execute on function public.marcar_notificacao_lida(uuid) to authenticated;

create or replace function public.aplicar_decisao_solicitacao()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
    if old.status = 'rascunho' and new.status not in ('rascunho','pendente') then
        raise exception 'O rascunho so pode ser enviado para analise.';
    elsif old.status = 'rascunho' and new.status = 'pendente'
       and (new.colaborador_id, new.treinamento_id, new.supervisor_id, new.certificado_path, new.data_conclusao_informada)
           is distinct from
           (old.colaborador_id, old.treinamento_id, old.supervisor_id, old.certificado_path, old.data_conclusao_informada) then
        raise exception 'Os dados da solicitacao nao podem ser alterados durante o envio.';
    elsif old.status = 'rascunho' and new.status = 'pendente'
       and not exists (select 1 from storage.objects o where o.bucket_id = 'certificados' and o.name = new.certificado_path) then
        raise exception 'Envie o certificado antes de enviar a solicitacao para analise.';
    elsif old.status = 'pendente' and new.status not in ('pendente','aprovada','reprovada') then
        raise exception 'A solicitacao pendente so pode ser aprovada ou reprovada.';
    elsif old.status in ('aprovada','reprovada') and new.status <> old.status then
        raise exception 'A decisao da solicitacao nao pode ser alterada.';
    end if;
    if old.status = 'pendente' and new.status in ('aprovada','reprovada') then
        new.analisado_por := (select public.usuario_colaborador_id());
        new.analisado_em := now();
        if new.status = 'aprovada' then
            insert into public.colaboradores_treinamentos (colaborador_id, treinamento_id, data_conclusao)
            values (new.colaborador_id, new.treinamento_id, new.data_conclusao_informada)
            on conflict (colaborador_id, treinamento_id)
            do update set data_conclusao = excluded.data_conclusao;
            new.motivo_reprovacao := null;
        elsif nullif(trim(new.motivo_reprovacao),'') is null then
            raise exception 'Informe o motivo da reprovacao.';
        end if;
    end if;
    return new;
end
$$;
create trigger solicitacao_aplicar_decisao
before update on public.solicitacoes_treinamento
for each row execute function public.aplicar_decisao_solicitacao();
revoke all on function public.aplicar_decisao_solicitacao() from public, anon, authenticated;

create or replace function public.notificar_solicitacao()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
    v_colaborador text;
    v_treinamento text;
    v_supervisor text;
begin
    select nome into v_colaborador from public.colaboradores where id = new.colaborador_id;
    select treinamento into v_treinamento from public.treinamentos where id = new.treinamento_id;
    select nome into v_supervisor from public.colaboradores where id = new.supervisor_id;
    if new.status = 'pendente' and (tg_op = 'INSERT' or old.status = 'rascunho') then
        insert into public.notificacoes (destinatario_id,tipo,titulo,mensagem,dados)
        select c.id,'solicitacao','Certificado aguardando analise',
               v_supervisor || ' enviou certificado de ' || v_colaborador || ' para ' || v_treinamento || '.',
               jsonb_build_object('solicitacao_id',new.id,'colaborador_id',new.colaborador_id,'treinamento_id',new.treinamento_id)
          from public.colaboradores c join public.setores s on s.id = c.setor_id
         where s.nome = 'SST';
    elsif tg_op = 'UPDATE' and old.status = 'pendente' and new.status in ('aprovada','reprovada') then
        insert into public.notificacoes (destinatario_id,tipo,titulo,mensagem,dados)
        values (
            new.supervisor_id, 'resultado',
            case when new.status = 'aprovada' then 'Certificado aprovado' else 'Certificado reprovado' end,
            case when new.status = 'aprovada'
                 then 'O SST aprovou o certificado de ' || v_colaborador || ' para ' || v_treinamento || '.'
                 else 'O SST reprovou o certificado de ' || v_colaborador || ' para ' || v_treinamento || '. Motivo: ' || new.motivo_reprovacao end,
            jsonb_build_object('solicitacao_id',new.id,'status',new.status,'motivo',new.motivo_reprovacao)
        );
    end if;
    return new;
end
$$;
create trigger solicitacao_notificar
after insert or update of status on public.solicitacoes_treinamento
for each row execute function public.notificar_solicitacao();
revoke all on function public.notificar_solicitacao() from public, anon, authenticated;

create or replace function public._gerar_alerta_vencimentos(p_supervisor_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
    v_itens jsonb;
    v_total integer;
begin
    select jsonb_agg(jsonb_build_object(
        'colaborador_id', c.id, 'colaborador', c.nome,
        'treinamento_id', t.id, 'treinamento', t.treinamento,
        'vencimento', (ct.data_conclusao + make_interval(months => t.validade_meses))::date,
        'status', case when (ct.data_conclusao + make_interval(months => t.validade_meses))::date < current_date then 'Vencido' else 'A vencer' end
    ) order by (ct.data_conclusao + make_interval(months => t.validade_meses))::date, c.nome), count(*)
      into v_itens, v_total
      from public.supervisores_setores ss
      join public.colaboradores sup on sup.id = ss.supervisor_id
      join public.cargos sup_cargo on sup_cargo.id = sup.cargo_id and sup_cargo.supervisor
      join public.colaboradores c on c.setor_id = ss.setor_id
      join public.colaboradores_treinamentos ct on ct.colaborador_id = c.id
      join public.treinamentos t on t.id = ct.treinamento_id
     where ss.supervisor_id = p_supervisor_id
       and ct.data_conclusao is not null and t.validade_meses > 0
       and (ct.data_conclusao + make_interval(months => t.validade_meses))::date <= current_date + 30;
    if coalesce(v_total,0) = 0 then return; end if;
    insert into public.notificacoes (destinatario_id,tipo,titulo,mensagem,dados,chave_deduplicacao)
    values (p_supervisor_id,'vencimentos','Treinamentos que exigem atencao',
            v_total || ' treinamento(s) vencido(s) ou a vencer nos setores sob sua responsabilidade.',
            v_itens,'vencimentos:' || p_supervisor_id::text || ':' || current_date::text)
    on conflict (chave_deduplicacao) do update
       set mensagem = excluded.mensagem, dados = excluded.dados;
end
$$;

create or replace function public.notificar_vencimentos_usuario()
returns void language plpgsql security definer set search_path = ''
as $$
declare v_id uuid := (select public.usuario_colaborador_id());
begin
    if not (select public.usuario_e_supervisor()) or v_id is null then
        raise exception 'Apenas supervisores podem gerar seus alertas de vencimento.';
    end if;
    perform public._gerar_alerta_vencimentos(v_id);
end
$$;
revoke all on function public._gerar_alerta_vencimentos(uuid) from public, authenticated;
revoke all on function public.notificar_vencimentos_usuario() from public;
grant execute on function public.notificar_vencimentos_usuario() to authenticated;

-- Alertas por data, agrupados uma vez por dia para cada supervisor.
do $enable_cron$
begin
    begin
        create extension if not exists pg_cron with schema pg_catalog;
        if not exists (select 1 from cron.job where jobname = 'notificar-vencimentos-treinamentos') then
            perform cron.schedule(
                'notificar-vencimentos-treinamentos',
                '0 11 * * *',
                $$ select public._gerar_alerta_vencimentos(ss.supervisor_id)
                     from (select distinct supervisor_id from public.supervisores_setores) ss $$
            );
        end if;
    exception when others then
        raise warning 'pg_cron nao foi configurado (%). Agende _gerar_alerta_vencimentos pela interface Cron do Supabase.', sqlerrm;
    end;
end
$enable_cron$;

-- Certificados ocupacionais são privados. A leitura será por signed URL curta.
do $$
begin
    if not exists (select 1 from storage.buckets where id = 'certificados') then
        raise exception 'Crie o bucket Storage "certificados" antes de aplicar esta migracao.';
    end if;
    update storage.buckets
       set public = false,
           file_size_limit = 10485760,
           allowed_mime_types = array['application/pdf','image/jpeg']
     where id = 'certificados';
end
$$;

create or replace function public.usuario_pode_ler_certificado(p_solicitacao_id text)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from public.solicitacoes_treinamento r
        where r.id::text = p_solicitacao_id
          and (r.supervisor_id = (select public.usuario_colaborador_id()) or (select public.usuario_e_sst()))
    )
$$;
create or replace function public.usuario_pode_enviar_certificado(p_solicitacao_id text)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from public.solicitacoes_treinamento r
        where r.id::text = p_solicitacao_id
          and r.supervisor_id = (select public.usuario_colaborador_id()) and r.status = 'rascunho'
    )
$$;
create or replace function public.usuario_pode_excluir_certificado(p_solicitacao_id text)
returns boolean language sql stable security definer set search_path = ''
as $$ select public.usuario_pode_enviar_certificado(p_solicitacao_id) $$;
revoke all on function public.usuario_pode_ler_certificado(text) from public;
revoke all on function public.usuario_pode_enviar_certificado(text) from public;
revoke all on function public.usuario_pode_excluir_certificado(text) from public;
grant execute on function public.usuario_pode_ler_certificado(text) to anon, authenticated;
grant execute on function public.usuario_pode_enviar_certificado(text) to anon, authenticated;
grant execute on function public.usuario_pode_excluir_certificado(text) to anon, authenticated;

create policy "Solicitante envia certificado do rascunho"
on storage.objects for insert to authenticated
with check (
    bucket_id = 'certificados'
    and exists (
        select 1 from public.solicitacoes_treinamento r
        where r.id::text = (storage.foldername(name))[1]
          and r.supervisor_id = (select public.usuario_colaborador_id())
          and r.status = 'rascunho'
    )
);
create policy "Supervisor e SST leem certificados autorizados"
on storage.objects for select to authenticated
using (
    bucket_id = 'certificados'
    and exists (
        select 1 from public.solicitacoes_treinamento r
        where r.id::text = (storage.foldername(name))[1]
          and (r.supervisor_id = (select public.usuario_colaborador_id()) or (select public.usuario_e_sst()))
    )
);
create policy "Solicitante remove arquivo de rascunho"
on storage.objects for delete to authenticated
using (
    bucket_id = 'certificados'
    and exists (
        select 1 from public.solicitacoes_treinamento r
        where r.id::text = (storage.foldername(name))[1]
          and r.supervisor_id = (select public.usuario_colaborador_id())
          and r.status = 'rascunho'
    )
);

-- Restrictive policies prevent pre-existing permissive Storage policies from widening access to certificates.
create policy "Certificados privados restringir leitura"
on storage.objects as restrictive for select to anon, authenticated
using (
    bucket_id <> 'certificados'
    or (select public.usuario_pode_ler_certificado((storage.foldername(name))[1]))
);
create policy "Certificados privados restringir envio"
on storage.objects as restrictive for insert to anon, authenticated
with check (
    bucket_id <> 'certificados'
    or (select public.usuario_pode_enviar_certificado((storage.foldername(name))[1]))
);
create policy "Certificados privados restringir alteracao"
on storage.objects as restrictive for update to anon, authenticated
using (bucket_id <> 'certificados')
with check (bucket_id <> 'certificados');
create policy "Certificados privados restringir exclusao"
on storage.objects as restrictive for delete to anon, authenticated
using (
    bucket_id <> 'certificados'
    or (select public.usuario_pode_excluir_certificado((storage.foldername(name))[1]))
);
