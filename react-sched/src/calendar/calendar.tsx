import * as React from "react";
import { MockConfigs } from "../configs";
import { CalendarNav } from "./calendar_nav/calendar_nav";
import ViewsModal from "./views_modal";
import OptionsModal from "./options_modal";
import AccountModal from "./account_modal";
import { ViewDate } from "../view_date";
import CalendarDay from "./day/calendar_day";
import { MockShifts } from "../shifts";
import { ICRUD } from "../icrud";
import { Employee } from "../employee";
import { Shift } from "../shift";
import { MockEmployees } from "../employees";
import { Config } from "../config";
import { ICredentials, MockCredentials } from "../credentials";
import { DateTime } from "luxon";

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
  employees: ICRUD<Employee>;
  shifts: ICRUD<Shift>;
  configs: ICRUD<Config>;
  credentials: ICredentials;
  viewDate: ViewDate;
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
      employees: new MockEmployees(),
      shifts: new MockShifts(),
      configs: new MockConfigs(),
      credentials: new MockCredentials(),
      viewDate: new ViewDate()
    };

    this.state.credentials.check();
  }

  addToViewDate = (days: number) => {
    this.setState((state, _props) => {
      let vd = state.viewDate;
      vd.addDays(days);
      return {
        viewDate: vd
      };
    });
  };

  fetchEmployees = () => {};

  openViews = () => {
    this.setState((_state, _props) => {
      return {
        modal: CalendarModals.Views
      };
    });
  };
  openOptions = () => {
    this.setState((_state, _props) => {
      return {
        modal: CalendarModals.Config
      };
    });
  };
  openAccount = () => {
    this.setState((_state, _props) => {
      return {
        modal: CalendarModals.Account
      };
    });
  };
  closeModal = () => {
    this.setState((_state, _props) => {
      return {
        modal: CalendarModals.None
      };
    });
  };
  logOut = () => {};

  addShift = (date: DateTime) => {
    let newShift = new Shift();
    newShift.start = date;
    newShift.end = date;
    this.setState((state, _props) => {
      return {shifts: state.shifts.add(newShift)}
    });
    return newShift;
  }

  updateShift = (shift: Shift) => {
    this.setState((state, _props) => {
      return {shifts: state.shifts.update(shift)}
    });
  };

  removeShift = (shift: Shift) => {
    this.setState((state, _props) => {
      return {shifts: state.shifts.remove(shift)}
    });
    this.state.shifts.remove(shift);
  }

  visibleEmployees = (visibleEmployeeIds: number[]) => {
    return visibleEmployeeIds.map((id: number) => {
      return this.state.employees.get().find((emp: Employee) => {
        return emp.id === id;
      });
    });
  };

  chooseView(viewType: ViewType) {
    let configs = this.state.configs.get();
    let current_employee = this.state.credentials.get();
    if (current_employee) {
      let curr = current_employee;
      let active_cfg = configs.find((cfg: Config) => {
        if (curr.active_config !== undefined) {
          return cfg.id === curr.active_config;
        }
        return false;
      });
      if (active_cfg !== undefined) {
        switch (viewType) {
          case ViewType.Day:
            return (
              <CalendarDay
                view_date={this.state.viewDate.get()}
                addToDate={this.addToViewDate}
                shifts={this.state.shifts.get()}
                employees={this.state.employees.get()}
                current_employee={curr}
                visible_employees={this.visibleEmployees(active_cfg.view_employees)}
                active_config={active_cfg}
                addShift={this.addShift}
                updateShift={this.updateShift}
                removeShift={this.removeShift}
              />
            );
          case ViewType.Week:
            return <p>Week</p>;
          case ViewType.Month:
            return <p>Month</p>;
          default:
            return <p>Unknown view type!</p>;
        }
      }
    }
  }

  public render() {
    return (
      <div>
        <p>Calendar</p>
        <CalendarNav
          openViews={this.openViews}
          openOptions={this.openOptions}
          openAccount={this.openAccount}
          logOut={this.logOut}
        />
        {this.chooseView(this.state.viewType)}
        <ViewsModal
          isOpen={this.state.modal === CalendarModals.Views}
          close={this.closeModal}
        />
        <OptionsModal
          isOpen={this.state.modal === CalendarModals.Config}
          close={this.closeModal}
        />
        <AccountModal
          isOpen={this.state.modal === CalendarModals.Account}
          close={this.closeModal}
        />
      </div>
    );
  }
}
