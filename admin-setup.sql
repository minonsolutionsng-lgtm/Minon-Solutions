-- ============================================================
-- MINON SOLUTIONS — ADMIN ACCOUNT SETUP
-- Run this in Supabase SQL Editor AFTER the main schema.sql
-- ============================================================

-- STEP 1: Create the admin user in Supabase Auth
-- This creates the login account with email + password
SELECT auth.uid(); -- Just to confirm you're connected

-- Insert admin into auth.users directly (Service Role needed)
-- If you get permission error, use the Supabase Dashboard instead:
-- Authentication → Users → Invite User → enter minonsolutions5@gmail.com

-- STEP 2: After the user is created (via dashboard or SQL),
-- run this to set their role to admin:

UPDATE public.profiles
SET
  role = 'admin',
  full_name = 'Minon Admin',
  verified = true,
  updated_at = NOW()
WHERE email = 'minonsolutions5@gmail.com';

-- STEP 3: Verify it worked
SELECT id, email, role, full_name
FROM public.profiles
WHERE email = 'minonsolutions5@gmail.com';

-- ============================================================
-- IMPORTANT: If the profile row doesn't exist yet
-- (because the user hasn't signed up), use this INSERT instead:
-- ============================================================

-- INSERT INTO public.profiles (id, email, role, full_name, verified)
-- SELECT id, email, 'admin', 'Minon Admin', true
-- FROM auth.users
-- WHERE email = 'minonsolutions5@gmail.com'
-- ON CONFLICT (id) DO UPDATE SET role = 'admin', verified = true;
