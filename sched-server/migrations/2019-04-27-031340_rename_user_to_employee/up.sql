ALTER TABLE settings RENAME COLUMN user_id TO employee_id;
ALTER TABLE shifts RENAME COLUMN user_id TO supervisor_id;
ALTER TABLE sessions RENAME COLUMN user_id TO employee_id;

DROP TABLE vacations;
CREATE TABLE vacations (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER,
  supervisor_id INTEGER,
  approved BOOLEAN DEFAULT false,
  start_year INTEGER NOT NULL,
  start_month INTEGER NOT NULL,
  start_day INTEGER NOT NULL,
  end_year INTEGER NOT NULL,
  end_month INTEGER NOT NULL,
  end_day INTEGER NOT NULL
);