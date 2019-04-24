DROP TABLE per_employee_settings;
CREATE TABLE per_employee_settings (
  id SERIAL PRIMARY KEY,
  settings_id INTEGER NOT NULL,
  employee_id INTEGER NOT NULL,
  color TEXT default 'Blue' NOT NULL
);