table! {
    employees (id) {
        id -> Int4,
        first -> Text,
        last -> Text,
        phone_number -> Nullable<Text>,
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
    sessions (id) {
        id -> Int4,
        user_id -> Int4,
        year -> Int4,
        month -> Int4,
        day -> Int4,
        hour -> Int4,
        minute -> Int4,
        token -> Text,
    }
}

table! {
    settings (id) {
        id -> Int4,
        user_id -> Int4,
        view_type -> Text,
        hour_format -> Text,
        last_name_style -> Text,
        view_year -> Int4,
        view_month -> Int4,
        view_day -> Int4,
        view_employees -> Array<Int4>,
    }
}

table! {
    shifts (id) {
        id -> Int4,
        user_id -> Int4,
        employee_id -> Int4,
        year -> Int4,
        month -> Int4,
        day -> Int4,
        hour -> Int4,
        minute -> Int4,
        hours -> Int4,
        minutes -> Int4,
        shift_repeat -> Text,
        every_x -> Int4,
    }
}

table! {
    users (id) {
        id -> Int4,
        email -> Text,
        password_hash -> Text,
        startup_settings -> Nullable<Int4>,
        level -> Text,
    }
}

allow_tables_to_appear_in_same_query!(
    employees,
    per_employee_settings,
    sessions,
    settings,
    shifts,
    users,
);
