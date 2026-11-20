-- ONLYUSLABS full admin CMS / CRM database setup
-- Run this complete script once in Supabase Dashboard -> SQL Editor -> New query.
-- Browser code must use the publishable key only. NEVER place a secret/service_role key in the website.

create extension if not exists pgcrypto;

-- Administrator allow-list. The first row is the workspace owner.
create table if not exists public.admin_users (
  email text primary key,
  display_name text,
  role text not null default 'admin' check (role in ('owner','admin','editor')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.admin_users (email, display_name, role, active)
values ('cheggexpertshiva@gmail.com', 'ONLYUSLABS Owner', 'owner', true)
on conflict (email) do update set role='owner', active=true;

-- Security helper functions. SECURITY DEFINER avoids recursive RLS when checking the allow-list.
create or replace function public.is_onlyus_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users au
    where lower(au.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and au.active = true
  );
$$;

create or replace function public.is_onlyus_owner()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users au
    where lower(au.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and au.active = true and au.role = 'owner'
  );
$$;

create or replace function public.is_onlyus_manager()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users au
    where lower(au.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and au.active = true and au.role in ('owner','admin')
  );
$$;

grant execute on function public.is_onlyus_admin() to anon, authenticated;
grant execute on function public.is_onlyus_owner() to anon, authenticated;
grant execute on function public.is_onlyus_manager() to anon, authenticated;

-- CRM enquiries submitted from the public website.
create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  company text,
  industry text,
  service text,
  message text not null,
  status text not null default 'new' check (status in ('new','contacted','qualified','proposal','won','lost')),
  source text not null default 'website',
  consent boolean not null default false,
  assigned_to text,
  internal_notes text,
  follow_up_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists leads_created_at_idx on public.leads (created_at desc);
create index if not exists leads_status_idx on public.leads (status);
-- Country and local-currency project budget captured by the public enquiry form.
alter table public.leads add column if not exists country text;
alter table public.leads add column if not exists estimated_budget numeric(14,2);
alter table public.leads add column if not exists budget_currency text;
create index if not exists leads_country_idx on public.leads (country);


-- Unified content collection for pages, services, industries, healthcare, case studies,
-- testimonials, FAQs and insights.
create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),
  content_type text not null check (content_type in ('page','service','industry','healthcare','case_study','testimonial','faq','insight')),
  title text not null,
  slug text not null,
  route text unique,
  excerpt text,
  body text,
  category text,
  author text,
  featured_image_url text,
  seo_title text,
  seo_description text,
  seo_keywords text,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  sort_order integer not null default 0,
  data jsonb not null default '{}'::jsonb,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint content_slug_type_unique unique (content_type, slug)
);
create index if not exists content_type_status_idx on public.content_items (content_type, status);
create index if not exists content_route_idx on public.content_items (route);

-- Global public website settings (no credentials or private secrets belong here).
create table if not exists public.site_settings (
  id text primary key default 'global' check (id = 'global'),
  settings jsonb not null default '{}'::jsonb,
  is_public boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.site_settings (id, settings, is_public)
values ('global', jsonb_build_object(
  'company_name','ONLYUSLABS',
  'tagline','Intelligence Behind Better Business.',
  'phone','+91 77803 67903',
  'whatsapp','917780367903',
  'default_seo_title','ONLYUSLABS — Intelligence Behind Better Business',
  'default_seo_description','ONLYUSLABS designs intelligent automation systems that connect people, processes and technology.'
), true)
on conflict (id) do nothing;

-- Storage metadata. Actual files live in the onlyuslabs-media Supabase Storage bucket.
create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  file_name text not null,
  storage_path text not null unique,
  public_url text not null,
  mime_type text,
  size_bytes bigint,
  alt_text text,
  created_at timestamptz not null default now()
);
create index if not exists media_assets_created_at_idx on public.media_assets (created_at desc);

-- Audit trail for actions performed inside the admin workspace.
create table if not exists public.admin_activity (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  entity_type text,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  user_email text,
  created_at timestamptz not null default now()
);
create index if not exists admin_activity_created_at_idx on public.admin_activity (created_at desc);

