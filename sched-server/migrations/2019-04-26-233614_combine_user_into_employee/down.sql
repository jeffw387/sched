DROP TABLE employees;

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  startup_settings INTEGER,
  "level" TEXT NOT NULL
);

CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  "first" TEXT NOT NULL,
  "last" TEXT NOT NULL,
  phone_number TEXT
);