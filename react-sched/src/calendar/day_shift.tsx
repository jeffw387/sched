import * as React from "react";
import { Shift } from "../shift";
import Employee from "../employee";
import { LastNameStyle } from "../last_name_style";
import { DateTime } from "luxon";
import { HourFormat } from "../hour_format";

export interface IDayShiftProps {
  employee: Employee;
  lastNameStyle: LastNameStyle;
  showMinutes: boolean;
  hourFormat: HourFormat;
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

  printDate = (dt: DateTime) => {
    let baseFormat = "";
    switch (this.props.hourFormat) {
      case HourFormat.H12:
        baseFormat += "h";
        break;
      case HourFormat.H24:
        baseFormat += "H";
        break;
    }
    if (this.props.showMinutes) {
      baseFormat += ":mm";
    }
    let prefix = dt.toFormat(baseFormat);
    let suffix = "";
    if (this.props.hourFormat === HourFormat.H12) {
      if (dt.hour >= 12) {
        suffix += "p";
      }
      else {
        suffix += "a";
      }
    }
    return prefix + suffix;
  };

  public render() {
    return (
      <div className="stack pseudo button">
        {this.printName()}
        {" "}
        {this.printDate(this.props.shift.start)}
        -
        {this.printDate(this.props.shift.end)}
      </div>
    );
  }
}
