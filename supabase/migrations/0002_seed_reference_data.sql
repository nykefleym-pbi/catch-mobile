-- Seed the v1 reference catalogs: personality traits and starter foods.
-- Idempotent so it can run repeatedly in local/dev.

insert into public.personality_traits (id, label, description) values
  ('curious',     'Curious',     'Nose into everything; loves new things.'),
  ('brave',       'Brave',       'Faces the world head-on.'),
  ('lazy',        'Lazy',        'Expert napper; unbothered.'),
  ('foodie',      'Foodie',      'Gains extra affection from feeding.'),
  ('mischievous', 'Mischievous', 'Playful trouble-maker.'),
  ('elegant',     'Elegant',     'Poised and graceful.'),
  ('playful',     'Playful',     'Always up for a game.'),
  ('protective',  'Protective',  'Watches over its people.'),
  ('explorer',    'Explorer',    'Happiest on the move.'),
  ('shy',         'Shy',         'Gentle and reserved.')
on conflict (id) do nothing;

insert into public.items (id, label, type, affection, is_cosmetic) values
  ('tuna',           'Tuna',           'food', 5,  false),
  ('salmon',         'Salmon',         'food', 6,  false),
  ('chicken',        'Chicken',        'food', 4,  false),
  ('premium_treats', 'Premium Treats', 'food', 8,  false),
  ('catnip',         'Catnip',         'food', 3,  false)
on conflict (id) do nothing;
