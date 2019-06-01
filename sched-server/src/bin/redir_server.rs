use actix_files::NamedFile;
use actix_web::{
    web,
    App,
    HttpRequest,
    HttpResponse,
    HttpServer,
};

fn redir_response(_: HttpRequest) -> HttpResponse {
    HttpResponse::PermanentRedirect()
        .header("Location", "https://www.jw387.com/sched")
        .finish()
}

fn main() -> std::io::Result<()> {
    HttpServer::new(move || {
        App::new()
            .default_service(web::get().to(redir_response))
    })
    .bind("0.0.0.0:80")?
    .run()
}
