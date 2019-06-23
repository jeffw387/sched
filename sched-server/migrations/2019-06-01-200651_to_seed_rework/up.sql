CREATE TABLE shifts(
    id SERIAL PRIMARY KEY,
    supervisor_id INTEGER NOT NULL,
    employee_id INTEGER,
    "start" TIMESTAMP (0) WITH TIME ZONE NOT NULL,
    "end" TIMESTAMP (0) WITH TIME ZONE NOT NULL,
    "repeat" TEXT NOT NULL,
    every_x INTEGER,
    note TEXT,
    on_call BOOLEAN NOT NULL
);

CREATE TABLE shift_exceptions(
    id SERIAL PRIMARY KEY,
    shift_id INTEGER NOT NULL,
    "date" TIMESTAMP (0) WITH TIME ZONE NOT NULL
);

CREATE TABLE vacations(
    id SERIAL PRIMARY KEY,
    supervisor_id INTEGER,
    employee_id INTEGER NOT NULL,
    approved BOOLEAN NOT NULL,
    "start" TIMESTAMP (0) WITH TIME ZONE NOT NULL,
    "end" TIMESTAMP (0) WITH TIME ZONE NOT NULL,
    requested TIMESTAMP (0) WITH TIME ZONE NOT NULL
);

CREATE TABLE employees(
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    active_config INTEGER,
    "level" TEXT NOT NULL,
    "first" TEXT NOT NULL,
    "last" TEXT NOT NULL,
    phone_number TEXT,
    default_color TEXT NOT NULL
);

CREATE TABLE configs(
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    config_name TEXT NOT NULL,
    hour_format TEXT NOT NULL,
    last_name_style TEXT NOT NULL,
    view_employees INTEGER[] NOT NULL,
    show_minutes BOOLEAN NOT NULL,
    show_shifts BOOLEAN NOT NULL,
    show_vacations BOOLEAN NOT NULL,
    show_call_shifts BOOLEAN NOT NULL,
    show_disabled BOOLEAN NOT NULL
);

CREATE TABLE per_employee_configs(
    id SERIAL PRIMARY KEY,
    config_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    color TEXT NOT NULL
);

CREATE TABLE sessions(
    id SERIAL PRIMARY KEY,
    employee_id INTEGER NOT NULL,
    expiration TIMESTAMP (0) WITH TIME ZONE NOT NULL,
    token TEXT NOT NULL
);