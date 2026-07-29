-- Harden the SECURITY DEFINER trigger function.
--
-- handle_new_user() only ever runs from the auth.users AFTER INSERT trigger,
-- which executes with the definer's rights regardless of role grants. Removing
-- its REST/RPC exposure closes the /rest/v1/rpc/handle_new_user endpoint so it
-- can't be invoked directly by anon/authenticated callers. (Supabase security
-- advisor lints 0028 / 0029.)
revoke execute on function public.handle_new_user() from public, anon, authenticated;
