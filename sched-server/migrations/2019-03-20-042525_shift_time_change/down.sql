DROP TABLE shifts;
CREATE TABLE shifts (
  id INTEGER PRIMARY KEY,
  employee_id INTEGER NOT NULL,
  start TIMESTAMP NOT NULL,
  duration_hours REAL NOT NULL
);