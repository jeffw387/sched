table! {
    configs (id) {
        id -> Int4,
        employee_id -> Int4,
        config_name -> Text,
        hour_format -> Text,
        last_name_style -> Text,
        view_date -> Timestamptz,
        view_employees -> Array<Int4>,
        show_minutes -> Bool,
        show_shifts -> Bool,
        show_vacations -> Bool,
        show_call_shifts -> Bool,
        show_disabled -> Bool,
    }
}

table! {
    employees (id) {
        id -> Int4,
        email -> Text,
        password_hash -> Text,
        active_config -> Nullable<Int4>,
        level -> Text,
        first -> Text,
        last -> Text,
        phone_number -> Nullable<Text>,
        default_color -> Text,
    }
}

table! {
    per_employee_configs (id) {
        id -> Int4,
        config_id -> Int4,
        employee_id -> Int4,
        color -> Text,
    }
}

table! {
    sessions (id) {
        id -> Int4,
        employee_id -> Int4,
        expiration -> Timestamptz,
        token -> Text,
    }
}

table! {
    shift_exceptions (id) {
        id -> Int4,
        shift_id -> Int4,
        date -> Timestamptz,
    }
}

table! {
    shifts (id) {
        id -> Int4,
        supervisor_id -> Int4,
        employee_id -> Nullable<Int4>,
        start -> Timestamptz,
        end -> Timestamptz,
        repeat -> Text,
        every_x -> Nullable<Int4>,
        note -> Nullable<Text>,
        on_call -> Bool,
    }
}

table! {
    vacations (id) {
        id -> Int4,
        supervisor_id -> Nullable<Int4>,
        employee_id -> Int4,
        approved -> Bool,
        start -> Timestamptz,
        end -> Timestamptz,
        requested -> Timestamptz,
    }
}

allow_tables_to_appear_in_same_query!(
    configs,
    employees,
    per_employee_configs,
    sessions,
    shift_exceptions,
    shifts,
    vacations,
);
