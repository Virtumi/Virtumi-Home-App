-- Fill user_profiles from the sign-up metadata.
--
-- The existing trigger on_auth_user_created_profile_settings (auth.users,
-- AFTER INSERT) already calls handle_new_user_profile_and_settings(), which
-- only created an empty profile row. This replaces the function so first name,
-- last name, phone and address entered at registration are stored too.
-- No second trigger is created.

CREATE OR REPLACE FUNCTION public.handle_new_user_profile_and_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_meta  JSONB := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
  v_full  TEXT  := btrim(COALESCE(v_meta ->> 'full_name', v_meta ->> 'name', ''));
  v_first TEXT  := btrim(COALESCE(v_meta ->> 'first_name', ''));
  v_last  TEXT  := btrim(COALESCE(v_meta ->> 'last_name', ''));
BEGIN
  -- No explicit names (e.g. OAuth sign-up): split the full name.
  IF v_first = '' AND v_last = '' AND v_full <> '' THEN
    v_first := split_part(v_full, ' ', 1);
    v_last := btrim(substr(v_full, char_length(v_first) + 1));
  END IF;

  INSERT INTO public.user_profiles (
    user_id,
    first_name,
    last_name,
    phone,
    address_street,
    address_postal_code,
    address_city,
    address_country
  )
  VALUES (
    NEW.id,
    v_first,
    v_last,
    COALESCE(v_meta ->> 'phone', ''),
    COALESCE(v_meta ->> 'address_street', ''),
    COALESCE(v_meta ->> 'address_postal_code', ''),
    COALESCE(v_meta ->> 'address_city', ''),
    COALESCE(NULLIF(v_meta ->> 'address_country', ''), 'Deutschland')
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.app_settings (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Backfill: profiles that are still empty although the registration metadata
-- contains the names. Already filled profiles are left untouched.
UPDATE public.user_profiles p
SET
  first_name = btrim(COALESCE(u.raw_user_meta_data ->> 'first_name', '')),
  last_name = btrim(COALESCE(u.raw_user_meta_data ->> 'last_name', '')),
  phone = CASE WHEN p.phone = '' THEN COALESCE(u.raw_user_meta_data ->> 'phone', '') ELSE p.phone END,
  address_street = CASE WHEN p.address_street = '' THEN COALESCE(u.raw_user_meta_data ->> 'address_street', '') ELSE p.address_street END,
  address_postal_code = CASE WHEN p.address_postal_code = '' THEN COALESCE(u.raw_user_meta_data ->> 'address_postal_code', '') ELSE p.address_postal_code END,
  address_city = CASE WHEN p.address_city = '' THEN COALESCE(u.raw_user_meta_data ->> 'address_city', '') ELSE p.address_city END,
  updated_at = now()
FROM auth.users u
WHERE u.id = p.user_id
  AND btrim(p.first_name) = ''
  AND btrim(p.last_name) = ''
  AND (
    btrim(COALESCE(u.raw_user_meta_data ->> 'first_name', '')) <> ''
    OR btrim(COALESCE(u.raw_user_meta_data ->> 'last_name', '')) <> ''
  );
