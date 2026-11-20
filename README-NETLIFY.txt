ONLYUSLABS — PREMIUM WEBSITE + FUNCTIONAL ADMIN WORKSPACE
========================================================

This package is a static website designed for Netlify, with Supabase providing authentication, database storage and media storage.

QUICK START
1. Follow SUPABASE-ADMIN-SETUP.txt.
2. Run ONLYUSLABS-SUPABASE-SETUP.sql in the Supabase SQL Editor.
3. Confirm the owner Auth user exists.
4. Deploy the extracted website folder to your existing Netlify site.
5. Open /admin/login.html and sign in.

TECHNICAL STACK
- Static HTML/CSS/JavaScript website.
- Supabase JavaScript client v2 loaded as an ES module.
- Supabase Auth email/password login.
- Supabase Postgres tables with Row Level Security.
- Supabase Storage public-read media bucket with administrator-only writes.
- Netlify static hosting and redirects.

ADMIN ROUTES
/admin/login.html — secure sign-in
/admin/ — authenticated admin workspace

ADMIN MODULES
Overview; Enquiries / CRM; Pages; Services; Industries; Healthcare content; Case studies; Testimonials; FAQs; Insights; Media library; SEO & website settings; Administrators; Account security; Activity log.

PUBLIC WEBSITE INTEGRATION
- Contact form writes new enquiry records to Supabase.
- Public CMS runtime reads published content records by exact route.
- Published service/industry/healthcare/insight/case-study records can appear in the relevant public collection sections.
- Public pages only read published CMS content and public website settings.

IMPORTANT
The SQL script must be run before the dashboard or contact form can work. Do not remove the RLS policies or expose the Supabase secret/service_role key. The CRM is for ordinary business enquiries only and must not be used to store patient or other sensitive records.

The existing site's page layouts and brand styling have been retained. This package adds the functional admin application and database integration; it does not automatically replace the entire public website design.


PORTFOLIO & HOMEPAGE CONTENT UPDATE
- Added a six-project selected-work directory and six individual project context pages.
- Added expanded services and expertise content, a six-stage delivery process, Why ONLYUSLABS section, technology ecosystem and client-perspectives area.
- The six featured projects are the projects visible in the publicly accessible portfolio content reviewed for this update. This is not a claim that all 50+ projects or 100+ enterprise clients have been individually extracted.
- Technology labels are limited to technologies identified in the available project descriptions.
- No former portfolio phone number, email address, street address or contact link has been copied. Existing ONLYUSLABS contact and WhatsApp details remain unchanged.
- Client testimonials imported into the optional SQL are DRAFT only and must be verified and approved before publishing or attributing them to ONLYUSLABS.
