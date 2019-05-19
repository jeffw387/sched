CREATE TABLE shift_exceptions (
  id SERIAL PRIMARY KEY,
  shift_id INTEGER NOT NULL,
  "year" INTEGER NOT NULL,
  "month" INTEGER NOT NULL,
  "day" INTEGER NOT NULL
);