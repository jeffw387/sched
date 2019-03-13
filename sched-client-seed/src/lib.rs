pub mod root;

use root::{RootComponent, RootPage};

use seed::prelude::*;
use seed::h1;

#[derive(Clone, Debug)]
enum Message {
  Page(RootPage)
}

fn update(msg: Message, _root: RootComponent) -> Update<Message, RootComponent> {
  match msg {
    Message::Page(page) => Render(RootComponent {root_page: page})
  }
}

fn view(_state: seed::App<Message, RootComponent>, _root: &RootComponent) -> El<Message> {
  h1!["Test text"]
}

#[wasm_bindgen]
pub fn render() {
  seed::App::build(RootComponent::default(), update, view)
    .finish()
    .run();
}