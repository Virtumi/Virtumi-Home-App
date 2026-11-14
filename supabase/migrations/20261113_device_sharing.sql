-- Device sharing: owners can grant other users access to homes, floors,
-- rooms or single devices.
--
-- * Access is evaluated dynamically via public.shared_device_paths().
-- * Additional permissive RLS policies are added; existing policies are untouched.
-- * Writes by shared users are stored with the ORIGINAL owner user_id
--   (trigger), because target devices filter realtime events by that user_id.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL DEFAULT auth.uid()
    REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_with_user_id UUID NOT NULL
    REFERENCES auth.users(id) ON DELETE CASCADE,
  scope_type TEXT NOT NULL CHECK (scope_type IN ('home', 'floor', 'room', 'device')),
  scope_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT device_shares_not_self CHECK (owner_id <> shared_with_user_id),
  CONSTRAINT device_shares_unique UNIQUE (shared_with_user_id, scope_type, scope_id)
);

CREATE INDEX IF NOT EXISTS device_shares_owner_idx
  ON public.device_shares (owner_id);
CREATE INDEX IF NOT EXISTS device_shares_shared_with_idx
  ON public.device_shares (shared_with_user_id);

ALTER TABLE public.device_shares ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2. Helper functions (SECURITY DEFINER, bypass RLS)
-- ---------------------------------------------------------------------------

