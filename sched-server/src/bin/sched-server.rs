#![feature(trait_alias)]
use actix_files::{
    Files,
    NamedFile,
};
use actix_web::{
    middleware,
    web::{
        self,
        HttpResponse,
        JsonConfig,
    },
    App,
    HttpRequest,
    HttpServer,
};
use diesel::pg::PgConnection;
use diesel::r2d2::{
    self,
    ConnectionManager,
};
use openssl::ssl::{
    SslAcceptor,
    SslFiletype,
    SslMethod,
};
use sched_server::api;
use sched_server::env;

pub const ENV_DB_URL: &str = "DATABASE_URL";
pub const STATIC_DIR: &str = "STATIC_DIR";

fn index_html(_: HttpRequest) -> actix_web::Result<NamedFile> {
    let static_dir = env::get_env(STATIC_DIR);
    Ok(NamedFile::open(static_dir + "/index.html")?)
}

fn test_client_js(_: HttpRequest) -> actix_web::Result<NamedFile> {
    let static_dir = env::get_env(STATIC_DIR);
    Ok(NamedFile::open(static_dir + "/test-client.js")?)
}

fn test_client_wasm(_: HttpRequest) -> actix_web::Result<NamedFile> {
    let static_dir = env::get_env(STATIC_DIR);
    Ok(NamedFile::open(static_dir + "/test-client.wasm")?)
}

fn print_request(
    req: HttpRequest,
) -> actix_web::Result<HttpResponse> {
    dbg!(req);
    Ok(HttpResponse::Ok().finish())
}

fn main() -> std::io::Result<()> {
    let db_url = env::get_env(ENV_DB_URL);
    // let static_dir = env::get_env(STATIC_DIR);
    env_logger::init();

    println!("database url: {}", db_url);
    let manager =
        ConnectionManager::<PgConnection>::new(db_url);

    let pool = r2d2::Pool::builder()
        .build(manager)
        .expect("Failed to create connection pool!");

    // let mut builder =
    //     SslAcceptor::mozilla_intermediate(SslMethod::tls())
    //         .unwrap();

    // builder
    //     .set_private_key_file("/etc/letsencrypt/live/www.jw387.com/privkey.pem", SslFiletype::PEM)
    //     .unwrap();

    // builder.set_certificate_chain_file("/etc/letsencrypt/live/www.jw387.com/fullchain.pem").unwrap();

    HttpServer::new(move || {
        App::new()
            .data(pool.clone())
            .wrap(middleware::Logger::default())
            .service(
                web::resource("/sched/login")
                    .data(JsonConfig::default())
                    .route(
                        web::post().to_async(api::login),
                    ),
            )
            .service(
                web::resource("/sched/check_token").route(
                    web::post().to_async(api::check_token),
                ),
            )
            .service(
                web::resource("/sched/change_password")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::change_password),
                    ),
            )
            .service(
                web::resource("/sched/get_active_config")
                    .route(
                        web::post()
                            .to_async(api::get_active_config),
                    ),
            )
            .service(
                web::resource("/sched/set_active_config")
                    .data(JsonConfig::default())
                    .route(
                        web::post().to_async(
                            api::set_active_config,
                        ),
                    ),
            )
            .service(
                web::resource("/sched/logout").route(
                    web::post().to_async(api::logout),
                ),
            )
            .service(
                web::resource("/sched/get_configs").route(
                    web::post().to_async(api::get_configs),
                ),
            )
            .service(
                web::resource("/sched/add_config")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::add_config),
                    ),
            )
            .service(
                web::resource("/sched/update_config")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::update_config),
                    ),
            )
            .service(
                web::resource("/sched/copy_config")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::copy_config),
                    ),
            )
            .service(
                web::resource("/sched/remove_config")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::remove_config),
                    ),
            )
            .service(
                web::resource("/sched/add_employee_config")
                    .data(JsonConfig::default())
                    .route(web::post().to_async(
                        api::add_employee_config,
                    )),
            )
            .service(
                web::resource(
                    "/sched/update_employee_config",
                )
                .data(JsonConfig::default())
                .route(
                    web::post().to_async(
                        api::update_employee_config,
                    ),
                ),
            )
            .service(
                web::resource("/sched/get_employees")
                    .route(
                        web::post()
                            .to_async(api::get_employees),
                    ),
            )
            .service(
                web::resource(
                    "/sched/get_current_employee",
                )
                .route(
                    web::post().to_async(
                        api::get_current_employee,
                    ),
                ),
            )
            .service(
                web::resource("/sched/add_employee")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::add_employee),
                    ),
            )
            .service(
                web::resource("/sched/update_employee")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::update_employee),
                    ),
            )
            .service(
                web::resource(
                    "/sched/update_employee_color",
                )
                .data(JsonConfig::default())
                .route(
                    web::post().to_async(
                        api::update_employee_color,
                    ),
                ),
            )
            .service(
                web::resource(
                    "/sched/update_employee_phone_number",
                )
                .data(JsonConfig::default())
                .route(
                    web::post().to_async(
                        api::update_employee_phone_number,
                    ),
                ),
            )
            .service(
                web::resource("/sched/remove_employee")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::remove_employee),
                    ),
            )
            .service(
                web::resource("/sched/get_shifts").route(
                    web::post().to_async(api::get_shifts),
                ),
            )
            .service(
                web::resource("/sched/add_shift")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::add_shift),
                    ),
            )
            .service(
                web::resource("/sched/update_shift")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::update_shift),
                    ),
            )
            .service(
                web::resource("/sched/remove_shift")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::remove_shift),
                    ),
            )
            .service(
                web::resource(
                    "/sched/get_shift_exceptions",
                )
                .route(
                    web::post().to_async(
                        api::get_shift_exceptions,
                    ),
                ),
            )
            .service(
                web::resource("/sched/add_shift_exception")
                    .data(JsonConfig::default())
                    .route(web::post().to_async(
                        api::add_shift_exception,
                    )),
            )
            .service(
                web::resource(
                    "/sched/remove_shift_exception",
                )
                .data(JsonConfig::default())
                .route(
                    web::post().to_async(
                        api::remove_shift_exception,
                    ),
                ),
            )
            .service(
                web::resource("/sched/get_vacations")
                    .route(
                        web::post()
                            .to_async(api::get_vacations),
                    ),
            )
            .service(
                web::resource("/sched/add_vacation")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::add_vacation),
                    ),
            )
            .service(
                web::resource("/sched/update_vacation")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::update_vacation),
                    ),
            )
            .service(
                web::resource("/sched/remove_vacation")
                    .data(JsonConfig::default())
                    .route(
                        web::post()
                            .to_async(api::remove_vacation),
                    ),
            )
            .service(
                web::resource(
                    "/sched/update_vacation_approval",
                )
                .data(JsonConfig::default())
                .route(
                    web::post().to_async(
                        api::update_vacation_approval,
                    ),
                ),
            )
            .service(
                web::resource("test-client.js")
                    .route(web::get().to(test_client_js))
            )
            .service(
                web::resource("test-client.wasm")
                    .route(web::get().to(test_client_wasm))
            )
            .service(
                web::resource("/sched")
                    .route(web::get().to(index_html)),
            )
            // .service(Files::new(
            //     "/sched/",
            //     &static_dir,
            // ))
            // .service(Files::new(
            //     "/",
            //     &static_dir,
            // ))
            // .service(Files::new(
            //     "/static/",
            //     &static_dir,
            // ))
            .default_service(web::get().to(print_request))
    })
    // .bind_ssl("0.0.0.0:443", builder)?
    .bind("0.0.0.0:8000")?
    .run()
}