-- Updated-at trigger.
create or replace function public.set_onlyus_updated_at()
returns trigger language plpgsql set search_path = public
as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists leads_set_updated_at on public.leads;
create trigger leads_set_updated_at before update on public.leads for each row execute function public.set_onlyus_updated_at();
drop trigger if exists content_items_set_updated_at on public.content_items;
create trigger content_items_set_updated_at before update on public.content_items for each row execute function public.set_onlyus_updated_at();
drop trigger if exists site_settings_set_updated_at on public.site_settings;
create trigger site_settings_set_updated_at before update on public.site_settings for each row execute function public.set_onlyus_updated_at();

-- Enable Row Level Security on every table.
alter table public.admin_users enable row level security;
alter table public.leads enable row level security;
alter table public.content_items enable row level security;
alter table public.site_settings enable row level security;
alter table public.media_assets enable row level security;
alter table public.admin_activity enable row level security;

-- Administrator allow-list: any active admin can read; only owner can manage access.
drop policy if exists "onlyus_admin_users_read" on public.admin_users;
create policy "onlyus_admin_users_read" on public.admin_users for select to authenticated using (public.is_onlyus_admin());
drop policy if exists "onlyus_admin_users_owner_insert" on public.admin_users;
create policy "onlyus_admin_users_owner_insert" on public.admin_users for insert to authenticated with check (public.is_onlyus_owner());
drop policy if exists "onlyus_admin_users_owner_update" on public.admin_users;
create policy "onlyus_admin_users_owner_update" on public.admin_users for update to authenticated using (public.is_onlyus_owner()) with check (public.is_onlyus_owner());
drop policy if exists "onlyus_admin_users_owner_delete" on public.admin_users;
create policy "onlyus_admin_users_owner_delete" on public.admin_users for delete to authenticated using (public.is_onlyus_owner());

-- Leads: the public can only create a clean new enquiry; managers can read and manage CRM records.
drop policy if exists "onlyus_public_submit_lead" on public.leads;
create policy "onlyus_public_submit_lead" on public.leads for insert to anon, authenticated
with check (
  status = 'new' and source = 'website' and consent = true
  and length(trim(name)) between 2 and 100
  and length(trim(email)) between 5 and 160 and position('@' in email) > 1
  and length(trim(coalesce(company,''))) between 1 and 150
  and length(trim(message)) between 5 and 3000
  and country in ('United States','United Kingdom','India','Canada','Australia','Germany','Sweden')
  and case country
    when 'United States' then budget_currency = 'USD'
    when 'United Kingdom' then budget_currency = 'GBP'
    when 'India' then budget_currency = 'INR'
    when 'Canada' then budget_currency = 'CAD'
    when 'Australia' then budget_currency = 'AUD'
    when 'Germany' then budget_currency = 'EUR'
    when 'Sweden' then budget_currency = 'SEK'
    else false
  end
  and (estimated_budget is null or estimated_budget >= 0)
  and assigned_to is null and internal_notes is null
);
drop policy if exists "onlyus_managers_read_leads" on public.leads;
create policy "onlyus_managers_read_leads" on public.leads for select to authenticated using (public.is_onlyus_manager());
drop policy if exists "onlyus_managers_update_leads" on public.leads;
create policy "onlyus_managers_update_leads" on public.leads for update to authenticated using (public.is_onlyus_manager()) with check (public.is_onlyus_manager());
drop policy if exists "onlyus_managers_delete_leads" on public.leads;
create policy "onlyus_managers_delete_leads" on public.leads for delete to authenticated using (public.is_onlyus_manager());

-- Content: published content can be read publicly; active admins can manage all content.
drop policy if exists "onlyus_public_read_published_content" on public.content_items;
create policy "onlyus_public_read_published_content" on public.content_items for select to anon, authenticated using (status = 'published' or public.is_onlyus_admin());
drop policy if exists "onlyus_admin_insert_content" on public.content_items;
create policy "onlyus_admin_insert_content" on public.content_items for insert to authenticated with check (public.is_onlyus_admin());
drop policy if exists "onlyus_admin_update_content" on public.content_items;
create policy "onlyus_admin_update_content" on public.content_items for update to authenticated using (public.is_onlyus_admin()) with check (public.is_onlyus_admin());
drop policy if exists "onlyus_admin_delete_content" on public.content_items;
create policy "onlyus_admin_delete_content" on public.content_items for delete to authenticated using (public.is_onlyus_admin());

