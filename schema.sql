-- ============================================================
-- MINON SOLUTIONS — COMPLETE SUPABASE SQL SCHEMA
-- Run this entire script in Supabase SQL Editor
-- Project: rmwvrbpkxbxmbpidzbfe
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. PROFILES (extends Supabase auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  phone TEXT,
  role TEXT DEFAULT 'buyer' CHECK (role IN ('buyer','vendor','service_provider','dispatch_rider','tutor','realtor','restaurant_owner','freelancer','admin')),
  state TEXT,
  city TEXT,
  address TEXT,
  bio TEXT,
  skills TEXT,
  subjects TEXT,
  agency TEXT,
  experience_years INTEGER DEFAULT 0,
  business_name TEXT,
  restaurant_name TEXT,
  restaurant_phone TEXT,
  restaurant_open BOOLEAN DEFAULT false,
  min_order NUMERIC DEFAULT 0,
  delivery_time INTEGER DEFAULT 30,
  cuisine_type TEXT,
  plate_number TEXT,
  vehicle_type TEXT DEFAULT 'Motorcycle',
  portfolio_url TEXT,
  online BOOLEAN DEFAULT false,
  available BOOLEAN DEFAULT false,
  verified BOOLEAN DEFAULT false,
  suspended BOOLEAN DEFAULT false,
  premium BOOLEAN DEFAULT false,
  premium_expires_at TIMESTAMPTZ,
  referral_code TEXT UNIQUE,
  referred_by TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. WALLETS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  balance NUMERIC DEFAULT 0 CHECK (balance >= 0),
  total_earned NUMERIC DEFAULT 0,
  total_withdrawn NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. WALLET TRANSACTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  type TEXT CHECK (type IN ('credit','debit','withdrawal')),
  description TEXT,
  reference TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. WITHDRAWAL REQUESTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount >= 5000),
  bank_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_name TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','paid','rejected')),
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. PAYMENT RECEIPTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.payment_receipts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  type TEXT, -- 'verification', 'premium', 'rider_verification', etc.
  receipt_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  notes TEXT,
  reviewed_by UUID REFERENCES public.profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. PRODUCTS (Vendor listings)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC NOT NULL CHECK (price > 0),
  compare_price NUMERIC,
  category TEXT,
  emoji TEXT DEFAULT '📦',
  images TEXT[],
  stock INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','inactive','deleted')),
  is_flash_sale BOOLEAN DEFAULT false,
  flash_price NUMERIC,
  flash_ends_at TIMESTAMPTZ,
  sales_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. ORDERS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  buyer_id UUID REFERENCES public.profiles(id),
  vendor_id UUID REFERENCES public.profiles(id),
  restaurant_id UUID REFERENCES public.profiles(id),
  realtor_id UUID REFERENCES public.profiles(id),
  rider_id UUID REFERENCES public.profiles(id),
  product_id UUID REFERENCES public.products(id),
  product_name TEXT,
  buyer_name TEXT,
  customer_name TEXT,
  client_name TEXT,
  items_summary TEXT,
  quantity INTEGER DEFAULT 1,
  unit_price NUMERIC DEFAULT 0,
  total_amount NUMERIC DEFAULT 0,
  commission_amount NUMERIC DEFAULT 0,
  commission NUMERIC DEFAULT 0,
  property_name TEXT,
  deal_type TEXT,
  deal_value NUMERIC DEFAULT 0,
  delivery_address TEXT,
  delivery_fee NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','processing','preparing','ready','in_transit','delivered','completed','cancelled','refunded')),
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending','paid','refunded')),
  payment_method TEXT DEFAULT 'wallet',
  notes TEXT,
  ready_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. DELIVERY JOBS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.delivery_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES public.orders(id),
  rider_id UUID REFERENCES public.profiles(id),
  sender_name TEXT,
  customer_name TEXT,
  pickup_address TEXT NOT NULL,
  delivery_address TEXT NOT NULL,
  package_description TEXT,
  delivery_type TEXT DEFAULT 'package' CHECK (delivery_type IN ('package','food','errand','express','business','interstate')),
  fee NUMERIC DEFAULT 0,
  rider_fee NUMERIC DEFAULT 0,
  is_express BOOLEAN DEFAULT false,
  distance_km NUMERIC,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','picked_up','in_transit','delivered','cancelled')),
  accepted_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. SERVICE LISTINGS (Provider & Freelancer)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.service_listings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT,
  base_price NUMERIC DEFAULT 0,
  delivery_time TEXT,
  revisions INTEGER DEFAULT 1,
  experience_years INTEGER DEFAULT 0,
  location TEXT,
  availability TEXT DEFAULT 'Everyday',
  status TEXT DEFAULT 'active' CHECK (status IN ('active','inactive','deleted')),
  sales_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 10. CLASS BOOKINGS (Tutor sessions & freelancer/provider jobs)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.class_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES public.profiles(id),
  provider_id UUID REFERENCES public.profiles(id),
  student_id UUID REFERENCES public.profiles(id),
  client_id UUID REFERENCES public.profiles(id),
  service_name TEXT,
  subject TEXT,
  level TEXT,
  student_name TEXT,
  customer_name TEXT,
  client_name TEXT,
  amount NUMERIC DEFAULT 0,
  location TEXT,
  scheduled_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','confirmed','active','in_progress','completed','cancelled')),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 11. STUDY MATERIALS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.study_materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  subject TEXT,
  type TEXT DEFAULT 'pdf' CHECK (type IN ('pdf','video','live')),
  level TEXT,
  price NUMERIC DEFAULT 0,
  description TEXT,
  file_url TEXT,
  status TEXT DEFAULT 'published' CHECK (status IN ('published','draft','deleted')),
  sales_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 12. PROPERTIES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.properties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  realtor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  property_type TEXT,
  listing_type TEXT DEFAULT 'sale' CHECK (listing_type IN ('sale','rent','lease')),
  price NUMERIC NOT NULL,
  negotiable BOOLEAN DEFAULT true,
  state TEXT,
  city TEXT,
  address TEXT,
  bedrooms INTEGER,
  bathrooms INTEGER,
  toilets INTEGER,
  size NUMERIC,
  parking INTEGER,
  images TEXT[],
  status TEXT DEFAULT 'active' CHECK (status IN ('active','sold','rented','inactive','deleted')),
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 13. RESTAURANTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.restaurants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  cuisine_type TEXT,
  city TEXT,
  state TEXT,
  address TEXT,
  phone TEXT,
  emoji TEXT DEFAULT '🍽️',
  opening_time TIME DEFAULT '08:00',
  closing_time TIME DEFAULT '22:00',
  min_order NUMERIC DEFAULT 0,
  delivery_time INTEGER DEFAULT 30,
  delivery_fee NUMERIC DEFAULT 0,
  restaurant_open BOOLEAN DEFAULT false,
  verified BOOLEAN DEFAULT false,
  rating NUMERIC DEFAULT 0,
  review_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 14. MENU ITEMS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.menu_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  price NUMERIC NOT NULL CHECK (price > 0),
  emoji TEXT DEFAULT '🍽️',
  prep_time INTEGER DEFAULT 20,
  available BOOLEAN DEFAULT true,
  is_deal BOOLEAN DEFAULT false,
  deal_price NUMERIC,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 15. PORTFOLIO ITEMS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.portfolio_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  freelancer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  category TEXT,
  description TEXT,
  image_url TEXT,
  project_link TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 16. REVIEWS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reviewer_id UUID REFERENCES public.profiles(id),
  reviewer_name TEXT,
  vendor_id UUID REFERENCES public.profiles(id),
  provider_id UUID REFERENCES public.profiles(id),
  tutor_id UUID REFERENCES public.profiles(id),
  realtor_id UUID REFERENCES public.profiles(id),
  restaurant_id UUID REFERENCES public.profiles(id),
  freelancer_id UUID REFERENCES public.profiles(id),
  order_id UUID REFERENCES public.orders(id),
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 17. DISPUTES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  buyer_id UUID REFERENCES public.profiles(id),
  vendor_id UUID REFERENCES public.profiles(id),
  order_id UUID REFERENCES public.orders(id),
  issue_type TEXT,
  description TEXT,
  evidence_url TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','investigating','resolved','closed')),
  resolution TEXT,
  resolved_by UUID REFERENCES public.profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 18. REPORTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID REFERENCES public.profiles(id),
  reported_id UUID REFERENCES public.profiles(id),
  reason TEXT,
  description TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','reviewed','dismissed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 19. NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT,
  icon TEXT DEFAULT '🔔',
  type TEXT,
  read BOOLEAN DEFAULT false,
  link TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 20. CONTACT MESSAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.contact_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  email TEXT,
  phone TEXT,
  subject TEXT,
  message TEXT,
  service_type TEXT,
  realtor_id UUID,
  property_name TEXT,
  status TEXT DEFAULT 'unread' CHECK (status IN ('unread','read','replied')),
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 21. PROMOTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.promotions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT,
  product_name TEXT,
  restaurant_id UUID REFERENCES public.profiles(id),
  vendor_id UUID REFERENCES public.profiles(id),
  type TEXT DEFAULT 'Flash Sale',
  discount_percent INTEGER DEFAULT 0,
  end_date TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','expired','deleted')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 22. BLOG POSTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.blog_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID REFERENCES public.profiles(id),
  title TEXT NOT NULL,
  content TEXT,
  category TEXT DEFAULT 'News',
  cover_image TEXT,
  slug TEXT UNIQUE,
  status TEXT DEFAULT 'published' CHECK (status IN ('published','draft','deleted')),
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 23. JOB LISTINGS (Careers)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.job_listings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  department TEXT,
  type TEXT DEFAULT 'Full-time',
  location TEXT,
  description TEXT,
  requirements TEXT,
  salary_range TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','closed','filled')),
  application_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 24. CHAT SESSIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chat_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_message TEXT,
  admin_read BOOLEAN DEFAULT false,
  user_read BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 25. CHAT MESSAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  sender TEXT CHECK (sender IN ('user','admin')),
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 26. WISHLISTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.wishlists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, product_id)
);

