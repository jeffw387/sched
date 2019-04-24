DROP TABLE per_employee_settings;
CREATE TABLE per_employee_settings (
  id SERIAL PRIMARY KEY,
  settings_id INTEGER NOT NULL,
  employee_id INTEGER NOT NULL,
  red REAL NOT NULL,
  green REAL NOT NULL,
  blue REAL NOT NULL,
  alpha REAL NOT NULL
);