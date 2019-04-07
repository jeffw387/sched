DROP TABLE "sessions";
CREATE TABLE "sessions" (
  id SERIAL PRIMARY KEY,
  "user_id" INTEGER NOT NULL,
  "year" INTEGER NOT NULL,
  "month" INTEGER NOT NULL,
  "day" INTEGER NOT NULL,
  "hour" INTEGER NOT NULL,
  "minute" INTEGER NOT NULL,
  token VARCHAR NOT NULL
);