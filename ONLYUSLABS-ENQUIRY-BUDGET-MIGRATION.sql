-- ONLYUSLABS enquiry country and estimated-budget migration
-- Run once in Supabase SQL Editor for an existing ONLYUSLABS database.
-- Safe to re-run: columns and index use IF NOT EXISTS; policy is replaced idempotently.

alter table public.leads add column if not exists country text;
alter table public.leads add column if not exists estimated_budget numeric(14,2);
alter table public.leads add column if not exists budget_currency text;
create index if not exists leads_country_idx on public.leads (country);

-- Recreate the public insert policy so the new fields are validated.
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
