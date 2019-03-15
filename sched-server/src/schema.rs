table! {
    employees (id) {
        id -> Int4,
        first -> Varchar,
        last -> Varchar,
        phone_number -> Nullable<Varchar>,
    }
}

table! {
    sessions (token) {
        token -> Text,
    }
}

table! {
    shifts (id) {
        id -> Int4,
        employee_id -> Int4,
        start -> Timestamp,
        duration_hours -> Float4,
    }
}

table! {
    users (id) {
        id -> Int4,
        email -> Varchar,
        password_hash -> Varchar,
    }
}

joinable!(shifts -> employees (employee_id));

allow_tables_to_appear_in_same_query!(
    employees, sessions, shifts, users,
);