-- All devices (with their location path) the current user may access through
-- a share. Shares are dynamic: new devices in a shared room appear at once.
CREATE OR REPLACE FUNCTION public.shared_device_paths()
RETURNS TABLE (
  device_id UUID,
  device_type_id UUID,
  room_id UUID,
  floor_id UUID,
  home_id UUID
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT d.id, d.device_type_id, r.id, f.id, f.home_id
  FROM public.devices d
  JOIN public.device_types dt ON dt.id = d.device_type_id
  JOIN public.rooms r ON r.id = dt.room_id
  JOIN public.floors f ON f.id = r.floor_id
  WHERE EXISTS (
    SELECT 1
    FROM public.device_shares s
    WHERE s.shared_with_user_id = auth.uid()
      AND (
        (s.scope_type = 'device' AND s.scope_id = d.id)
        OR (s.scope_type = 'room' AND s.scope_id = r.id)
        OR (s.scope_type = 'floor' AND s.scope_id = f.id)
        OR (s.scope_type = 'home' AND s.scope_id = f.home_id)
      )
  );
$$;

-- Original owner of a device (the user_id target devices filter on).
CREATE OR REPLACE FUNCTION public.device_owner_id(p_device_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(d.user_id, h.user_id)
  FROM public.devices d
  LEFT JOIN public.device_types dt ON dt.id = d.device_type_id
  LEFT JOIN public.rooms r ON r.id = dt.room_id
  LEFT JOIN public.floors f ON f.id = r.floor_id
  LEFT JOIN public.homes h ON h.id = f.home_id
  WHERE d.id = p_device_id;
$$;

-- True when the current user owns the device (device or home owner).
CREATE OR REPLACE FUNCTION public.is_device_owner(p_device_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.devices d
    LEFT JOIN public.device_types dt ON dt.id = d.device_type_id
    LEFT JOIN public.rooms r ON r.id = dt.room_id
    LEFT JOIN public.floors f ON f.id = r.floor_id
    LEFT JOIN public.homes h ON h.id = f.home_id
    WHERE d.id = p_device_id
      AND (d.user_id = auth.uid() OR h.user_id = auth.uid())
  );
$$;

-- True when the current user owns the given share scope.
CREATE OR REPLACE FUNCTION public.owns_share_scope(p_type TEXT, p_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE p_type
    WHEN 'home' THEN EXISTS (
      SELECT 1 FROM public.homes h
      WHERE h.id = p_id AND h.user_id = auth.uid()
    )
    WHEN 'floor' THEN EXISTS (
      SELECT 1 FROM public.floors f
      JOIN public.homes h ON h.id = f.home_id
      WHERE f.id = p_id AND h.user_id = auth.uid()
    )
    WHEN 'room' THEN EXISTS (
      SELECT 1 FROM public.rooms r
      JOIN public.floors f ON f.id = r.floor_id
      JOIN public.homes h ON h.id = f.home_id
      WHERE r.id = p_id AND h.user_id = auth.uid()
    )
    WHEN 'device' THEN public.is_device_owner(p_id)
    ELSE FALSE
  END;
$$;

-- Display name of a share scope.
CREATE OR REPLACE FUNCTION public.share_scope_name(p_type TEXT, p_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE p_type
    WHEN 'home' THEN (SELECT h.name::text FROM public.homes h WHERE h.id = p_id)
    WHEN 'floor' THEN (SELECT f.name::text FROM public.floors f WHERE f.id = p_id)
    WHEN 'room' THEN (SELECT r.name::text FROM public.rooms r WHERE r.id = p_id)
    WHEN 'device' THEN (
      SELECT COALESCE(NULLIF(d.devicename, ''), d.name::text)
      FROM public.devices d WHERE d.id = p_id
    )
  END;
$$;

-- Location path of a share scope (parents only, e.g. "Haus / Etage").
CREATE OR REPLACE FUNCTION public.share_scope_path(p_type TEXT, p_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE p_type
    WHEN 'floor' THEN (
      SELECT h.name::text
      FROM public.floors f JOIN public.homes h ON h.id = f.home_id
      WHERE f.id = p_id
    )
    WHEN 'room' THEN (
      SELECT h.name::text || ' / ' || f.name::text
      FROM public.rooms r
      JOIN public.floors f ON f.id = r.floor_id
      JOIN public.homes h ON h.id = f.home_id
      WHERE r.id = p_id
    )
    WHEN 'device' THEN (
      SELECT h.name::text || ' / ' || f.name::text || ' / ' || r.name::text
      FROM public.devices d
      JOIN public.device_types dt ON dt.id = d.device_type_id
      JOIN public.rooms r ON r.id = dt.room_id
      JOIN public.floors f ON f.id = r.floor_id
      JOIN public.homes h ON h.id = f.home_id
      WHERE d.id = p_id
    )
    ELSE NULL
  END;
$$;

-- ---------------------------------------------------------------------------
-- 3. RPCs used by the app
-- ---------------------------------------------------------------------------

-- Partial search over first name, last name and e-mail (min. 3 characters).
CREATE OR REPLACE FUNCTION public.search_users(p_query TEXT)
RETURNS TABLE (
  user_id UUID,
  first_name TEXT,
  last_name TEXT,
  email TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_term TEXT := btrim(COALESCE(p_query, ''));
  v_pattern TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF char_length(v_term) < 3 THEN
    RETURN;
  END IF;

  v_pattern := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';

  RETURN QUERY
  SELECT
    u.id,
    COALESCE(p.first_name, '')::text,
    COALESCE(p.last_name, '')::text,
    COALESCE(u.email, '')::text
  FROM auth.users u
  LEFT JOIN public.user_profiles p ON p.user_id = u.id
  WHERE u.id <> auth.uid()
    AND u.deleted_at IS NULL
    AND (
      u.email ILIKE v_pattern
      OR COALESCE(p.first_name, '') ILIKE v_pattern
      OR COALESCE(p.last_name, '') ILIKE v_pattern
      OR (COALESCE(p.first_name, '') || ' ' || COALESCE(p.last_name, '')) ILIKE v_pattern
      OR (COALESCE(p.last_name, '') || ' ' || COALESCE(p.first_name, '')) ILIKE v_pattern
    )
  ORDER BY p.last_name NULLS LAST, p.first_name NULLS LAST, u.email
  LIMIT 20;
END;
$$;

-- Shares created by the current user (counterpart = recipient).
CREATE OR REPLACE FUNCTION public.list_my_shares()
RETURNS TABLE (
  id UUID,
  counterpart_user_id UUID,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  scope_type TEXT,
  scope_id UUID,
  scope_name TEXT,
  scope_path TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id,
    s.shared_with_user_id,
    COALESCE(p.first_name, '')::text,
    COALESCE(p.last_name, '')::text,
    COALESCE(u.email, '')::text,
    s.scope_type,
    s.scope_id,
    COALESCE(public.share_scope_name(s.scope_type, s.scope_id), '')::text,
    public.share_scope_path(s.scope_type, s.scope_id),
    s.created_at
  FROM public.device_shares s
  JOIN auth.users u ON u.id = s.shared_with_user_id
  LEFT JOIN public.user_profiles p ON p.user_id = s.shared_with_user_id
  WHERE s.owner_id = auth.uid()
  ORDER BY p.last_name NULLS LAST, p.first_name NULLS LAST, u.email, s.created_at;
$$;

-- Shares granted to the current user (counterpart = owner).
CREATE OR REPLACE FUNCTION public.list_shares_with_me()
RETURNS TABLE (
  id UUID,
  counterpart_user_id UUID,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  scope_type TEXT,
  scope_id UUID,
  scope_name TEXT,
  scope_path TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id,
    s.owner_id,
    COALESCE(p.first_name, '')::text,
    COALESCE(p.last_name, '')::text,
    COALESCE(u.email, '')::text,
    s.scope_type,
    s.scope_id,
    COALESCE(public.share_scope_name(s.scope_type, s.scope_id), '')::text,
    public.share_scope_path(s.scope_type, s.scope_id),
    s.created_at
  FROM public.device_shares s
  JOIN auth.users u ON u.id = s.owner_id
  LEFT JOIN public.user_profiles p ON p.user_id = s.owner_id
  WHERE s.shared_with_user_id = auth.uid()
  ORDER BY p.last_name NULLS LAST, p.first_name NULLS LAST, u.email, s.created_at;
$$;

-- ---------------------------------------------------------------------------
-- 4. Policies on device_shares
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Owners manage own shares" ON public.device_shares;
CREATE POLICY "Owners manage own shares"
  ON public.device_shares
  FOR ALL
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (
    owner_id = auth.uid()
    AND public.owns_share_scope(scope_type, scope_id)
  );

DROP POLICY IF EXISTS "Recipients can leave shares" ON public.device_shares;
CREATE POLICY "Recipients can leave shares"
  ON public.device_shares
  FOR DELETE
  TO authenticated
  USING (shared_with_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 5. Additional RLS policies for shared access
-- ---------------------------------------------------------------------------

-- Device-bound tables: full access to configuration/data of shared devices.
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'cp_btn_requests', 'cp_general_settings', 'cp_parameters',
    'device_data', 'device_datetime_settings', 'device_location_settings',
    'device_mqtt_settings', 'device_network_settings', 'device_settings',
    'device_softap_details', 'device_softap_settings',
    'device_station_details', 'device_station_settings',
    'device_update_status', 'device_virtumi_cloud_settings',
    'ems_general_settings', 'ems_sensordata', 'ems_sensordata_history',
    'matter_requests', 'matter_settings',
    'smart_led_general_settings', 'smart_led_settings', 'smart_led_triggers',
    'update_requests', 'update_settings'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "shared_device_access" ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY "shared_device_access" ON public.%I '
      'FOR ALL TO authenticated '
      'USING (device_id IN (SELECT device_id FROM public.shared_device_paths())) '
      'WITH CHECK (device_id IN (SELECT device_id FROM public.shared_device_paths()))',
      t
    );
  END LOOP;
END $$;

-- Structure tables: read-only for shared users.
DROP POLICY IF EXISTS "shared_home_read" ON public.homes;
CREATE POLICY "shared_home_read" ON public.homes
  FOR SELECT TO authenticated
  USING (id IN (SELECT home_id FROM public.shared_device_paths()));

DROP POLICY IF EXISTS "shared_floor_read" ON public.floors;
CREATE POLICY "shared_floor_read" ON public.floors
  FOR SELECT TO authenticated
  USING (id IN (SELECT floor_id FROM public.shared_device_paths()));

DROP POLICY IF EXISTS "shared_room_read" ON public.rooms;
CREATE POLICY "shared_room_read" ON public.rooms
  FOR SELECT TO authenticated
  USING (id IN (SELECT room_id FROM public.shared_device_paths()));

DROP POLICY IF EXISTS "shared_device_type_read" ON public.device_types;
CREATE POLICY "shared_device_type_read" ON public.device_types
  FOR SELECT TO authenticated
  USING (id IN (SELECT device_type_id FROM public.shared_device_paths()));

-- Devices: read and update (no insert, no delete).
DROP POLICY IF EXISTS "shared_device_read" ON public.devices;
CREATE POLICY "shared_device_read" ON public.devices
  FOR SELECT TO authenticated
  USING (id IN (SELECT device_id FROM public.shared_device_paths()));

DROP POLICY IF EXISTS "shared_device_update" ON public.devices;
CREATE POLICY "shared_device_update" ON public.devices
  FOR UPDATE TO authenticated
  USING (id IN (SELECT device_id FROM public.shared_device_paths()))
  WITH CHECK (id IN (SELECT device_id FROM public.shared_device_paths()));

-- ---------------------------------------------------------------------------
-- 6. Triggers
-- ---------------------------------------------------------------------------

-- Always store the ORIGINAL owner user_id: target devices filter realtime
-- events by it, so rows written by shared users must carry the owner id.
CREATE OR REPLACE FUNCTION public.enforce_device_owner_user_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner UUID;
BEGIN
  IF NEW.device_id IS NOT NULL THEN
    v_owner := public.device_owner_id(NEW.device_id);
    IF v_owner IS NOT NULL THEN
      NEW.user_id := v_owner;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'cp_btn_requests', 'cp_general_settings', 'cp_parameters',
    'device_datetime_settings', 'device_location_settings',
    'device_mqtt_settings', 'device_network_settings',
    'device_softap_details', 'device_softap_settings',
    'device_station_details', 'device_station_settings',
    'device_update_status', 'device_virtumi_cloud_settings',
    'ems_general_settings', 'ems_sensordata', 'ems_sensordata_history',
    'matter_requests', 'matter_settings',
    'smart_led_general_settings', 'smart_led_settings', 'smart_led_triggers',
    'update_requests', 'update_settings'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS aa_enforce_device_owner_user_id ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER aa_enforce_device_owner_user_id '
      'BEFORE INSERT OR UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.enforce_device_owner_user_id()',
      t
    );
  END LOOP;
END $$;

-- Shared users must not reassign a device (owner / location).
CREATE OR REPLACE FUNCTION public.guard_shared_device_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_device_owner(OLD.id) THEN
    NEW.user_id := OLD.user_id;
    NEW.device_type_id := OLD.device_type_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS aa_guard_shared_device_update ON public.devices;
CREATE TRIGGER aa_guard_shared_device_update
  BEFORE UPDATE ON public.devices
  FOR EACH ROW EXECUTE FUNCTION public.guard_shared_device_update();

-- Remove shares whose scope no longer exists.
CREATE OR REPLACE FUNCTION public.cleanup_device_shares()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.device_shares
  WHERE scope_type = TG_ARGV[0] AND scope_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS cleanup_shares_home ON public.homes;
CREATE TRIGGER cleanup_shares_home AFTER DELETE ON public.homes
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_device_shares('home');
DROP TRIGGER IF EXISTS cleanup_shares_floor ON public.floors;
CREATE TRIGGER cleanup_shares_floor AFTER DELETE ON public.floors
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_device_shares('floor');
DROP TRIGGER IF EXISTS cleanup_shares_room ON public.rooms;
CREATE TRIGGER cleanup_shares_room AFTER DELETE ON public.rooms
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_device_shares('room');
DROP TRIGGER IF EXISTS cleanup_shares_device ON public.devices;
CREATE TRIGGER cleanup_shares_device AFTER DELETE ON public.devices
  FOR EACH ROW EXECUTE FUNCTION public.cleanup_device_shares('device');

-- ---------------------------------------------------------------------------
-- 7. Function privileges
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION
  public.shared_device_paths(),
  public.device_owner_id(UUID),
  public.is_device_owner(UUID),
  public.owns_share_scope(TEXT, UUID),
  public.share_scope_name(TEXT, UUID),
  public.share_scope_path(TEXT, UUID),
  public.search_users(TEXT),
  public.list_my_shares(),
  public.list_shares_with_me(),
  public.enforce_device_owner_user_id(),
  public.guard_shared_device_update(),
  public.cleanup_device_shares()
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.shared_device_paths(),
  public.device_owner_id(UUID),
  public.is_device_owner(UUID),
  public.owns_share_scope(TEXT, UUID),
  public.share_scope_name(TEXT, UUID),
  public.share_scope_path(TEXT, UUID),
  public.search_users(TEXT),
  public.list_my_shares(),
  public.list_shares_with_me()
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_shares TO authenticated;

-- Internal helpers: only called from other SECURITY DEFINER functions or
-- triggers, never directly by clients (also avoids leaking owner ids).
REVOKE EXECUTE ON FUNCTION
  public.enforce_device_owner_user_id(),
  public.guard_shared_device_update(),
  public.cleanup_device_shares(),
  public.device_owner_id(UUID),
  public.is_device_owner(UUID),
  public.share_scope_name(TEXT, UUID),
  public.share_scope_path(TEXT, UUID)
FROM PUBLIC, anon, authenticated;
