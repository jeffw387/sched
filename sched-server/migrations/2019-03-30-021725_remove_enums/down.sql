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

DROP TABLE settings;
CREATE TABLE settings (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  view_type ViewType NOT NULL,
  hour_format HourFormat NOT NULL,
  last_name_style LastNameStyle NOT NULL
);