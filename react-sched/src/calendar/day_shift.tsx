import * as React from "react";
import { Shift } from "../shift";
import Employee from "../employee";
import { LastNameStyle } from "../last_name_style";

export interface IDayShiftProps {
  employee: Employee;
  lastNameStyle: LastNameStyle;
  shift: Shift;
}

export interface IDayShiftState {}

export default class DayShift extends React.Component<
  IDayShiftProps,
  IDayShiftState
> {
  constructor(props: IDayShiftProps) {
    super(props);

    this.state = {};
  }

  printName = () => {
    return this.props.employee.printName(this.props.lastNameStyle);
  };

  printDate = () => {
    return this.props.shift.start.toString() + " to " + this.props.shift.end.toString();
  };

  public render() {
    return (
      <div className="card">
        <span>{this.printName()}</span>
        <span>{this.printDate()}</span>
      </div>
    );
  }
}
