-- Seed the diseases lookup table with the codes produced by CoffeeDiseaseClassifier_v100.
-- Required before any row can be inserted into `diagnoses` (FK constraint).
INSERT INTO public.diseases (code, name, description) VALUES
  ('sano',    'Hoja sana',               'Planta en buen estado, sin signos de enfermedad ni deficiencias visibles.'),
  ('roya',    'Roya del café',           'Hemileia vastatrix. Manchas amarillas en el haz, polvo anaranjado en el envés. Principal amenaza del cafetal.'),
  ('minador', 'Minador de la hoja',      'Leucoptera coffeella. Larvas que crean galerías sinuosas, debilitando la planta.'),
  ('phoma',   'Phoma (mancha de hierro)','Phoma sp. Manchas circulares oscuras con halo amarillo. Favorecida por humedad y mal drenaje.')
ON CONFLICT (code) DO NOTHING;
