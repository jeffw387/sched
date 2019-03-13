use yew::{
    ShouldRender, 
    Component, 
    ComponentLink, 
    Renderable,
    Html,
    html};
use crate::login::{LoginComponent};
use sched::message::LoginRequest;

pub enum Message {
    Login(LoginRequest),
    FetchLogin,
}

pub enum RootPage {
    Login,
    Settings,
    Calendar
}
pub struct RootComponent {
    pub root_page: RootPage
}

impl Component for RootComponent {
    type Message = ();
    type Properties = ();

    fn create(_: Self::Properties, _: ComponentLink<Self>) -> RootComponent {
        RootComponent { root_page: RootPage::Login }
    }

    fn update(&mut self, _: Self::Message) -> ShouldRender {
        true
    }
}

impl Renderable<RootComponent> for RootComponent {
    fn view(&self) ->Html<Self> {
        html! {
            <div class="header",>
            <h1>{"Login!"}</h1>
            <LoginComponent:/>
            </div>
        }
    }
}