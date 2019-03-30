table! {
    employees (id) {
        id -> Int4,
        first -> Varchar,
        last -> Varchar,
        phone_number -> Nullable<Varchar>,
    }
}

table! {
    per_employee_settings (id) {
        id -> Int4,
        settings_id -> Int4,
        employee_id -> Int4,
        red -> Float4,
        green -> Float4,
        blue -> Float4,
        alpha -> Float4,
    }
}

table! {
    repeat_shifts (id) {
        id -> Int4,
        employee_id -> Int4,
        repeat_type -> Varchar,
        every_n -> Int4,
        hour -> Int4,
        minute -> Int4,
        hours -> Int4,
        minutes -> Int4,
    }
}

table! {
    sessions (id) {
        id -> Int4,
        user_id -> Int4,
        year -> Int4,
        month -> Int4,
        day -> Int4,
        hour -> Int4,
        hours -> Int4,
        token -> Varchar,
    }
}

table! {
    settings (id) {
        id -> Int4,
        user_id -> Int4,
        view_type -> Varchar,
        hour_format -> Varchar,
        last_name_style -> Varchar,
    }
}

table! {
    shifts (id) {
        id -> Int4,
        employee_id -> Int4,
        year -> Int4,
        month -> Int4,
        day -> Int4,
        hour -> Int4,
        minute -> Int4,
        hours -> Int4,
        minutes -> Int4,
    }
}

table! {
    users (id) {
        id -> Int4,
        email -> Varchar,
        password_hash -> Varchar,
        startup_settings -> Nullable<Int4>,
    }
}

allow_tables_to_appear_in_same_query!(
    employees,
    per_employee_settings,
    repeat_shifts,
    sessions,
    settings,
    shifts,
    users,
);
