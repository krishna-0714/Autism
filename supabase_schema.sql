-- =============================================================================
-- AutiConnect Supabase One-Shot Master Schema
-- WARNING: This script wipes existing tables for a clean reset.
-- =============================================================================

-- 0. CLEAN RESET (Optional/Force)
-- Drop in reverse dependency order to avoid foreign key errors.
DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS user_models;
DROP TABLE IF EXISTS symbols;
DROP TABLE IF EXISTS rooms;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS families;

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. FAMILIES
CREATE TABLE families (
  id              TEXT PRIMARY KEY, -- 6-char family code
  created_at      BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
  caregiver_name  TEXT NOT NULL,
  caregiver_email TEXT NOT NULL UNIQUE,
  CONSTRAINT caregiver_email_format CHECK (caregiver_email LIKE '%@%.%')
);

CREATE INDEX idx_families_email ON families(caregiver_email);
ALTER TABLE families ENABLE ROW LEVEL SECURITY;

CREATE POLICY "families_select" ON families
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "families_insert" ON families
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- 3. USERS
CREATE TABLE users (
  id          TEXT PRIMARY KEY,
  family_id   TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  email       TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('caregiver', 'child')),
  device_id   TEXT,
  created_at  BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
  last_login  BIGINT,
  auth_uid    UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX idx_users_family ON users(family_id);
CREATE INDEX idx_users_auth_uid ON users(auth_uid);
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION current_user_family_id()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT family_id
  FROM users
  WHERE auth_uid = auth.uid()
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION current_user_family_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION current_user_family_id() TO authenticated;

CREATE POLICY "users_own_family" ON users
  FOR SELECT
  USING (family_id = current_user_family_id());

CREATE POLICY "users_insert_own" ON users
  FOR INSERT
  WITH CHECK (auth_uid = auth.uid());

CREATE POLICY "users_update_own" ON users
  FOR UPDATE
  USING (auth_uid = auth.uid())
  WITH CHECK (auth_uid = auth.uid());

-- 4. ROOMS
CREATE TABLE rooms (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id   TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  created_at  BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
  CONSTRAINT unique_room_per_family UNIQUE (family_id, name)
);

CREATE INDEX idx_rooms_family ON rooms(family_id);
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rooms_family" ON rooms
  FOR ALL
  USING (family_id = current_user_family_id())
  WITH CHECK (family_id = current_user_family_id());

-- 5. SYMBOLS
CREATE TABLE symbols (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id   TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  label       TEXT NOT NULL,
  category    TEXT NOT NULL DEFAULT 'general',
  room_id     UUID REFERENCES rooms(id) ON DELETE SET NULL,
  image_url   TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);

CREATE INDEX idx_symbols_family ON symbols(family_id);
CREATE INDEX idx_symbols_room ON symbols(room_id);
CREATE INDEX idx_symbols_category ON symbols(category);
ALTER TABLE symbols ENABLE ROW LEVEL SECURITY;

CREATE POLICY "symbols_family" ON symbols
  FOR ALL
  USING (family_id = current_user_family_id())
  WITH CHECK (family_id = current_user_family_id());

-- 6. MESSAGES
CREATE TABLE messages (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id            TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  symbol_id            TEXT NOT NULL,
  room_id              TEXT,
  sender_device_id     TEXT NOT NULL,
  detection_method     TEXT CHECK (detection_method IN ('wifi', 'manual', 'gps')),
  detection_confidence REAL CHECK (detection_confidence BETWEEN 0.0 AND 1.0),
  status               TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'acknowledged', 'resolved')),
  timestamp            BIGINT NOT NULL,
  created_at           BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);

CREATE INDEX idx_messages_family ON messages(family_id);
CREATE INDEX idx_messages_status ON messages(status);
CREATE INDEX idx_messages_timestamp ON messages(timestamp DESC);
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_family_select" ON messages
  FOR SELECT
  USING (family_id = current_user_family_id());

CREATE POLICY "messages_family_insert" ON messages
  FOR INSERT
  WITH CHECK (family_id = current_user_family_id());

CREATE POLICY "messages_caregiver_update" ON messages
  FOR UPDATE
  USING (family_id = current_user_family_id())
  WITH CHECK (family_id = current_user_family_id());

-- 7. USER MODELS (for backend Python KNN persistence)
CREATE TABLE user_models (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  model_bytes  TEXT NOT NULL,
  updated_at   BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);

ALTER TABLE user_models ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_models_select_own" ON user_models
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "user_models_insert_own" ON user_models
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_models_update_own" ON user_models
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 8. REALTIME
-- Enable Realtime for messages table.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  END IF;
END $$;

-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
