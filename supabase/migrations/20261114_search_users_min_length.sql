-- User search for sharing: start at the first character and rank matches that
-- begin with the search text first. Partial matches (contains) in first name,
-- last name and e-mail stay as before.

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
  v_escaped TEXT;
  v_pattern TEXT;
  v_prefix TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF char_length(v_term) < 1 THEN
    RETURN;
  END IF;

  v_escaped := replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_');
  v_pattern := '%' || v_escaped || '%';
  v_prefix := v_escaped || '%';

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
  ORDER BY
    CASE
      WHEN COALESCE(p.first_name, '') ILIKE v_prefix
        OR COALESCE(p.last_name, '') ILIKE v_prefix
        OR COALESCE(u.email, '') ILIKE v_prefix
        OR (COALESCE(p.first_name, '') || ' ' || COALESCE(p.last_name, '')) ILIKE v_prefix
      THEN 0
      ELSE 1
    END,
    p.last_name NULLS LAST,
    p.first_name NULLS LAST,
    u.email
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.search_users(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(TEXT) TO authenticated;
