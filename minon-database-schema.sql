-- ============================================================
-- MINON SOLUTIONS — COMPLETE SUPABASE DATABASE SCHEMA
-- Run this entire file in Supabase SQL Editor
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM (
  'buyer', 'vendor', 'service_provider', 'dispatch_rider',
  'tutor', 'realtor', 'restaurant_owner', 'freelancer', 'admin'
);

CREATE TYPE verification_status AS ENUM ('pending', 'verified', 'rejected', 'suspended');
CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'in_transit', 'delivered', 'cancelled', 'disputed');
CREATE TYPE payment_status AS ENUM ('pending', 'receipt_uploaded', 'verified', 'rejected', 'refunded');
CREATE TYPE dispute_status AS ENUM ('open', 'under_review', 'resolved_refund', 'resolved_no_refund', 'closed');
CREATE TYPE withdrawal_status AS ENUM ('pending', 'approved', 'rejected', 'paid');
CREATE TYPE notification_type AS ENUM (
  'order_placed', 'order_confirmed', 'order_in_transit', 'order_delivered',
  'payment_verified', 'payment_rejected', 'dispute_opened', 'dispute_resolved',
  'withdrawal_approved', 'withdrawal_rejected', 'verification_approved',
  'verification_rejected', 'referral_bonus', 'new_message', 'live_chat_request',
  'new_review', 'new_listing', 'flash_sale', 'warning', 'general'
);
CREATE TYPE property_type AS ENUM ('house', 'apartment', 'land', 'shop', 'warehouse', 'office', 'shortlet', 'other');
CREATE TYPE listing_type AS ENUM ('sale', 'rent', 'shortlet', 'lease');
CREATE TYPE service_category AS ENUM ('plumbing', 'electrical', 'cleaning', 'repairs', 'carpentry', 'painting', 'other');
CREATE TYPE subscription_tier AS ENUM ('free', 'premium');
CREATE TYPE branch AS ENUM ('agency', 'logistics', 'study', 'market', 'place', 'services', 'realtors', 'academic');

-- ============================================================
-- 1. USERS & PROFILES
-- ============================================================

-- Core profiles (extends Supabase auth.users)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE,
  phone TEXT UNIQUE,
  full_name TEXT NOT NULL,
  username TEXT UNIQUE,
  role user_role NOT NULL DEFAULT 'buyer',
  avatar_url TEXT,
  cover_url TEXT,
  bio TEXT,
  location TEXT,
  state TEXT DEFAULT 'Anambra',
  city TEXT DEFAULT 'Awka',
  address TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  is_banned BOOLEAN DEFAULT FALSE,
  ban_reason TEXT,
  verification_status verification_status DEFAULT 'pending',
  subscription_tier subscription_tier DEFAULT 'free',
  premium_expires_at TIMESTAMPTZ,
  premium_trial_used BOOLEAN DEFAULT FALSE,
  referral_code TEXT UNIQUE DEFAULT upper(substring(gen_random_uuid()::text, 1, 8)),
  referred_by UUID REFERENCES profiles(id),
  terms_accepted BOOLEAN DEFAULT FALSE,
  terms_accepted_at TIMESTAMPTZ,
  tutorial_completed BOOLEAN DEFAULT FALSE,
  last_active_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vendor / Provider extra details
CREATE TABLE vendor_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  business_name TEXT NOT NULL,
  business_description TEXT,
  branch branch NOT NULL,
  nin TEXT,
  id_document_url TEXT,
  business_reg_url TEXT,
  phone_verified BOOLEAN DEFAULT FALSE,
  verification_fee_paid BOOLEAN DEFAULT FALSE,
  verification_fee_receipt_url TEXT,
  is_premium BOOLEAN DEFAULT FALSE,
  storefront_url TEXT UNIQUE,
  banner_url TEXT,
  total_sales NUMERIC DEFAULT 0,
  total_earnings NUMERIC DEFAULT 0,
  commission_owed NUMERIC DEFAULT 0,
  last_activity_at TIMESTAMPTZ DEFAULT NOW(),
  warning_count INT DEFAULT 0,
  last_warning_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. WALLET SYSTEM
-- ============================================================

