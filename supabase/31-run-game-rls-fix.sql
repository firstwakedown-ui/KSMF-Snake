-- KSMF Snake: run_game po zapnutí bezpečných RLS relací nemohl vložit
-- počáteční snake_states a game_strawberries. Funkce už uvnitř ověřuje
-- assert_admin(), proto jí bezpečně povolíme provést tyto serverové zápisy.

begin;

alter function public.run_game(uuid) security definer;
alter function public.run_game(uuid) set search_path = public;

commit;
