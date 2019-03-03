CREATE TABLE shifts(
  id SERIAL PRIMARY KEY,
  start_date DATE NOT NULL,
  start_time TIME NOT NULL,
  duration_hours FLOAT NOT NULL
)