CREATE TABLE wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  balance NUMERIC DEFAULT 0 CHECK (balance >= 0),
  total_earned NUMERIC DEFAULT 0,
  total_withdrawn NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE wallet_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  wallet_id UUID REFERENCES wallets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id),
  type TEXT NOT NULL CHECK (type IN ('credit', 'debit')),
  amount NUMERIC NOT NULL,
  description TEXT,
  reference TEXT UNIQUE,
  order_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Withdrawal requests
CREATE TABLE withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  amount NUMERIC NOT NULL CHECK (amount >= 5000),
  bank_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_name TEXT NOT NULL,
  status withdrawal_status DEFAULT 'pending',
  admin_note TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. REFERRAL SYSTEM
-- ============================================================

CREATE TABLE referrals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id UUID REFERENCES profiles(id),
  referred_id UUID REFERENCES profiles(id),
  bonus_amount NUMERIC DEFAULT 300,
  bonus_paid BOOLEAN DEFAULT FALSE,
  bonus_paid_at TIMESTAMPTZ,
  triggered_by_order_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. LISTINGS & PRODUCTS (Minon Market)
-- ============================================================

CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  price NUMERIC NOT NULL,
  negotiable BOOLEAN DEFAULT FALSE,
  category TEXT NOT NULL,
  sub_category TEXT,
  stock_qty INT DEFAULT 1,
  is_available BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  is_flash_sale BOOLEAN DEFAULT FALSE,
  flash_sale_price NUMERIC,
  flash_sale_ends_at TIMESTAMPTZ,
  discount_percent INT DEFAULT 0,
  views INT DEFAULT 0,
  total_sold INT DEFAULT 0,
  location TEXT,
  delivery_time TEXT DEFAULT '2 weeks maximum',
  media_urls TEXT[] DEFAULT '{}',
  video_url TEXT,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. SERVICES (Minon Services)
-- ============================================================

CREATE TABLE service_listings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  category service_category NOT NULL,
  pricing_type TEXT DEFAULT 'quote' CHECK (pricing_type IN ('fixed', 'quote')),
  base_price NUMERIC,
  is_available BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  location TEXT,
  media_urls TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. RESTAURANT & FOOD (Minon Place)
-- ============================================================

CREATE TABLE restaurants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  phone TEXT,
  logo_url TEXT,
  banner_url TEXT,
  opening_time TEXT,
  closing_time TEXT,
  is_open BOOLEAN DEFAULT TRUE,
  is_verified BOOLEAN DEFAULT FALSE,
  is_featured BOOLEAN DEFAULT FALSE,
  rating NUMERIC DEFAULT 0,
  total_orders INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE menu_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC NOT NULL,
  category TEXT,
  image_url TEXT,
  is_available BOOLEAN DEFAULT TRUE,
  is_flash_sale BOOLEAN DEFAULT FALSE,
  flash_sale_price NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. REAL ESTATE (Minon Realtors)
-- ============================================================

CREATE TABLE properties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  realtor_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  property_type property_type NOT NULL,
  listing_type listing_type NOT NULL,
  price NUMERIC NOT NULL,
  negotiable BOOLEAN DEFAULT FALSE,
  bedrooms INT,
  bathrooms INT,
  size_sqm NUMERIC,
  address TEXT,
  city TEXT,
  state TEXT,
  is_available BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  media_urls TEXT[] DEFAULT '{}',
  video_url TEXT,
  virtual_tour_url TEXT,
  views INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. STUDY SERVICES (Minon Study)
-- ============================================================

CREATE TABLE study_materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tutor_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  subject TEXT NOT NULL,
  category TEXT,
  material_type TEXT CHECK (material_type IN ('pdf', 'video', 'live_class')),
  price NUMERIC NOT NULL,
  file_url TEXT,
  thumbnail_url TEXT,
  total_purchases INT DEFAULT 0,
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE class_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES profiles(id),
  tutor_id UUID REFERENCES profiles(id),
  material_id UUID REFERENCES study_materials(id),
  scheduled_at TIMESTAMPTZ,
  duration_minutes INT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  payment_status payment_status DEFAULT 'pending',
  amount NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. AGENCY SERVICES (Minon Agency)
-- ============================================================

