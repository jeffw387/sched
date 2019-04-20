CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  startup_settings INTEGER,
  "level" TEXT NOT NULL
);

CREATE TABLE sessions (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  "year" INTEGER NOT NULL,
  "month" INTEGER NOT NULL,
  "day" INTEGER NOT NULL,
  "hour" INTEGER NOT NULL,
  "minute" INTEGER NOT NULL,
  "token" TEXT NOT NULL
);

CREATE TABLE settings (
  id SERIAL PRIMARY KEY,
  "user_id" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  view_type TEXT NOT NULL,
  hour_format TEXT NOT NULL,
  last_name_style TEXT NOT NULL,
  view_year INTEGER NOT NULL,
  view_month INTEGER NOT NULL,
  view_day INTEGER NOT NULL,
  view_employees INTEGER[] NOT NULL
);

CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  "first" TEXT NOT NULL,
  "last" TEXT NOT NULL,
  phone_number TEXT
);

CREATE TABLE per_employee_settings (
  id SERIAL PRIMARY KEY,
  settings_id INTEGER NOT NULL,
  employee_id INTEGER NOT NULL,
  red REAL NOT NULL,
  green REAL NOT NULL,
  blue REAL NOT NULL,
  alpha REAL NOT NULL
);

CREATE TABLE shifts (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  employee_id INTEGER NOT NULL,
  "year" INTEGER NOT NULL,
  "month" INTEGER NOT NULL,
  "day" INTEGER NOT NULL,
  "hour" INTEGER NOT NULL,
  "minute" INTEGER NOT NULL,
  "hours" INTEGER NOT NULL,
  "minutes" INTEGER NOT NULL,
  "shift_repeat" TEXT NOT NULL,
  "every_x" INTEGER NOT NULL
);