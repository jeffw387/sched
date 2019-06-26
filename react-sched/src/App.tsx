import React from "react";
import logo from "./logo.svg";
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
    if (this.state.page === Page.Login) {
    } else if (this.state.page === Page.Calendar) {
      return <div>Calendar</div>;
    }
  }
}

// const App: React.FC = () => {
//   return (
//     <div className="App">

//       <header className="App-header">
//         {/* <img src={logo} className="App-logo" alt="logo" /> */}
//         <p>
//           Edit <code>src/App.tsx</code> and save to reload.
//         </p>
//         <a
//           className="App-link"
//           href="https://reactjs.org"
//           target="_blank"
//           rel="noopener noreferrer"
//         >
//           Learn React
//         </a>
//       </header>
//     </div>
//   );
// }

// export default App;
