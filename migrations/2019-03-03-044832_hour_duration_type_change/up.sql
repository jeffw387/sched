DROP TABLE shifts;
CREATE TABLE shifts(
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL,
  start_date DATE NOT NULL,
  start_time TIME NOT NULL,
  duration_hours REAL NOT NULL
)