CREATE TABLE agency_services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  pricing_type TEXT DEFAULT 'fixed' CHECK (pricing_type IN ('fixed', 'quote', 'both')),
  price NUMERIC,
  price_label TEXT,
  features TEXT[] DEFAULT '{}',
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE agency_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id UUID REFERENCES profiles(id),
  freelancer_id UUID REFERENCES profiles(id),
  service_id UUID REFERENCES agency_services(id),
  requirements TEXT,
  budget NUMERIC,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'assigned', 'in_progress', 'completed', 'cancelled')),
  payment_status payment_status DEFAULT 'pending',
  amount NUMERIC,
  receipt_url TEXT,
  admin_verified BOOLEAN DEFAULT FALSE,
  deadline_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 10. LOGISTICS (Minon Logistics)
-- ============================================================

CREATE TABLE delivery_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id UUID REFERENCES profiles(id),
  rider_id UUID REFERENCES profiles(id),
  pickup_address TEXT NOT NULL,
  delivery_address TEXT NOT NULL,
  package_description TEXT,
  quoted_price NUMERIC,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'quoted', 'accepted', 'picked_up', 'in_transit', 'delivered', 'cancelled')),
  payment_status payment_status DEFAULT 'pending',
  receipt_url TEXT,
  admin_verified BOOLEAN DEFAULT FALSE,
  estimated_delivery TEXT DEFAULT '2 weeks maximum',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 11. ORDERS (Universal)
-- ============================================================

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  buyer_id UUID REFERENCES profiles(id),
  seller_id UUID REFERENCES profiles(id),
  branch branch NOT NULL,
  item_id UUID,
  item_title TEXT,
  quantity INT DEFAULT 1,
  unit_price NUMERIC NOT NULL,
  total_amount NUMERIC NOT NULL,
  commission_amount NUMERIC,
  seller_payout NUMERIC,
  status order_status DEFAULT 'pending',
  payment_status payment_status DEFAULT 'pending',
  receipt_url TEXT,
  receipt_verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES profiles(id),
  delivery_address TEXT,
  delivery_notes TEXT,
  estimated_delivery TEXT DEFAULT '2 weeks maximum',
  tracking_status TEXT DEFAULT 'Order Placed',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Payment receipts uploaded by customers
CREATE TABLE payment_receipts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id),
  user_id UUID REFERENCES profiles(id),
  receipt_url TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  sender_name TEXT NOT NULL,
  bank_name TEXT NOT NULL,
  transaction_date DATE NOT NULL,
  transaction_id TEXT,
  account_number TEXT,
  additional_notes TEXT,
  status payment_status DEFAULT 'receipt_uploaded',
  admin_note TEXT,
  verified_by UUID REFERENCES profiles(id),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 12. DISPUTES
-- ============================================================

CREATE TABLE disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id),
  raised_by UUID REFERENCES profiles(id),
  against UUID REFERENCES profiles(id),
  reason TEXT NOT NULL,
  description TEXT,
  evidence_urls TEXT[] DEFAULT '{}',
  status dispute_status DEFAULT 'open',
  admin_decision TEXT,
  resolved_by UUID REFERENCES profiles(id),
  resolved_at TIMESTAMPTZ,
  refund_issued BOOLEAN DEFAULT FALSE,
  refund_amount NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 13. REVIEWS & RATINGS
-- ============================================================

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID REFERENCES orders(id),
  reviewer_id UUID REFERENCES profiles(id),
  reviewed_id UUID REFERENCES profiles(id),
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  media_urls TEXT[] DEFAULT '{}',
  vendor_reply TEXT,
  vendor_replied_at TIMESTAMPTZ,
  is_visible BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 14. NOTIFICATIONS
-- ============================================================

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  type notification_type NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  link TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 15. LIVE CHAT SYSTEM
-- ============================================================

CREATE TABLE chat_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  admin_id UUID REFERENCES profiles(id),
  status TEXT DEFAULT 'ai' CHECK (status IN ('ai', 'requested', 'live', 'closed')),
  subject TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES profiles(id),
  sender_type TEXT CHECK (sender_type IN ('user', 'ai', 'admin')),
  message TEXT NOT NULL,
  media_url TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 16. REPORTS
-- ============================================================

CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id UUID REFERENCES profiles(id),
  reported_user_id UUID REFERENCES profiles(id),
  reported_listing_id UUID,
  listing_type TEXT,
  reason TEXT NOT NULL,
  description TEXT,
  evidence_urls TEXT[] DEFAULT '{}',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'action_taken', 'dismissed')),
  admin_note TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 17. PROMOTIONS & SALES EVENTS
