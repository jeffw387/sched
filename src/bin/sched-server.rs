use actix_web::{server, App};

fn main() {
    let _ = server::HttpServer::new(
        || App::new()
            .resource("/sched", |r| { r.f(|_| "Scheduler stub"); }))
            .bind("localhost:8080")
            .unwrap()
            .run();
}
