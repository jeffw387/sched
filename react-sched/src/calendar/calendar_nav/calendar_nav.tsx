import * as React from "react";

export interface ICalendarNavProps {
  openViews(): void;
  openOptions(): void;
  openAccount(): void;
  logOut(): void;
}

export interface ICalendarNavState {
  navOpen: boolean;
}

export class CalendarNav extends React.Component<
  ICalendarNavProps,
  ICalendarNavState
> {
  constructor(props: Readonly<ICalendarNavProps>) {
    super(props);

    this.state = {
      navOpen: false
    };
  }

  navToggle = () => {
    this.setState((state, props) => {
      return {
        navOpen: !state.navOpen
      };
    });
  };

  openViews = () => {
    this.setState((state, props) => {
      return {
        navOpen: false
      };
    });
    this.props.openViews();
  };

  openOptions = () => {
    this.setState((state, props) => {
      return {
        navOpen: false
      };
    });
    this.props.openOptions();
  };

  openAccount = () => {
    this.setState((state, props) => {
      return {
        navOpen: false
      };
    });
    this.props.openAccount();
  };

  logOut = () => {
    this.setState((state, props) => {
      return {
        navOpen: false
      };
    });
    this.props.logOut();
  };

  public render() {
    return (
      <nav>
        <input
          type="checkbox"
          className="show"
          id="nav-toggle"
          checked={this.state.navOpen}
          onChange={this.navToggle}
        />
        <label htmlFor="nav-toggle" className="burger button">
          &#9776;
        </label>

        <div className="menu">
          <a onClick={this.openViews} className="button">
            Views
          </a>
          <a onClick={this.openOptions} className="button">
            Options
          </a>
          <a onClick={this.openAccount} className="button">
            Account
          </a>
          <a onClick={this.logOut} className="button">
            Log out
          </a>
        </div>
      </nav>
    );
  }
}
