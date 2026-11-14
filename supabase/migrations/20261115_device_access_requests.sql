-- Device access requests: a user who finds a device that already belongs to
-- another account can ask the owner for access to exactly this device.
--
-- * public.device_access_requests  - one row per request (pending/approved/declined)
-- * public.app_notifications       - generic in-app inbox (bell icon in the app)
-- * RPCs (SECURITY DEFINER): find_device_owner, request_device_access,
--   get_device_access_request, respond_device_access_request,
--   list_notifications
--
-- Approving a request creates a plain device share (scope_type = 'device')
-- in public.device_shares, so the existing sharing logic/RLS applies.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.device_access_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL DEFAULT auth.uid()
    REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ,
  CONSTRAINT device_access_requests_not_self CHECK (owner_id <> requester_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS device_access_requests_one_pending_idx
  ON public.device_access_requests (device_id, requester_id)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS device_access_requests_owner_idx
  ON public.device_access_requests (owner_id);
CREATE INDEX IF NOT EXISTS device_access_requests_requester_idx
  ON public.device_access_requests (requester_id);

CREATE TABLE IF NOT EXISTS public.app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (
    'device_access_request',
    'device_access_approved',
    'device_access_declined'
  )),
  request_id UUID REFERENCES public.device_access_requests(id) ON DELETE CASCADE,
  device_name TEXT NOT NULL DEFAULT '',
  actor_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS app_notifications_user_idx
  ON public.app_notifications (user_id, created_at DESC);

ALTER TABLE public.device_access_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2. Policies / privileges (writes only through the RPCs below)
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.device_access_requests FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.app_notifications FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.device_access_requests TO authenticated;
GRANT SELECT ON public.app_notifications TO authenticated;
-- Recipients may only mark their own notifications as read.
GRANT UPDATE (read_at) ON public.app_notifications TO authenticated;

DROP POLICY IF EXISTS "Parties read own requests" ON public.device_access_requests;
CREATE POLICY "Parties read own requests"
  ON public.device_access_requests
  FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid() OR requester_id = auth.uid());

DROP POLICY IF EXISTS "Recipients read own notifications" ON public.app_notifications;
CREATE POLICY "Recipients read own notifications"
  ON public.app_notifications
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Recipients mark own notifications read" ON public.app_notifications;
CREATE POLICY "Recipients mark own notifications read"
  ON public.app_notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Realtime: live unread counter in the app.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'app_notifications'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_notifications;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3. RPCs
-- ---------------------------------------------------------------------------

