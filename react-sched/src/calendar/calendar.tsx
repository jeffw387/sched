import * as React from "react";
import { Employees } from "../employees";
import { Configs } from "../configs";
import { CalendarNav } from "./calendar_nav/calendar_nav";
import ViewsModal from "./views_modal";

enum ViewType {
  Month,
  Week,
  Day
}

enum CalendarModals {
  None,
  Views,
  Config,
  Account
}

export interface ICalendarProps {}

export interface ICalendarState {
  viewType: ViewType;
  modal: CalendarModals;
  employees: Employees;
  configs: Configs;
}

export default class Calendar extends React.Component<
  ICalendarProps,
  ICalendarState
> {
  constructor(props: ICalendarProps) {
    super(props);

    this.state = {
      viewType: ViewType.Day,
      modal: CalendarModals.None,
      employees: new Employees(),
      configs: new Configs()
    };
  }

  fetchEmployees = () => {};

  openViews = () => {
    this.setState((state, props) => {
      return {
        modal: CalendarModals.Views
      };
    });
  };
  openConfig = () => {
    this.setState((state, props) => {
      return {
        modal: CalendarModals.Config
      };
    });
  };
  openAccount = () => {
    this.setState((state, props) => {
      return {
        modal: CalendarModals.Account
      };
    });
  };
  closeModal = () => {
    this.setState((state, props) => {
      return {
        modal: CalendarModals.None
      };
    });
  };
  logOut = () => {};

  chooseView(viewType: ViewType) {
    switch (viewType) {
      case ViewType.Day:
        return <p>Day</p>;
      case ViewType.Week:
        return <p>Week</p>;
      case ViewType.Month:
        return <p>Month</p>;
      default:
        return <p>Unknown view type!</p>;
    }
  }

  public render() {
    return (
      <div>
        <p>Calendar</p>
        <CalendarNav
          openViews={this.openViews}
          openOptions={this.openConfig}
          openAccount={this.openAccount}
          logOut={this.logOut}
        />
        {this.chooseView(this.state.viewType)}
        <ViewsModal
          isOpen={this.state.modal === CalendarModals.Views}
          close={this.closeModal}
        />
      </div>
    );
  }
}