-- ============================================================

CREATE TABLE promotions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vendor_id UUID REFERENCES profiles(id),
  title TEXT NOT NULL,
  description TEXT,
  promo_type TEXT CHECK (promo_type IN ('flash_sale', 'discount', 'black_friday', 'custom')),
  discount_percent INT,
  discount_code TEXT UNIQUE,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,
  is_admin_approved BOOLEAN DEFAULT FALSE,
  approved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Promoted / featured listings (admin controlled)
CREATE TABLE featured_listings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  listing_id UUID NOT NULL,
  listing_type TEXT NOT NULL,
  vendor_id UUID REFERENCES profiles(id),
  promoted_by UUID REFERENCES profiles(id),
  starts_at TIMESTAMPTZ DEFAULT NOW(),
  ends_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 18. BLOG / NEWS
-- ============================================================

CREATE TABLE blog_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID REFERENCES profiles(id),
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  content TEXT NOT NULL,
  excerpt TEXT,
  cover_url TEXT,
  tags TEXT[] DEFAULT '{}',
  is_published BOOLEAN DEFAULT FALSE,
  published_at TIMESTAMPTZ,
  views INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 19. WISHLIST / SAVED ITEMS
-- ============================================================

CREATE TABLE wishlists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  listing_id UUID NOT NULL,
  listing_type TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, listing_id)
);

-- ============================================================
-- 20. CAREERS
-- ============================================================

CREATE TABLE job_listings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  department TEXT,
  description TEXT,
  requirements TEXT,
  location TEXT DEFAULT 'Awka, Anambra',
  job_type TEXT DEFAULT 'full_time',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE job_applications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES job_listings(id),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  cv_url TEXT,
  cover_letter TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'shortlisted', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 21. CONTACT FORM
-- ============================================================

CREATE TABLE contact_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  subject TEXT,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  replied_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 22. COOKIE CONSENT
-- ============================================================

CREATE TABLE cookie_consents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  ip_address TEXT,
  accepted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Auto-create wallet on profile creation
CREATE OR REPLACE FUNCTION create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO wallets (user_id, balance) VALUES (NEW.id, 0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION create_wallet_for_new_user();

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER wallets_updated_at BEFORE UPDATE ON wallets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER orders_updated_at BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER chat_sessions_updated_at BEFORE UPDATE ON chat_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-calculate commission on order (2%)
CREATE OR REPLACE FUNCTION calculate_order_commission()
RETURNS TRIGGER AS $$
BEGIN
  NEW.commission_amount = ROUND(NEW.total_amount * 0.02, 2);
  NEW.seller_payout = NEW.total_amount - NEW.commission_amount;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_commission
  BEFORE INSERT OR UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION calculate_order_commission();

-- Auto-pay referral bonus when first order is verified
CREATE OR REPLACE FUNCTION process_referral_bonus()
RETURNS TRIGGER AS $$
DECLARE
  ref RECORD;
BEGIN
  IF NEW.payment_status = 'verified' AND OLD.payment_status != 'verified' THEN
    SELECT * INTO ref FROM referrals
    WHERE referred_id = NEW.buyer_id AND bonus_paid = FALSE
    LIMIT 1;

    IF ref.id IS NOT NULL THEN
      UPDATE wallets SET balance = balance + 300, total_earned = total_earned + 300
      WHERE user_id = ref.referrer_id;

      UPDATE referrals SET bonus_paid = TRUE, bonus_paid_at = NOW(), triggered_by_order_id = NEW.id
      WHERE id = ref.id;

      INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, description, reference)
      SELECT id, ref.referrer_id, 'credit', 300, 'Referral bonus for verified order', 'REF-' || gen_random_uuid()
      FROM wallets WHERE user_id = ref.referrer_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER order_referral_bonus
  AFTER UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION process_referral_bonus();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlists ENABLE ROW LEVEL SECURITY;

-- Profiles: users see own, admin sees all, public sees basic info
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Public can view basic profiles" ON profiles FOR SELECT USING (is_active = TRUE AND is_banned = FALSE);

-- Wallets: only owner
CREATE POLICY "Users can view own wallet" ON wallets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view own transactions" ON wallet_transactions FOR SELECT USING (auth.uid() = user_id);

