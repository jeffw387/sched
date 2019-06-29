import React from "react";
import "./App.css";
import Login from "./login/login";
import Calendar from "./calendar/calendar";

enum Page {
  Login,
  Calendar
}

export interface IAppState {
  page: Page;
}

export default class App extends React.Component<{}, IAppState> {
  constructor(props: Readonly<{}>) {
    super(props);
    this.state = {
      page: Page.Login
    };
  }

  onLogin = () => {
    this.setState((prevState, prevProps) => {return {
      page: Page.Calendar
    }});
}

  render() {
    switch (this.state.page) {
      case Page.Login:
        return (
          <Login
            onLogin={this.onLogin}
          />
        );
      case Page.Calendar:
        return <Calendar/>
    
      default:
        return <div>No matching page!</div>;
    }
  }
}