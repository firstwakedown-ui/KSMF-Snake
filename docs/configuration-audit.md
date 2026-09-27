# Configuration audit

The production diagnostic showed 33/50 and 29 points on Podzamka lite.
The screenshot of the settings showed a different plan with 39 points.
This proves a stored-settings mismatch, not an RLS failure. Previous claims
that RLS or the activation trigger were confirmed causes were unsubstantiated.
The manual repair then set a plan AND its running game to 100/100 and activated
all berries. Changing a plan cannot undo that running-game state.

Migration 50 replaces plan settings with one global game_settings row. Saving
configuration changes only that row. A BEFORE INSERT trigger copies every value
to a newly created game, forming the immutable snapshot boundary. Lobby and
running games are never updated by later saves. run_game reads only the game
snapshot and no longer refreshes strawberry percentages from the plan. The client
compares every persisted value with its request before reporting success.

Expected cases on 29 points: 50/50 starts with 15 active; 100/100 with 29;
0/50 starts empty and refills to at most 15. On 39 points, 50/50 starts with 20.
Save first and test a newly created game. Existing games intentionally retain
the values they had at creation.

Snake tick reads speed, initial length, growth, spawn interval, lead limit,
self-collision grace and duration from games. Respawn uses game settings.
The active limit applies to subsequent activations. Grey admin markers show
possible berry positions; colored markers show active berries.

Legacy limitations: current PlayerView does not implement the former joystick
controls. Current snake_tick does not use idle_timeout_s or outside_timeout_s as
standalone timers. Persisting those settings does not implement those mechanics.
These need a separate gameplay decision rather than silently changing Snake rules.

Verification: frontend production build. No local PostgreSQL/PostGIS runtime is
available; migration execution and production behavior must be checked in Supabase.
