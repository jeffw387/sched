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
    }
}

allow_tables_to_appear_in_same_query!(
    employees,
    sessions,
    shifts,
    users,
);
