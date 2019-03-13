use yew::{
    ShouldRender, 
    Component, 
    ComponentLink, 
    Renderable,
    Html,
    html};

pub struct LoginComponent {
    email: String,
    password: String,
    inputs_disabled: bool
}
pub enum Message {
    UpdateEmail(String),
    UpdatePassword(String),
    Submit
}
impl Component for LoginComponent {
    type Message = Message;
    type Properties = ();

    fn create(_: Self::Properties, _: ComponentLink<Self>) -> Self {
        LoginComponent { email: String::new(), password: String::new(), inputs_disabled: false }
    }

    fn update(&mut self, msg: Self::Message) -> ShouldRender {
        match msg {
            Message::UpdateEmail(upd) => {self.email = upd; false},
            Message::UpdatePassword(upd) => {self.password = upd; false},
            Message::Submit => {self.inputs_disabled = true; true}
        }
    }
}

impl Renderable<LoginComponent> for LoginComponent {
    fn view(&self) -> Html<Self> {
        html! {
            <div class="loginform",>
            <form onsubmit="return false",>
                <div>
                <input type="email", 
                    oninput=|upd| Message::UpdateEmail(upd.value),
                    disabled=self.inputs_disabled,
                    placeholder="*Email*",/>
                </div>
                <div><input type="password",
                    oninput=|upd| Message::UpdatePassword(upd.value),
                    disabled=self.inputs_disabled,
                    placeholder="*Password*",/>
                </div>
                <div class="login_buttons",>
                    <button 
                        type="submit",
                        disabled=self.inputs_disabled,
                        onclick=|_upd| Message::Submit,>{"Login"}</button>
                </div>
            </form>
            </div>
        }
    }
}