-- ============================================================
-- OrderBase v2 — UPGRADE SQL — Run in Supabase SQL Editor
-- ============================================================

-- 1. Products table enhancements
alter table products add column if not exists image_url text;
alter table products add column if not exists has_sizes boolean default false;
alter table products add column if not exists sizes text;
alter table products add column if not exists description text;

-- 2. Orders table enhancements
alter table orders add column if not exists items jsonb;
alter table orders add column if not exists subtotal integer default 0;
alter table orders add column if not exists payment_method text default 'COD';
alter table orders add column if not exists payment_status text default 'Pending';
alter table orders add column if not exists bank_slip_url text;
alter table orders add column if not exists reminder_sent boolean default false;

-- 3. Clients table enhancements (plan management)
alter table clients add column if not exists plan_type text default 'normal';
alter table clients add column if not exists max_orders integer default 100;
alter table clients add column if not exists max_products integer default 20;
alter table clients add column if not exists branding_color text default '#185fa5';
alter table clients add column if not exists branding_logo text;
alter table clients add column if not exists shop_description text;

-- 4. Storage buckets for images
insert into storage.buckets (id,name,public) values ('slips','slips',true) on conflict do nothing;
insert into storage.buckets (id,name,public) values ('products','products',true) on conflict do nothing;

-- 5. Storage policies
drop policy if exists "anon upload slips" on storage.objects;
drop policy if exists "anon read slips" on storage.objects;
drop policy if exists "anon upload products" on storage.objects;
drop policy if exists "anon read products" on storage.objects;

create policy "anon upload slips" on storage.objects for insert to anon with check (bucket_id='slips');
create policy "anon read slips" on storage.objects for select to anon using (bucket_id='slips');
create policy "anon read products" on storage.objects for select to anon using (bucket_id='products');
create policy "service upload products" on storage.objects for all to service_role using (bucket_id='products');

-- 6. Reminders table
create table if not exists reminders (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid references orders(id) on delete cascade,
  client_id uuid references clients(id) on delete cascade,
  sent_at timestamptz default now(),
  message text
);

-- 7. Client order stats view
drop view if exists client_order_stats;
create view client_order_stats as
select
  c.id as client_id,
  c.name as client_name,
  c.status,
  c.plan_amount,
  c.plan_type,
  c.max_orders,
  c.max_products,
  count(o.id) as total_orders,
  count(o.id) filter (where o.status='Pending') as pending_orders,
  count(o.id) filter (where o.status='Delivered') as delivered_orders,
  coalesce(sum(o.subtotal) filter (where o.status='Delivered'),0) as delivered_revenue,
  count(o.id) filter (where date_trunc('month',o.created_at)=date_trunc('month',now())) as orders_this_month_count
from clients c 
left join orders o on o.client_id=c.id 
group by c.id;

-- 8. Permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO postgres, anon, authenticated, service_role;