-- ============================================================
-- 27. REFERRALS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.referrals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id UUID REFERENCES public.profiles(id),
  referred_id UUID REFERENCES public.profiles(id),
  bonus_paid BOOLEAN DEFAULT false,
  bonus_amount NUMERIC DEFAULT 300,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public) VALUES
  ('products', 'products', true),
  ('study-materials', 'study-materials', false),
  ('receipts', 'receipts', false),
  ('portfolio', 'portfolio', true),
  ('properties', 'properties', true),
  ('avatars', 'avatars', true),
  ('restaurants', 'restaurants', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read all, update only their own
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Wallets: users can only see and update their own
CREATE POLICY "Users can view own wallet"
  ON public.wallets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own wallet"
  ON public.wallets FOR UPDATE USING (auth.uid() = user_id);

-- Wallet transactions: users see only their own
CREATE POLICY "Users can view own transactions"
  ON public.wallet_transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Authenticated can insert transactions"
  ON public.wallet_transactions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Withdrawal requests: users see only their own
CREATE POLICY "Users can view own withdrawals"
  ON public.withdrawal_requests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create withdrawals"
  ON public.withdrawal_requests FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Payment receipts: users see only their own
CREATE POLICY "Users can view own receipts"
  ON public.payment_receipts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can submit receipts"
  ON public.payment_receipts FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Orders: buyer, vendor, restaurant, rider can see their orders
CREATE POLICY "Users can view own orders"
  ON public.orders FOR SELECT USING (
    auth.uid() = buyer_id OR auth.uid() = vendor_id OR
    auth.uid() = restaurant_id OR auth.uid() = rider_id OR
    auth.uid() = realtor_id
  );
CREATE POLICY "Authenticated users can create orders"
  ON public.orders FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Notifications: users see only their own
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT USING (auth.uid() = user_id);

-- Chat: users see their own sessions
CREATE POLICY "Users can view own chat"
  ON public.chat_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create chat sessions"
  ON public.chat_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- TRIGGERS: Auto-create wallet & profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.wallets (user_id, balance)
  VALUES (NEW.id, 0)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- TRIGGER: Update wallet updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

CREATE TRIGGER wallets_updated_at BEFORE UPDATE ON public.wallets
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER orders_updated_at BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER products_updated_at BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
CREATE TRIGGER properties_updated_at BEFORE UPDATE ON public.properties
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- REALTIME PUBLICATIONS
-- ============================================================
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE
    public.orders,
    public.delivery_jobs,
    public.class_bookings,
    public.notifications,
    public.chat_messages,
    public.chat_sessions,
    public.payment_receipts,
    public.withdrawal_requests,
    public.disputes;
COMMIT;

-- ============================================================
-- FIRST ADMIN USER (run after creating your admin account)
-- Replace 'your-email@example.com' with your actual email
-- ============================================================
-- UPDATE public.profiles
-- SET role = 'admin'
-- WHERE email = 'your-email@example.com';

-- ============================================================
-- DONE! All 27 tables created.
-- ============================================================
