CREATE TYPE ViewType AS ENUM (
  'Month',
  'Week',
  'Day'
);

CREATE TYPE HourFormat AS ENUM (
  'Hour12',
  'Hour24'
);

CREATE TYPE LastNameStyle AS ENUM (
  'FullName',
  'FirstInitial',
  'Hidden'
);

CREATE TABLE settings (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  view_type ViewType NOT NULL,
  hour_format HourFormat NOT NULL,
  last_name_style LastNameStyle NOT NULL
);

CREATE TABLE per_employee_settings (
  id INTEGER PRIMARY KEY,
  settings_id INTEGER NOT NULL,
  employee_id INTEGER UNIQUE NOT NULL,
  red REAL NOT NULL,
  green REAL NOT NULL,
  blue REAL NOT NULL,
  alpha REAL NOT NULL
);

ALTER TABLE users ADD COLUMN startup_settings INTEGER;