-- Orders: buyer or seller can see
CREATE POLICY "Buyers and sellers can view orders" ON orders FOR SELECT USING (auth.uid() = buyer_id OR auth.uid() = seller_id);
CREATE POLICY "Buyers can create orders" ON orders FOR INSERT WITH CHECK (auth.uid() = buyer_id);

-- Notifications: only recipient
CREATE POLICY "Users see own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- Products: public can view, vendor manages own
CREATE POLICY "Anyone can view products" ON products FOR SELECT USING (is_available = TRUE);
CREATE POLICY "Vendors manage own products" ON products FOR ALL USING (auth.uid() = vendor_id);

-- Chat: participant only
CREATE POLICY "Users see own chat sessions" ON chat_sessions FOR SELECT USING (auth.uid() = user_id OR auth.uid() = admin_id);
CREATE POLICY "Users see own chat messages" ON chat_messages FOR SELECT USING (
  session_id IN (SELECT id FROM chat_sessions WHERE user_id = auth.uid() OR admin_id = auth.uid())
);

-- Wishlists: private to user
CREATE POLICY "Users manage own wishlist" ON wishlists FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- SEED DATA — Agency Services
-- ============================================================

INSERT INTO agency_services (name, description, category, pricing_type, price, price_label, features, sort_order) VALUES
('Meta Ads Starter', 'Perfect for businesses just starting with paid advertising', 'Meta Ads', 'fixed', 20000, '₦20,000', ARRAY['3 Static Creatives', '1 Campaign (7 Days)', '₦10,000 Ad Spend', '8k-20k Impressions', '150-400 Engagements'], 1),
('Meta Ads Growth', 'Scale your reach with mixed creative formats', 'Meta Ads', 'fixed', 40000, '₦40,000', ARRAY['6 Creatives (Static+Videos)', '2 Campaigns (14 Days)', '₦25,000 Ad Spend', '25k-60k Impressions', '400-1k Clicks/Leads'], 2),
('Meta Ads Premium', 'Advanced campaigns with retargeting', 'Meta Ads', 'fixed', 60000, '₦60,000', ARRAY['10 Premium Creatives', '3 Campaigns + Retargeting', '₦40,000 Ad Spend', '40k-120k+ Impressions', '800-2.5k Interactions'], 3),
('Meta Ads Pro', 'High-end campaigns with trackable ROI', 'Meta Ads', 'fixed', 85000, '₦85,000', ARRAY['15 High-End Creatives', 'Advanced Campaigns (30 Days)', '₦60,000 Ad Spend', 'Trackable Leads & Sales', 'Strong ROI'], 4),
('Meta Ads Enterprise', 'Full monthly management for serious brands', 'Meta Ads', 'fixed', 120000, '₦120,000+/month', ARRAY['Unlimited Creatives & Campaigns', 'Full Monthly Management', '₦80k-₦100k+ Ad Spend', 'Consistent Brand Growth', 'Dedicated Account Manager'], 5),
('Business Name Registration (CAC)', 'Register your business name officially', 'CAC Registration', 'fixed', 30000, '₦30,000', ARRAY['Certificate', 'Status Report', 'Fast Processing'], 6),
('Limited Company (LTD)', 'Full company registration with 1m shares', 'CAC Registration', 'fixed', 50000, '₦50,000', ARRAY['Certificate', 'MEMART', 'Status Report', '1 Million Shares'], 7),
('NGO / Church / Mosque Registration', 'Non-profit incorporation with all documents', 'CAC Registration', 'fixed', 130000, '₦130,000', ARRAY['Incorporated Trustees', 'Constitution', 'Newspaper Publication'], 8),
('SCUML Certificate (EFCC)', 'Anti-Money Laundering compliance certificate', 'CAC Registration', 'fixed', 30000, '₦30,000', ARRAY['EFCC Compliance', 'Fast Processing'], 9),
('Trademark Registration', 'Protect your brand legally', 'CAC Registration', 'fixed', 50000, '₦50,000', ARRAY['Brand Protection', 'Official Trademark Certificate'], 10),
('Social Media Management', 'Full management of your social media presence', 'Digital Services', 'quote', NULL, 'Get a Quote', ARRAY['Content Creation', 'Posting Schedule', 'Engagement', 'Monthly Report'], 11),
('Logo Design & Branding', 'Professional logo and brand identity', 'Digital Services', 'both', NULL, 'From ₦15,000', ARRAY['Logo Design', 'Brand Colors', 'Brand Guidelines', 'Multiple Formats'], 12),
('Flyer & Graphic Design', 'Eye-catching designs for your business', 'Digital Services', 'both', NULL, 'From ₦5,000', ARRAY['Print-ready Files', 'Multiple Formats', 'Quick Turnaround'], 13),
('Video Editing & Content', 'Professional video editing for social media', 'Digital Services', 'quote', NULL, 'Get a Quote', ARRAY['Short-form Videos', 'Reels & TikToks', 'Color Grading', 'Subtitles'], 14),
('Website Design', 'Modern, mobile-friendly websites', 'Digital Services', 'quote', NULL, 'Get a Quote', ARRAY['Responsive Design', 'SEO Ready', 'Fast Loading', 'Admin Panel'], 15),
('Business Visibility Package', 'Boost your business presence online and offline', 'Visibility', 'quote', NULL, 'Get a Quote', ARRAY['Social Media Boost', 'Featured Listing', 'Content Creation', 'Brand Strategy'], 16),
('IT Placements', 'Connect businesses with skilled IT professionals', 'Placements', 'quote', NULL, 'Get a Quote', ARRAY['Vetted Candidates', 'Skill Assessment', 'Placement Support'], 17),
('Project & Assignment Help', 'Academic and professional project support', 'Study', 'quote', NULL, 'Get a Quote', ARRAY['Research', 'Writing', 'Presentations', 'Fast Delivery'], 18),
('University Assignment Help', 'Coursework, take-home tests and daily assignments', 'Academic', 'fixed', 3000, 'From ₦3,000', ARRAY['All Subjects', '100-500 Level', '24-72hr Delivery'], 19),
('IT/SIWES Report Writing', 'Industrial Training report fully written and formatted', 'Academic', 'fixed', 8000, 'From ₦8,000', ARRAY['Full Report', 'Proper Formatting', '3-7 Days'], 20),
('Final Year Project (FYP)', 'Complete final year project with all chapters', 'Academic', 'fixed', 25000, 'From ₦25,000', ARRAY['All Chapters', 'Literature Review', 'Methodology', 'Data Analysis'], 21),
('Research Paper Writing', 'Academic research with proper citations', 'Academic', 'fixed', 12000, 'From ₦12,000', ARRAY['APA/MLA/Harvard', 'Literature Review', '5-7 Days'], 22),
('MSc/MBA Thesis', 'Full postgraduate dissertation', 'Academic', 'fixed', 80000, 'From ₦80,000', ARRAY['80-150 Pages', 'Data Analysis', 'Proper References', '3-6 Weeks'], 23),
('Proofreading & Editing', 'Grammar correction and formatting of your existing work', 'Academic', 'fixed', 2000, 'From ₦2,000', ARRAY['Grammar Fix', 'Restructuring', 'APA Formatting', 'Plagiarism Reduction'], 24),
('PowerPoint Presentation', 'Professional slides for seminar or project defence', 'Academic', 'fixed', 5000, 'From ₦5,000', ARRAY['Clean Design', 'All Levels', '24-48 Hours'], 25);

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_referral_code ON profiles(referral_code);
CREATE INDEX idx_products_vendor ON products(vendor_id);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_featured ON products(is_featured);
CREATE INDEX idx_orders_buyer ON orders(buyer_id);
CREATE INDEX idx_orders_seller ON orders(seller_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);
CREATE INDEX idx_chat_messages_session ON chat_messages(session_id);
CREATE INDEX idx_reviews_reviewed ON reviews(reviewed_id);
CREATE INDEX idx_blog_posts_slug ON blog_posts(slug);
CREATE INDEX idx_properties_type ON properties(listing_type, property_type);
CREATE INDEX idx_wallet_transactions_user ON wallet_transactions(user_id);

-- ============================================================
-- END OF SCHEMA
-- ============================================================
-- Total tables: 32
-- Total triggers: 6
-- Total functions: 4
-- Total RLS policies: 12
-- Ready for: Supabase Auth, Edge Functions, Realtime
-- ============================================================
