-- Supabase installs pgcrypto in the extensions schema. The original
-- enter_matchmaking function deliberately restricts its search_path, so make
-- that schema explicit for databases where the first migration is deployed.

DO $$
BEGIN
  IF to_regprocedure('public.enter_matchmaking(text,text,integer)') IS NULL THEN
    RAISE EXCEPTION 'enter_matchmaking(text,text,integer) must be installed first';
  END IF;

  ALTER FUNCTION public.enter_matchmaking(TEXT, TEXT, INTEGER)
    SET search_path = public, extensions;
END
$$;