-- Public settings may be read by the website; only managers can change them.
drop policy if exists "onlyus_public_read_site_settings" on public.site_settings;
create policy "onlyus_public_read_site_settings" on public.site_settings for select to anon, authenticated using (is_public = true or public.is_onlyus_admin());
drop policy if exists "onlyus_manager_insert_site_settings" on public.site_settings;
create policy "onlyus_manager_insert_site_settings" on public.site_settings for insert to authenticated with check (public.is_onlyus_manager());
drop policy if exists "onlyus_manager_update_site_settings" on public.site_settings;
create policy "onlyus_manager_update_site_settings" on public.site_settings for update to authenticated using (public.is_onlyus_manager()) with check (public.is_onlyus_manager());

-- Public metadata read for public assets; active admins can upload and manage the metadata.
drop policy if exists "onlyus_public_read_media_metadata" on public.media_assets;
create policy "onlyus_public_read_media_metadata" on public.media_assets for select to anon, authenticated using (true);
drop policy if exists "onlyus_admin_insert_media_metadata" on public.media_assets;
create policy "onlyus_admin_insert_media_metadata" on public.media_assets for insert to authenticated with check (public.is_onlyus_admin());
drop policy if exists "onlyus_admin_update_media_metadata" on public.media_assets;
create policy "onlyus_admin_update_media_metadata" on public.media_assets for update to authenticated using (public.is_onlyus_admin()) with check (public.is_onlyus_admin());
drop policy if exists "onlyus_admin_delete_media_metadata" on public.media_assets;
create policy "onlyus_admin_delete_media_metadata" on public.media_assets for delete to authenticated using (public.is_onlyus_admin());

-- Audit log: administrators can view and add audit events.
drop policy if exists "onlyus_admin_read_activity" on public.admin_activity;
create policy "onlyus_admin_read_activity" on public.admin_activity for select to authenticated using (public.is_onlyus_admin());
drop policy if exists "onlyus_admin_insert_activity" on public.admin_activity;
create policy "onlyus_admin_insert_activity" on public.admin_activity for insert to authenticated with check (public.is_onlyus_admin());

-- Grant the minimum table privileges; RLS policies above enforce row-level access.
grant select, insert, update, delete on public.admin_users to authenticated;
grant select, insert, update, delete on public.leads to authenticated;
grant insert on public.leads to anon;
grant select, insert, update, delete on public.content_items to authenticated;
grant select on public.content_items to anon;
grant select, insert, update, delete on public.site_settings to authenticated;
grant select on public.site_settings to anon;
grant select, insert, update, delete on public.media_assets to authenticated;
grant select on public.media_assets to anon;
grant select, insert on public.admin_activity to authenticated;

-- Create the public media bucket. Public read is intentional for website images; uploads/deletes remain admin-only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('onlyuslabs-media', 'onlyuslabs-media', true, 15728640, array['image/jpeg','image/png','image/webp','image/gif','image/svg+xml','application/pdf'])
on conflict (id) do update set public=true, file_size_limit=15728640, allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "onlyus_public_read_onlyus_media" on storage.objects;
create policy "onlyus_public_read_onlyus_media" on storage.objects for select to anon, authenticated using (bucket_id = 'onlyuslabs-media');
drop policy if exists "onlyus_admin_upload_onlyus_media" on storage.objects;
create policy "onlyus_admin_upload_onlyus_media" on storage.objects for insert to authenticated with check (bucket_id = 'onlyuslabs-media' and public.is_onlyus_admin());
drop policy if exists "onlyus_admin_update_onlyus_media" on storage.objects;
create policy "onlyus_admin_update_onlyus_media" on storage.objects for update to authenticated using (bucket_id = 'onlyuslabs-media' and public.is_onlyus_admin()) with check (bucket_id = 'onlyuslabs-media' and public.is_onlyus_admin());
drop policy if exists "onlyus_admin_delete_onlyus_media" on storage.objects;
create policy "onlyus_admin_delete_onlyus_media" on storage.objects for delete to authenticated using (bucket_id = 'onlyuslabs-media' and public.is_onlyus_admin());

