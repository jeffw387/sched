ALTER TABLE settings RENAME COLUMN employee_id TO user_id;
ALTER TABLE shifts RENAME COLUMN supervisor_id TO user_id;
ALTER TABLE sessions RENAME COLUMN employee_id TO user_id;

DROP TABLE vacations;
CREATE TABLE vacations (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER,
  approved BOOLEAN DEFAULT false,
  start_year INTEGER NOT NULL,
  start_month INTEGER NOT NULL,
  start_day INTEGER NOT NULL,
  end_year INTEGER NOT NULL,
  end_month INTEGER NOT NULL,
  end_day INTEGER NOT NULL
);