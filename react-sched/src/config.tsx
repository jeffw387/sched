import { HourFormat } from "./hour_format";
import { LastNameStyle } from "./last_name_style";

export class Config {
  id: number;
  employee_id: number;
  config_name: string = "Default";
  hour_format: HourFormat = HourFormat.H12;
  last_name_style: LastNameStyle = LastNameStyle.Initial;
  view_employees: number[] = [];
  show_minutes: boolean = false;
  show_shifts: boolean = true;
  show_vacations: boolean = false;
  show_call_shifts: boolean = false;
  show_disabled: boolean = false;

  constructor(id: number, employee_id: number) {
    this.id = id;
    this.employee_id = employee_id;
  }
}