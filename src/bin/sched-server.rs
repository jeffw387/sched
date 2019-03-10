use actix::prelude::*;
use actix::{
    Addr,
};
use actix_web::{
    http,
    server,
    App,
    AsyncResponder,
    HttpRequest,
    HttpResponse,
    State,
};
use diesel::pg::PgConnection;
use diesel::r2d2::ConnectionManager;
use dotenv;
use futures::Future;
use sched::message::{
    DbExecutor,
    GetUsers,
};
use std::env;
struct AppState {
    db: Addr<DbExecutor>,
}

fn print_users(
    (_, state): (HttpRequest<AppState>, State<AppState>),
) -> impl Future<Item = HttpResponse, Error = actix_web::Error>
{
    state
        .db
        .send(GetUsers {})
        .from_err()
        .and_then(|res| {
            match res {
                Ok(usrs) => {
                    let user_output = format!("{:?}", usrs);
                    println!("{}", &user_output);
                    Ok(HttpResponse::Ok()
                        .content_type("text/plain")
                        .body(user_output))
                }
                Err(e) => {
                    let err_output = format!("{:?}", e);
                    println!("{}", &err_output);
                    Ok(HttpResponse::InternalServerError()
                        .content_type("text/plain")
                        .body(err_output))
                }
            }
        })
        .responder()
}

fn main() {
    let sys = actix::System::new("database-system");
    dotenv::dotenv().ok();
    let db_url = env::vars()
        .find(|(key, _)| key == "DATABASE_URL")
        .expect(
            "DATABASE_URL environment variable not set!",
        )
        .1;
    let manager =
        ConnectionManager::<PgConnection>::new(db_url);

    let pool = r2d2::Pool::builder()
        .build(manager)
        .expect("Failed to create connection pool!");

    let addr = SyncArbiter::start(3, move || {
        DbExecutor(pool.clone())
    });
    let _ = server::HttpServer::new(move || {
        App::with_state(AppState { db: addr.clone() })
            .resource("/sched", |r| {
                r.method(http::Method::POST)
                    .with_async(print_users)
            })
    })
    .bind("localhost:8080")
    .unwrap()
    .run();

    let _ = sys.run();
}
