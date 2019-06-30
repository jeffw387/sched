import * as React from "react";
import SpacedButton from "./spaced_button";
import { Shift } from "../../shift";
import Employee from "../../employee";
import DayShift from "../day_shift";
import { LastNameStyle } from "../../last_name_style";
import { DateTime } from "luxon";
import { Config } from "../../config";
import ShiftEditor from "../shift_editor";

export interface ICalendarDayProps {
  view_date: DateTime;
  addToDate(days: number): void;
  shifts: Shift[];
  employees: Employee[];
  current_employee: Employee;
  active_config: Config;
  updateShift(shift: Shift): void;
  removeShift(shift: Shift): void;
}

function sameYMD(day: DateTime, dateTime: DateTime): boolean {
  let dayStart = DateTime.local(day.year, day.month, day.day);
  let dayEnd = DateTime.local(day.year, day.month, day.day + 1);
  return dateTime >= dayStart && dateTime < dayEnd;
}

export interface ICalendarDayState {
  shiftEditorOpen: boolean,
  activeShift?: Shift
}

export default class CalendarDay extends React.Component<
  ICalendarDayProps,
  ICalendarDayState
> {
  constructor(props: ICalendarDayProps) {
    super(props);

    this.state = {
      shiftEditorOpen: false,
    };
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

  openShiftEditor = (shift: Shift) => {
    this.setState({
        shiftEditorOpen: true,
        activeShift: shift
    });
  };

  closeShiftEditor = () => {
    this.setState({
      shiftEditorOpen: false,
      activeShift: undefined
    })
  };

  updateShift = (shift: Shift) => {
    this.props.updateShift(shift);
  };

  removeShift = (shift: Shift) => {
    this.props.removeShift(shift);
  };

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
              openShiftEditor={this.openShiftEditor}
              closeShiftEditor={this.closeShiftEditor}
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
        {this.state.activeShift ? 
          <ShiftEditor
            shift={this.state.activeShift}
            current_employee={this.props.current_employee}
            close={this.closeShiftEditor}
            isOpen={this.state.shiftEditorOpen}
            updateShift={this.updateShift}
            removeShift={this.removeShift}
          />
          : <div></div>
        }
        {this.props.view_date.toLocaleString({
          month: 'long',
          day: 'numeric',
          year: 'numeric'
        })}
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