-- Starter CMS records matching the existing static website routes.
-- They are intentionally saved as DRAFT so the current public pages do not change until you publish them.
insert into public.content_items (content_type,title,slug,route,excerpt,status,sort_order) values
('page','Make complexity work beautifully','home','/', 'We design intelligent automation systems that connect people, processes and technology — helping organisations operate with greater clarity.', 'draft', 0),
('page','Technology, shaped around your work','solutions','/solutions/', 'We bring strategy, automation and engineering together to create systems that make everyday business more connected and considered.', 'draft', 0),
('page','Different contexts. Thoughtful systems.','industries','/industries/', 'We recognise that every industry works differently. Our approach starts with the details of your environment, not a pre-packaged approach.', 'draft', 0),
('page','Technology with intention','about','/about/', 'We believe the best technology is not the technology people notice. It is the thoughtful system that makes work clearer, calmer and more effective.', 'draft', 0),
('page','Ideas for a more intelligent business','insights','/insights/', 'Notes on automation, operational design and the thoughtful application of technology.', 'draft', 0),
('page','Better systems, thoughtfully designed','case-studies','/case-studies/', 'Explore examples of the operational challenges and workflow patterns that intelligent automation can help address.', 'draft', 0),
('page','Tell us what could work better','contact','/contact/', 'Share a little about your organisation and the process you would like to improve. We will take it from there.', 'draft', 0),
('healthcare','Intelligent operations for modern healthcare','healthcare','/healthcare/', 'Helping hospitals and healthcare organisations connect administrative workflows, improve coordination and create more considered patient experiences.', 'draft', 0),
('service','Conversational AI, made practical','conversational-ai','/solutions/conversational-ai/', 'Useful assistants for customer enquiries and internal support.', 'draft', 0),
('service','Intelligent workflow automation, made practical','workflow-automation','/solutions/workflow-automation/', 'Connect tasks, tools and teams with fewer manual hand-offs.', 'draft', 0),
('service','AI systems and agents, made practical','ai-systems-agents','/solutions/ai-systems-agents/', 'Purpose-built AI assistants for meaningful business work.', 'draft', 0),
('service','Business process engineering, made practical','process-engineering','/solutions/process-engineering/', 'Improve how work moves across your organisation.', 'draft', 0),
('service','Enterprise integrations, made practical','enterprise-integrations','/solutions/enterprise-integrations/', 'Connect existing software and data so information moves with less friction.', 'draft', 0),
('service','Custom digital platforms, made practical','custom-digital-platforms','/solutions/custom-digital-platforms/', 'Purpose-built portals, dashboards and internal tools.', 'draft', 0),
('industry','Real estate, connected with intent','real-estate','/industries/real-estate/', 'Connected property enquiries, follow-ups and sales operations.', 'draft', 0),
('industry','Civil engineering and construction, connected with intent','civil-engineering','/industries/civil-engineering/', 'More coordinated project reporting, approvals and site workflows.', 'draft', 0),
('industry','Enterprise operations, connected with intent','enterprise-operations','/industries/enterprise-operations/', 'Connected processes and information across growing organisations.', 'draft', 0),
('industry','Professional services, connected with intent','professional-services','/industries/professional-services/', 'More connected client intake, document and delivery workflows.', 'draft', 0),
('industry','Retail and commerce, connected with intent','retail-commerce','/industries/retail-commerce/', 'Connected customer enquiries, orders and operational workflows.', 'draft', 0),
('case_study','A more coordinated hospital enquiry workflow','hospital-enquiry-routing-study','/case-studies/hospital-enquiry-routing-study/', 'Enquiries can arrive through multiple channels and may need to be routed to different administrative teams.', 'draft', 0),
('case_study','A clearer path from property enquiry to site visit','property-lead-follow-up-study','/case-studies/property-lead-follow-up-study/', 'Property teams may coordinate enquiries, agent assignment and site visit availability across separate tools.', 'draft', 0)
on conflict (content_type, slug) do nothing;

-- End of setup. Reload /admin/ after the query succeeds.
