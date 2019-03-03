table! {
    employees (id) {
        id -> Int4,
        first -> Varchar,
        last -> Varchar,
        phone_number -> Nullable<Varchar>,
    }
}

table! {
    shifts (id) {
        id -> Int4,
        employee_id -> Int4,
        start_date -> Date,
        start_time -> Time,
        duration_hours -> Float4,
    }
}

allow_tables_to_appear_in_same_query!(employees, shifts,);
