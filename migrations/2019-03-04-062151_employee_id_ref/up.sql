DROP TABLE shifts;
CREATE TABLE shifts (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL REFERENCES employees (id),
  start TIMESTAMP NOT NULL,
  duration_hours REAL NOT NULL
)