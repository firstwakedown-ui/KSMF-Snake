-- Migrace 42 nahradila run_game a tím shodila dřívější SECURITY DEFINER.
-- Funkce sama ověřuje assert_admin(), serverové zápisy jsou proto bezpečné.

begin;

alter function public.run_game(uuid) security definer;
alter function public.run_game(uuid) set search_path=public;

commit;
