import { EmployeeLevel } from "./employee_level";
import { EmployeeColor } from "./employee_color";
import { LastNameStyle } from "./last_name_style";

export default class Employee {
  id: number;
  email: string;
  active_config?: number;
  level: EmployeeLevel;
  first: string;
  last: string;
  phone_number?: string;
  default_color: EmployeeColor;

  printName(style: LastNameStyle) {
    switch (style) {
      case LastNameStyle.Full:
        return this.first + " " + this.last;
      case LastNameStyle.Initial:
        return this.first + " " + this.last[0] + ".";
      case LastNameStyle.Hidden:
        return this.first;
      default:
        return "Unknown name style!";
    }
  }

  constructor(
    id?: number,
    email?: string,
    active_config?: number,
    level?: EmployeeLevel,
    first?: string,
    last?: string,
    phone_number?: string,
    default_color?: EmployeeColor
  ) {
    this.id = id ? id : 0;
    this.email = email ? email : "";
    this.active_config = active_config;
    this.level = level ? level : EmployeeLevel.Read;
    this.first = first ? first : "";
    this.last = last ? last : "";
    this.phone_number = phone_number;
    this.default_color = default_color
      ? default_color
      : EmployeeColor.Blue;
  }
}
