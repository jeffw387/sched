use actix::prelude::*;
use actix::Addr;
use actix_web::http;
use actix_web::{
    server,
    App,
    AsyncResponder,
    HttpMessage,
    HttpRequest,
    HttpResponse,
    State,
    fs::StaticFiles
};
use diesel::pg::PgConnection;
use diesel::r2d2::ConnectionManager;
use dotenv;
use futures::Future;
use sched::message::LoginInfo;
use sched_server::db::{
    DbExecutor,
    LoginRequest,
    LoginResult,
};
use std::env;
use chrono::Duration;
use cookie::SameSite;
use sched::api;
use sched::user::User;

struct AppState {
    db: Addr<DbExecutor>,
}

fn make_session() -> http::Cookie<'static> {
                                    http::Cookie::build(
                                        "session", "",
                                    )
                                    .max_age(
                                        Duration::days(1),
                                    )
                                    .domain("www.jw387.com")
                                    .http_only(true)
                                    .secure(true)
                                    .same_site(
                                        SameSite::Strict,
                                    )
                                    .finish()
}

fn login(
    (req, state): (HttpRequest<AppState>, State<AppState>),
) -> Box<Future<Item = HttpResponse, Error = actix_web::Error>>
{
    let db = state.db.clone();
    req.json()
        .from_err()
        .and_then(move |login_info: LoginInfo| {
                db
                .send(LoginRequest(login_info))
                .from_err()
                .and_then(|login_result: LoginResult| {
                    match login_result {
                        Ok(_token) => {
                            Ok(HttpResponse::Ok()
                            .cookie(make_session())
                            .finish())
                        }
                        Err(_err) => {
                            Ok(HttpResponse::Unauthorized().finish())
                        }
                    }
                }).responder()
        })
        .responder()
}

fn main() {
    std::env::set_var("RUST_LOG", "actix_web=info");

    let sys = actix::System::new("database-system");
    dotenv::dotenv().ok();
    let db_url = env::vars()
        .find(|(key, _)| key == "DATABASE_URL")
        .expect(
            "DATABASE_URL environment variable not set!",
        )
        .1;
    println!("database url: {}", db_url);
    let manager =
        ConnectionManager::<PgConnection>::new(db_url);

    let pool = r2d2::Pool::builder()
        .build(manager)
        .expect("Failed to create connection pool!");

    let addr = SyncArbiter::start(3, move || {
        DbExecutor(pool.clone())
    });
    if addr.connected() {
        println!("Successfully connected to database.");
    } else {
        println!("Failed to connect to database.");
    }

    server::HttpServer::new(move || {
        App::with_state(AppState { db: addr.clone() })
            .middleware(
                actix_web::middleware::Logger::default(),
            )
            .handler(api::API_INDEX, StaticFiles::new("./").expect("Error accessing fs").index_file("index.html"))
            .resource(api::API_LOGIN, |r| {
                r.post().with_async(login)
            })
    })
    .bind("127.0.0.1:8080")
    .unwrap()
    .start();

    let _ = sys.run();
}
