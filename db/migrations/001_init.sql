PRAGMA foreign_keys = ON;

-- schema meta
CREATE TABLE IF NOT EXISTS schema_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT OR IGNORE INTO schema_meta (key, value) VALUES ('schema_version', '1.0.0');

-- equipment
CREATE TABLE IF NOT EXISTS equipment (
  id   TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

-- exercises
CREATE TABLE IF NOT EXISTS exercise (
  id               TEXT PRIMARY KEY,
  name             TEXT NOT NULL,
  short_name       TEXT,
  training_type    TEXT NOT NULL CHECK (training_type IN ('mobility','cardio','resistance','skill')),
  base_exercise_id TEXT,
  notes            TEXT,
  is_active        INTEGER NOT NULL DEFAULT 1,
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  FOREIGN KEY (base_exercise_id) REFERENCES exercise(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_exercise_name_type
  ON exercise (LOWER(name), training_type);

-- exercise ↔ equipment
CREATE TABLE IF NOT EXISTS exercise_equipment (
  exercise_id  TEXT NOT NULL,
  equipment_id TEXT NOT NULL,
  PRIMARY KEY (exercise_id, equipment_id),
  FOREIGN KEY (exercise_id) REFERENCES exercise(id) ON DELETE CASCADE,
  FOREIGN KEY (equipment_id) REFERENCES equipment(id) ON DELETE RESTRICT
);

-- variants (exercise + equipment)
CREATE TABLE IF NOT EXISTS exercise_variant (
  id            TEXT PRIMARY KEY,
  exercise_id   TEXT NOT NULL,
  equipment_id  TEXT,
  display_name  TEXT NOT NULL,
  notes         TEXT,
  is_active     INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (exercise_id)  REFERENCES exercise(id),
  FOREIGN KEY (equipment_id) REFERENCES equipment(id),
  UNIQUE (exercise_id, COALESCE(equipment_id,''))
);

-- progression maps
CREATE TABLE IF NOT EXISTS progression_map (
  id               TEXT PRIMARY KEY,
  name             TEXT NOT NULL,
  base_exercise_id TEXT NOT NULL,
  FOREIGN KEY (base_exercise_id) REFERENCES exercise(id)
);

CREATE TABLE IF NOT EXISTS progression_node (
  id          TEXT PRIMARY KEY,
  map_id      TEXT NOT NULL,
  variant_id  TEXT NOT NULL,
  is_entry    INTEGER NOT NULL DEFAULT 0,
  is_active   INTEGER NOT NULL DEFAULT 1,
  FOREIGN KEY (map_id)     REFERENCES progression_map(id) ON DELETE CASCADE,
  FOREIGN KEY (variant_id) REFERENCES exercise_variant(id),
  UNIQUE (map_id, variant_id)
);

CREATE TABLE IF NOT EXISTS progression_edge (
  map_id        TEXT NOT NULL,
  from_node_id  TEXT NOT NULL,
  to_node_id    TEXT NOT NULL,
  relation      TEXT NOT NULL DEFAULT 'harder' CHECK (relation IN ('harder','easier','alt')),
  PRIMARY KEY (map_id, from_node_id, to_node_id),
  FOREIGN KEY (map_id)       REFERENCES progression_map(id) ON DELETE CASCADE,
  FOREIGN KEY (from_node_id) REFERENCES progression_node(id) ON DELETE CASCADE,
  FOREIGN KEY (to_node_id)   REFERENCES progression_node(id) ON DELETE CASCADE
);

-- programs / workouts
CREATE TABLE IF NOT EXISTS program (
  id    TEXT PRIMARY KEY,
  name  TEXT NOT NULL,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS workout (
  id         TEXT PRIMARY KEY,
  program_id TEXT NOT NULL,
  name       TEXT NOT NULL,
  notes      TEXT,
  FOREIGN KEY (program_id) REFERENCES program(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS workout_group (
  id               TEXT PRIMARY KEY,
  workout_id       TEXT NOT NULL,
  parent_group_id  TEXT,
  order_index      INTEGER NOT NULL,
  name             TEXT,
  kind             TEXT NOT NULL CHECK (kind IN ('section','sequence','circuit','superset','repeat')),
  params_json      TEXT,
  FOREIGN KEY (workout_id)      REFERENCES workout(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_group_id) REFERENCES workout_group(id) ON DELETE CASCADE,
  UNIQUE (workout_id, parent_group_id, order_index)
);

CREATE TABLE IF NOT EXISTS workout_block (
  id                    TEXT PRIMARY KEY,
  workout_id            TEXT NOT NULL,
  group_id              TEXT NOT NULL,
  order_index           INTEGER NOT NULL,
  type                  TEXT NOT NULL CHECK (type IN ('fixed','progression')),
  variant_id            TEXT,
  prog_node_id          TEXT,
  progress_key          TEXT,
  training_type         TEXT NOT NULL CHECK (training_type IN ('mobility','cardio','resistance','skill')),
  load_category         TEXT NOT NULL CHECK (load_category IN ('bodyweight','assisted','weighted')),
  load_spec_json        TEXT,
  scheme_json           TEXT NOT NULL,
  chosen_equipment_id   TEXT,
  notes                 TEXT,
  prog_policy_json      TEXT,
  FOREIGN KEY (workout_id)          REFERENCES workout(id) ON DELETE CASCADE,
  FOREIGN KEY (group_id)            REFERENCES workout_group(id) ON DELETE CASCADE,
  FOREIGN KEY (variant_id)          REFERENCES exercise_variant(id),
  FOREIGN KEY (prog_node_id)        REFERENCES progression_node(id),
  FOREIGN KEY (chosen_equipment_id) REFERENCES equipment(id),
  UNIQUE (group_id, order_index),
  CHECK (
    (type='fixed' AND variant_id IS NOT NULL AND prog_node_id IS NULL) OR
    (type='progression' AND prog_node_id IS NOT NULL AND variant_id IS NULL)
  )
);

-- plans
CREATE TABLE IF NOT EXISTS plan (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  status            TEXT NOT NULL CHECK (status IN ('active','archived','draft')),
  start_date        TEXT NOT NULL,
  timezone          TEXT NOT NULL,
  notify_defaults_json TEXT,
  notes             TEXT,
  started_at        TEXT,
  loop_on_finish    INTEGER NOT NULL DEFAULT 0,
  cycles_completed  INTEGER NOT NULL DEFAULT 0,
  end_behavior      TEXT NOT NULL DEFAULT 'prompt' CHECK (end_behavior IN ('prompt','repeat','stop')),
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS plan_group (
  id               TEXT PRIMARY KEY,
  plan_id          TEXT NOT NULL,
  parent_group_id  TEXT,
  order_index      INTEGER NOT NULL,
  name             TEXT,
  kind             TEXT NOT NULL CHECK (kind IN ('section','sequence','week','day')),
  params_json      TEXT,
  FOREIGN KEY (plan_id)         REFERENCES plan(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_group_id) REFERENCES plan_group(id) ON DELETE CASCADE,
  UNIQUE (plan_id, parent_group_id, order_index)
);

CREATE TABLE IF NOT EXISTS plan_item (
  id         TEXT PRIMARY KEY,
  plan_id    TEXT NOT NULL,
  group_id   TEXT NOT NULL,
  order_index INTEGER NOT NULL,
  workout_id TEXT NOT NULL,
  label      TEXT,
  notes      TEXT,
  FOREIGN KEY (plan_id)   REFERENCES plan(id) ON DELETE CASCADE,
  FOREIGN KEY (group_id)  REFERENCES plan_group(id) ON DELETE CASCADE,
  FOREIGN KEY (workout_id) REFERENCES workout(id),
  UNIQUE (group_id, order_index)
);

CREATE TABLE IF NOT EXISTS plan_occurrence (
  id             TEXT PRIMARY KEY,
  plan_id        TEXT NOT NULL,
  plan_item_id   TEXT NOT NULL,
  scheduled_local TEXT NOT NULL,
  scheduled_utc   TEXT NOT NULL,
  slot_label      TEXT,
  cycle_no        INTEGER NOT NULL DEFAULT 0,
  status          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','done','skipped','expired')),
  FOREIGN KEY (plan_id)      REFERENCES plan(id) ON DELETE CASCADE,
  FOREIGN KEY (plan_item_id) REFERENCES plan_item(id)
);

-- sessions
CREATE TABLE IF NOT EXISTS session (
  id                TEXT PRIMARY KEY,
  plan_occurrence_id TEXT,
  workout_id        TEXT NOT NULL,
  started_at        TEXT NOT NULL,
  completed_at      TEXT,
  duration_s        INTEGER,
  notes             TEXT,
  FOREIGN KEY (plan_occurrence_id) REFERENCES plan_occurrence(id),
  FOREIGN KEY (workout_id)         REFERENCES workout(id)
);

CREATE TABLE IF NOT EXISTS session_block (
  id                     TEXT PRIMARY KEY,
  session_id             TEXT NOT NULL,
  order_index            INTEGER NOT NULL,
  status                 TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','done','skipped')),
  source_workout_block_id TEXT,
  override_kind          TEXT CHECK (override_kind IN ('substitute','adhoc','scheme')),
  variant_id             TEXT NOT NULL,
  original_variant_id    TEXT,
  prog_node_id           TEXT,
  scheme_snapshot_json   TEXT NOT NULL,
  scheme_runtime_json    TEXT,
  load_snapshot_json     TEXT,
  notes                  TEXT,
  order_runtime          INTEGER,
  FOREIGN KEY (session_id)           REFERENCES session(id) ON DELETE CASCADE,
  FOREIGN KEY (variant_id)           REFERENCES exercise_variant(id),
  FOREIGN KEY (original_variant_id)  REFERENCES exercise_variant(id),
  FOREIGN KEY (prog_node_id)         REFERENCES progression_node(id),
  UNIQUE (session_id, order_index)
);

CREATE TABLE IF NOT EXISTS session_set (
  id                TEXT PRIMARY KEY,
  session_block_id  TEXT NOT NULL,
  set_index         INTEGER NOT NULL,
  reps              INTEGER,
  load              REAL,
  time_s            INTEGER,
  rpe               REAL,
  completed         INTEGER NOT NULL DEFAULT 1,
  notes             TEXT,
  FOREIGN KEY (session_block_id) REFERENCES session_block(id) ON DELETE CASCADE,
  UNIQUE (session_block_id, set_index)
);

-- user progress
CREATE TABLE IF NOT EXISTS user_progress_state (
  id                TEXT PRIMARY KEY,
  progress_key      TEXT NOT NULL,
  scope             TEXT NOT NULL CHECK (scope IN ('plan','global','workout')),
  scope_ref_id      TEXT,
  prog_map_id       TEXT NOT NULL,
  current_node_id   TEXT NOT NULL,
  current_variant_id TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  UNIQUE (progress_key, scope, COALESCE(scope_ref_id,'')),
  FOREIGN KEY (prog_map_id)       REFERENCES progression_map(id),
  FOREIGN KEY (current_node_id)   REFERENCES progression_node(id),
  FOREIGN KEY (current_variant_id) REFERENCES exercise_variant(id)
);

CREATE TABLE IF NOT EXISTS user_progress_event (
  id            TEXT PRIMARY KEY,
  progress_key  TEXT NOT NULL,
  session_id    TEXT NOT NULL,
  from_node_id  TEXT NOT NULL,
  to_node_id    TEXT NOT NULL,
  reason        TEXT NOT NULL,
  created_at    TEXT NOT NULL,
  FOREIGN KEY (session_id) REFERENCES session(id)
);

-- indices
CREATE INDEX IF NOT EXISTS idx_session_started_at ON session (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_occ_plan_time ON plan_occurrence (plan_id, scheduled_local);
CREATE INDEX IF NOT EXISTS idx_block_workout ON workout_block (workout_id, group_id, order_index);
CREATE INDEX IF NOT EXISTS idx_prog_node_map ON progression_node (map_id);
CREATE INDEX IF NOT EXISTS idx_variant_ex ON exercise_variant (exercise_id);
CREATE INDEX IF NOT EXISTS idx_user_prog_lookup ON user_progress_state (progress_key, scope, scope_ref_id);
