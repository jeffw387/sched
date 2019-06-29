import * as React from "react";
import SpacedButton from "./spaced_button";
import { Shift } from "../../shift";
import Employee from "../../employee";
import DayShift from "../day_shift";
import { LastNameStyle } from "../../last_name_style";
import { DateTime } from "luxon";
import { Config } from "../../config";

export interface ICalendarDayProps {
  view_date: DateTime;
  addToDate(days: number): void;
  shifts: Shift[];
  employees: Employee[];
  active_config: Config;
}

function sameYMD(day: DateTime, dateTime: DateTime): boolean {
  let dayStart = DateTime.local(day.year, day.month, day.day);
  let dayEnd = DateTime.local(day.year, day.month, day.day + 1);
  return dateTime >= dayStart && dateTime < dayEnd;
}

export interface ICalendarDayState {}

export default class CalendarDay extends React.Component<
  ICalendarDayProps,
  ICalendarDayState
> {
  constructor(props: ICalendarDayProps) {
    super(props);

    this.state = {};
  }

  filterShifts(): Shift[] {
    return this.props.shifts.filter((shift: Shift) => {
      let a = sameYMD(this.props.view_date, shift.start);
      if (shift.employee_id !== undefined) {
        let b = this.props.active_config.view_employees.includes(
          shift.employee_id
        );
        return a && b;
      }
      return false;
    });
  }

  mapShifts() {
    let shifts_today = this.filterShifts();
    let sorted_shifts = shifts_today.sort((a, b) => {
      return a.start.diff(b.start).as("minutes");
    });
    return sorted_shifts.map((shift: Shift) => {
      if (shift.employee_id !== null) {
        let emp = this.props.employees.find(e => {
          return e.id === shift.employee_id;
        });
        if (emp) {
          return (
            <DayShift
              key={shift.id}
              employee={emp}
              lastNameStyle={
                this.props.active_config.last_name_style
              }
              showMinutes={this.props.active_config.show_minutes}
              hourFormat={this.props.active_config.hour_format}
              shift={shift}
            />
          );
        }
      }
      return <div key={shift.id}>Employee Not Found</div>;
    });
  }

  public render() {
    return (
      <>
        {this.props.view_date.toString()}
        <div>
          <SpacedButton
            click={() => {
              this.props.addToDate(-1);
            }}
            text="Previous Day"
          />
          <SpacedButton
            click={() => {
              this.props.addToDate(1);
            }}
            text="Next Day"
          />
        </div>
        <div>{this.mapShifts()}</div>
      </>
    );
  }
}
