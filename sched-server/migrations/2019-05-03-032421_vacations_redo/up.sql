DROP TABLE vacations;
CREATE TABLE vacations (
  id SERIAL PRIMARY KEY,
  supervisor_id INTEGER,
  employee_id INTEGER NOT NULL,
  approved BOOLEAN NOT NULL,
  start_year INTEGER NOT NULL,
  start_month INTEGER NOT NULL,
  start_day INTEGER NOT NULL,
  duration_days INTEGER NOT NULL
);