DROP TABLE shifts;
CREATE TABLE shifts (
  "id" INTEGER PRIMARY KEY,
  "employee_id" INTEGER NOT NULL,
  "year" INTEGER NOT NULL,
  "month" INTEGER NOT NULL,
  "day" INTEGER NOT NULL,
  "hour" INTEGER NOT NULL,
  "minute" INTEGER NOT NULL,
  "hours" INTEGER NOT NULL,
  "minutes" INTEGER NOT NULL
);