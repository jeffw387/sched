CREATE TYPE RepeatType AS ENUM (
  'every_n_days',
  'every_n_weeks'
);

CREATE TABLE repeat_shifts (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL,
  repeat_type RepeatType NOT NULL,
  every_n INTEGER NOT NULL,
  "hour" INTEGER NOT NULL,
  "minute" INTEGER NOT NULL,
  "hours" INTEGER NOT NULL,
  "minutes" INTEGER NOT NULL
);