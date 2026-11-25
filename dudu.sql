create table jogadores (
    id_jogador serial primary key,
    nickname varchar(50) not null unique,
    email varchar(120) not null unique,
    senha varchar(100) not null,
    status varchar(40) not null default 'ativo',
    ativo boolean not null default true,
    data_cadastro timestamp not null default current_timestamp,
    check (status in ('ativo', 'inativo', 'banido'))
);

create table modalidades (
    id_modalidade serial primary key,
    nome varchar(100) not null unique,
    genero varchar(100),
    quantidade_jogadores_equipe int not null,
    constraint quantidade_jogadores check (quantidade_jogadores_equipe > 0)
);

create table partidas (
    id serial primary key,
    titulo varchar(100) not null,
    id_jogadores int not null references jogadores(id_jogador),
    id_modalidades int not null references modalidades(id_modalidade),
    data_partida timestamp not null,
    status varchar(20) not null default 'Agendada',
    data_criacao timestamp not null default current_timestamp,
    constraint status_partidas check (status in ('Agendada', 'Finalizada', 'Cancelada'))
);

create table historico_partidas (
    id_historicos serial primary key,
    id_partida int not null references partidas(id),
    acao varchar(50) not null,
    descricao text not null,
    data_registro timestamp not null default current_timestamp
);

create or replace function fn_validar_partida_before()
returns trigger as $$
declare
    v_jogador_ativo boolean;
    v_nickname varchar(50);
begin
    select ativo, nickname into v_jogador_ativo, v_nickname
    from jogadores
    where id_jogador = new.id_jogadores;

    if not found then
        raise exception 'Operação bloqueada: Jogador com ID % não encontrado.', new.id_jogadores;
    end if;

    if v_jogador_ativo is false then
        raise exception 'Operação bloqueada: O jogador "%" está inativo/banido e não pode ser vinculado a novas partidas.', v_nickname;
    end if;

    new.data_criacao := current_timestamp;
    return new;
end;
$$ language plpgsql;

create trigger trg_validar_partida 
before insert on partidas 
for each row execute function fn_validar_partida_before();

create or replace function fn_registrar_log_partida_after() 
returns trigger as $$ 
begin 
    insert into historico_partidas (id_partida, acao, descricao, data_registro) 
    values (
        new.id, 
        'CRIACAO_PARTIDA', 
        format('Partida "%s" agendada para %s com status inicial "%s".', new.titulo, to_char(new.data_partida, 'DD/MM/YYYY HH24:MI'), new.status), 
        new.data_criacao
    ); 
    return new; 
end; 
$$ language plpgsql;

create trigger trg_log_criacao_partida 
after insert on partidas 
for each row execute function fn_registrar_log_partida_after();

insert into jogadores (nickname, email, senha, status, ativo) values
('KaleBR', 'eduardo.miranda@esports.com.br', 'senha123', 'ativo', true),
('AskaKing', 'eduardo.lisboa@esports.com.br', 'valorant2026', 'ativo', true),
('KaieMid', 'gabriel.miranda@esports.com.br', 'midlaner99', 'ativo', true),
('TofcPlayer', 'banido.conta@esports.com.br', 'ban12345', 'banido', false);

insert into modalidades (nome, genero, quantidade_jogadores_equipe) values
('Counter-Strike 2', 'FPS Tático', 5),
('Valorant', 'FPS Tático', 5),
('League of Legends', 'MOBA', 5);

insert into partidas (titulo, id_jogadores, id_modalidades, data_partida, status) values
('Final Major Brasil - Imperial vs FURIA', 1, 1, '2026-12-01 19:00:00', 'Agendada'),
('Semifinal VCT Americas - LOUD vs Sentinels', 2, 2, '2026-11-28 21:00:00', 'Agendada'),
('Clássico CBLOL - paiN Gaming vs KaBuM', 3, 3, '2026-12-10 15:00:00', 'Agendada');

create or replace function fn_buscar_jogadores(p_termo_busca text)
returns table (
    id_jogadores int,
    nickname varchar,
    email varchar,
    status_conta text,
    data_cadastro timestamp
) as $$
begin
    return query
    select 
        j.id_jogadores,
        j.nickname,
        j.email,
        case when j.ativo then 'Ativo' else 'Inativo/Banido' end as status_conta,
        j.data_cadastro
    from jogadores j
    where j.nickname ilike '%' || trim(p_termo_busca) || '%'
       or j.email ilike '%' || trim(p_termo_busca) || '%'
    order by j.nickname asc;
end;
$$ language plpgsql;

create or replace view vw_painel_principal as
select 
    j.nickname as nickname_jogador,
    p.titulo as titulo_partida,
    m.nome as modalidade_jogo,
    p.data_partida,
    p.status as status_disputa
from partidas p
inner join jogadores j on p.id_jogadores = j.id_jogador
inner join modalidades m on p.id_modalidades = m.id_modalidade;

create or replace view vw_cronograma_partidas as
select 
    p.id as id_partida,
    p.titulo as titulo_partida,
    p.data_partida as data_agendamento,
    p.status as status_partida,
    greatest(0, extract(day from (p.data_partida - current_timestamp))::int) as dias_restantes,
    j.nickname as jogador_responsavel
from partidas p
inner join jogadores j on p.id_jogadores = j.id_jogador
order by p.data_partida asc;

select * from vw_painel_principal;

select * from vw_cronograma_partidas;

select * from historico_partidas;

select * from fn_buscar_jogadores('gabriel');