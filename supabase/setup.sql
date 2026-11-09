-- ============================================================
--  PONTE — Script de configuração do banco (Supabase)
--  Como usar: SQL Editor > New query > cole TUDO aqui > Run
--  Pode rodar mais de uma vez sem quebrar (é repetível).
-- ============================================================

-- 1. SALAS (código de 4 letras que liga vocês duas)
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_at timestamptz not null default now()
);

-- 2. MEMBROS (quem está na sala e em que idioma fala)
create table if not exists members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  name text not null,
  lang text not null default 'pt',
  last_seen timestamptz not null default now()
);

-- 3. MENSAGENS (texto, fotos e avisos do sistema)
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  sender_name text not null default '',
  sender_lang text not null default 'pt',
  kind text not null default 'text',      -- text | image | system
  original text not null default '',      -- texto/caption original
  image_url text,                         -- foto (quando kind = image)
  created_at timestamptz not null default now()
);

-- 4. FILMES DA SALA
create table if not exists movies (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  title text not null default 'Filme',
  url text,                               -- link .mp4/.m3u8 (null = arquivo local)
  local_path text,                        -- caminho no aparelho de quem adicionou
  added_by text not null default '',
  created_at timestamptz not null default now()
);

-- 5. SINCRONIZAÇÃO DE REPRODUÇÃO (assistir junto)
create table if not exists playback (
  room_id uuid primary key references rooms(id) on delete cascade,
  movie_id uuid references movies(id) on delete set null,
  position_seconds double precision not null default 0,
  is_playing boolean not null default false,
  controller text not null default '',    -- quem comanda o play/pause
  updated_at timestamptz not null default now()
);

-- Índices para as consultas do app
create index if not exists messages_room_created
  on messages (room_id, created_at desc);
create index if not exists movies_room_created
  on movies (room_id, created_at desc);
create index if not exists members_room
  on members (room_id, last_seen desc);

-- ============================================================
--  TEMPO REAL: avisa o app na hora quando chega mensagem
--  ou quando o estado do filme muda
-- ============================================================
do $$
begin
  alter publication supabase_realtime add table messages;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table playback;
exception
  when duplicate_object then null;
end $$;

-- ============================================================
--  PERMISSÕES: app usa a chave anônima, então liberamos as
--  tabelas para o uso pessoal de vocês (o "segredo" é o código
--  da sala — mantenha o projeto do GitHub privado)
-- ============================================================
alter table rooms    enable row level security;
alter table members  enable row level security;
alter table messages enable row level security;
alter table movies   enable row level security;
alter table playback enable row level security;

drop policy if exists "ponte_rooms_all"    on rooms;
drop policy if exists "ponte_members_all"  on members;
drop policy if exists "ponte_messages_all" on messages;
drop policy if exists "ponte_movies_all"   on movies;
drop policy if exists "ponte_playback_all" on playback;

create policy "ponte_rooms_all"    on rooms    for all using (true) with check (true);
create policy "ponte_members_all"  on members  for all using (true) with check (true);
create policy "ponte_messages_all" on messages for all using (true) with check (true);
create policy "ponte_movies_all"   on movies   for all using (true) with check (true);
create policy "ponte_playback_all" on playback for all using (true) with check (true);

-- ============================================================
--  FOTOS: bucket público "fotos" no Supabase Storage
-- ============================================================
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', true)
on conflict (id) do nothing;

drop policy if exists "ponte_fotos_all" on storage.objects;
create policy "ponte_fotos_all" on storage.objects
  for all using (bucket_id = 'fotos') with check (bucket_id = 'fotos');

-- Pronto! Agora copie a URL e a anon key do projeto
-- (Project Settings > API) para o arquivo lib/config.dart