-- Who owns the device with this MAC? Only answers when the caller also knows
-- the device password (device_code), so MACs alone reveal nothing.
CREATE OR REPLACE FUNCTION public.find_device_owner(
  p_mac TEXT,
  p_device_code TEXT
)
RETURNS TABLE (
  device_id UUID,
  device_name TEXT,
  owner_user_id UUID,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  is_self BOOLEAN,
  already_shared BOOLEAN,
  has_pending_request BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mac TEXT := upper(btrim(COALESCE(p_mac, '')));
  v_code TEXT := COALESCE(p_device_code, '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF v_mac = '' OR v_code = '' THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    COALESCE(NULLIF(d.devicename, ''), d.name::text)::text,
    o.owner_id,
    COALESCE(p.first_name, '')::text,
    COALESCE(p.last_name, '')::text,
    COALESCE(u.email, '')::text,
    (o.owner_id = auth.uid()),
    EXISTS (
      SELECT 1 FROM public.shared_device_paths() sp WHERE sp.device_id = d.id
    ),
    EXISTS (
      SELECT 1 FROM public.device_access_requests r
      WHERE r.device_id = d.id
        AND r.requester_id = auth.uid()
        AND r.status = 'pending'
    )
  FROM public.devices d
  CROSS JOIN LATERAL (
    SELECT public.device_owner_id(d.id) AS owner_id
  ) o
  JOIN auth.users u ON u.id = o.owner_id
  LEFT JOIN public.user_profiles p ON p.user_id = o.owner_id
  WHERE upper(btrim(COALESCE(d.mac_address, ''))) = v_mac
    AND d.device_code = v_code
    AND o.owner_id IS NOT NULL
  ORDER BY d.updated_at DESC NULLS LAST
  LIMIT 1;
END;
$$;

-- Creates a request for access to a single device and notifies the owner.
CREATE OR REPLACE FUNCTION public.request_device_access(p_device_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_owner UUID;
  v_name TEXT;
  v_request UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT public.device_owner_id(d.id),
         COALESCE(NULLIF(d.devicename, ''), d.name::text)
    INTO v_owner, v_name
  FROM public.devices d
  WHERE d.id = p_device_id;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'device_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_owner = v_uid THEN
    RAISE EXCEPTION 'already_owner' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.shared_device_paths() sp WHERE sp.device_id = p_device_id
  ) THEN
    RAISE EXCEPTION 'already_shared' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.device_access_requests r
    WHERE r.device_id = p_device_id
      AND r.requester_id = v_uid
      AND r.status = 'pending'
  ) THEN
    RAISE EXCEPTION 'request_pending' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.device_access_requests (device_id, owner_id, requester_id)
  VALUES (p_device_id, v_owner, v_uid)
  RETURNING id INTO v_request;

  INSERT INTO public.app_notifications (
    user_id, type, request_id, device_name, actor_user_id
  )
  VALUES (
    v_owner, 'device_access_request', v_request, COALESCE(v_name, ''), v_uid
  );

  RETURN v_request;
END;
$$;

-- Details of one request; visible to the owner and to the requester only.
CREATE OR REPLACE FUNCTION public.get_device_access_request(p_id UUID)
RETURNS TABLE (
  id UUID,
  status TEXT,
  device_id UUID,
  device_name TEXT,
  device_path TEXT,
  owner_id UUID,
  requester_id UUID,
  requester_first_name TEXT,
  requester_last_name TEXT,
  requester_email TEXT,
  created_at TIMESTAMPTZ,
  responded_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    r.id,
    r.status,
    r.device_id,
    COALESCE(public.share_scope_name('device', r.device_id), '')::text,
    public.share_scope_path('device', r.device_id),
    r.owner_id,
    r.requester_id,
    COALESCE(p.first_name, '')::text,
    COALESCE(p.last_name, '')::text,
    COALESCE(u.email, '')::text,
    r.created_at,
    r.responded_at
  FROM public.device_access_requests r
  JOIN auth.users u ON u.id = r.requester_id
  LEFT JOIN public.user_profiles p ON p.user_id = r.requester_id
  WHERE r.id = p_id
    AND (r.owner_id = auth.uid() OR r.requester_id = auth.uid());
$$;

-- Owner decision. Approving grants the requester a plain device share.
CREATE OR REPLACE FUNCTION public.respond_device_access_request(
  p_id UUID,
  p_approve BOOLEAN
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_req public.device_access_requests%ROWTYPE;
  v_status TEXT;
  v_name TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_req
  FROM public.device_access_requests
  WHERE id = p_id
  FOR UPDATE;

  IF NOT FOUND OR v_req.owner_id <> v_uid THEN
    RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'request_already_answered' USING ERRCODE = 'P0001';
  END IF;

  -- The owner must still own the device when approving.
  IF p_approve AND NOT public.is_device_owner(v_req.device_id) THEN
    RAISE EXCEPTION 'not_device_owner' USING ERRCODE = 'P0001';
  END IF;

  v_status := CASE WHEN p_approve THEN 'approved' ELSE 'declined' END;
  v_name := COALESCE(public.share_scope_name('device', v_req.device_id), '');

  IF p_approve THEN
    INSERT INTO public.device_shares (
      owner_id, shared_with_user_id, scope_type, scope_id
    )
    VALUES (v_uid, v_req.requester_id, 'device', v_req.device_id)
    ON CONFLICT (shared_with_user_id, scope_type, scope_id) DO NOTHING;
  END IF;

  UPDATE public.device_access_requests
  SET status = v_status, responded_at = now()
  WHERE id = p_id;

  -- The owner's own notification for this request counts as handled.
  UPDATE public.app_notifications
  SET read_at = COALESCE(read_at, now())
  WHERE request_id = p_id AND user_id = v_uid;

  INSERT INTO public.app_notifications (
    user_id, type, request_id, device_name, actor_user_id
  )
  VALUES (
    v_req.requester_id,
    CASE WHEN p_approve THEN 'device_access_approved'
         ELSE 'device_access_declined' END,
    p_id,
    v_name,
    v_uid
  );

  RETURN v_status;
END;
$$;

-- Inbox of the current user (newest first) incl. the other party's identity.
CREATE OR REPLACE FUNCTION public.list_notifications()
RETURNS TABLE (
  id UUID,
  type TEXT,
  request_id UUID,
  device_name TEXT,
  actor_user_id UUID,
  actor_first_name TEXT,
  actor_last_name TEXT,
  actor_email TEXT,
  request_status TEXT,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    n.id,
    n.type,
    n.request_id,
    n.device_name,
    n.actor_user_id,
    COALESCE(p.first_name, '')::text,
    COALESCE(p.last_name, '')::text,
    COALESCE(u.email, '')::text,
    r.status,
    n.read_at,
    n.created_at
  FROM public.app_notifications n
  LEFT JOIN auth.users u ON u.id = n.actor_user_id
  LEFT JOIN public.user_profiles p ON p.user_id = n.actor_user_id
  LEFT JOIN public.device_access_requests r ON r.id = n.request_id
  WHERE n.user_id = auth.uid()
  ORDER BY n.created_at DESC
  LIMIT 100;
$$;

-- ---------------------------------------------------------------------------
-- 4. Function privileges
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION
  public.find_device_owner(TEXT, TEXT),
  public.request_device_access(UUID),
  public.get_device_access_request(UUID),
  public.respond_device_access_request(UUID, BOOLEAN),
  public.list_notifications()
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION
  public.find_device_owner(TEXT, TEXT),
  public.request_device_access(UUID),
  public.get_device_access_request(UUID),
  public.respond_device_access_request(UUID, BOOLEAN),
  public.list_notifications()
TO authenticated;
