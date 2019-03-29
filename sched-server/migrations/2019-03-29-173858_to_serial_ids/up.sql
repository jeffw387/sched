DROP TABLE settings;
CREATE TABLE settings (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  view_type ViewType NOT NULL,
  hour_format HourFormat NOT NULL,
  last_name_style LastNameStyle NOT NULL
);

DROP TABLE shifts;
CREATE TABLE shifts (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL,
  "year" INTEGER NOT NULL,
  "month" INTEGER NOT NULL,
  "day" INTEGER NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  "hours" INTEGER NOT NULL,
  "minutes" INTEGER NOT NULL
);