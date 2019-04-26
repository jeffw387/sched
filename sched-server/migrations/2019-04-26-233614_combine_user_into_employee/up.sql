DROP TABLE users;
DROP TABLE employees;
CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  startup_settings INTEGER,
  "level" TEXT NOT NULL,
  "first" TEXT NOT NULL,
  "last" TEXT NOT NULL,
  phone_number TEXT
);