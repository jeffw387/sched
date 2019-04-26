table! {
    employees (id) {
        id -> Int4,
        email -> Text,
        password_hash -> Text,
        startup_settings -> Nullable<Int4>,
        level -> Text,
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
        color -> Text,
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
        name -> Text,
        view_type -> Text,
        hour_format -> Text,
        last_name_style -> Text,
        view_year -> Int4,
        view_month -> Int4,
        view_day -> Int4,
        view_employees -> Array<Int4>,
        show_minutes -> Bool,
    }
}

table! {
    shifts (id) {
        id -> Int4,
        user_id -> Int4,
        employee_id -> Nullable<Int4>,
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
    vacations (id) {
        id -> Int4,
        employee_id -> Nullable<Int4>,
        approved -> Nullable<Bool>,
        start_year -> Int4,
        start_month -> Int4,
        start_day -> Int4,
        end_year -> Int4,
        end_month -> Int4,
        end_day -> Int4,
    }
}

allow_tables_to_appear_in_same_query!(
    employees,
    per_employee_settings,
    sessions,
    settings,
    shifts,
    vacations,
);
