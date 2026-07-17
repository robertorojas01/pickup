-- ============================================================
-- PUNTO BURGER — Esquema para Supabase
-- Pega y ejecuta este archivo completo en:
-- Supabase → SQL Editor → New query → Run
-- ============================================================

-- Tabla principal de pedidos
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity (start with 100),
  order_type text not null check (order_type in ('retiro','delivery')),
  payment_method text not null check (payment_method in ('efectivo','tarjeta','online')),
  delivery_address text,
  subtotal numeric(10,0) not null,
  delivery_fee numeric(10,0) not null default 0,
  total numeric(10,0) not null,
  status text not null default 'recibido'
    check (status in ('recibido','preparando','listo','en_camino','entregado')),
  created_at timestamptz not null default now()
);

-- Detalle de productos por pedido
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  item_name text not null,
  unit_price numeric(10,0) not null,
  qty int not null,
  extras text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Seguridad a nivel de fila (RLS)
-- ============================================================
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Cualquiera (el cliente, sin login) puede CREAR un pedido
create policy "clientes pueden crear pedidos"
  on public.orders for insert
  to anon
  with check (true);

create policy "clientes pueden agregar items"
  on public.order_items for insert
  to anon
  with check (true);

-- Cualquiera puede LEER pedidos (necesario para el seguimiento del cliente
-- y para que el panel de cocina funcione con la misma llave anon).
-- ⚠️ Nota de seguridad: esto significa que cualquiera con la URL/llave anon
-- podría listar todos los pedidos (incluye direcciones de delivery).
-- Para un local chico esto suele ser un riesgo aceptable al partir, pero si
-- vas a producción, reemplaza esto por una Edge Function que sólo devuelva
-- el pedido puntual que el cliente está consultando.
create policy "lectura abierta de pedidos"
  on public.orders for select
  to anon
  using (true);

create policy "lectura abierta de items"
  on public.order_items for select
  to anon
  using (true);

-- Sólo el STAFF autenticado (login en el panel de cocina) puede
-- actualizar el estado de un pedido.
create policy "staff autenticado puede actualizar estado"
  on public.orders for update
  to authenticated
  using (true)
  with check (true);

-- ============================================================
-- Tiempo real: avisa a los clientes conectados apenas cambia un pedido
-- ============================================================
alter publication supabase_realtime add table public.orders;
alter publication supabase_realtime add table public.order_items;
