

#[derive(Clone, Debug)]
pub enum RootPage {
  Login,
  Settings,
  Calendar
}

pub struct RootComponent {
  pub root_page: RootPage
}

impl Default for RootComponent {
  fn default() -> Self {
    Self {
      root_page: RootPage::Login
    }
  }
}

