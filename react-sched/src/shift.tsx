import { DateTime } from "luxon";

export enum ShiftRepeat {
  NeverRepeat,
  EveryWeek,
  EveryDay
}

export class ShiftMessage {
  id: number = 0;
  supervisor_id: number = 0;
  employee_id?: number;
  start: string = "";
  end: string = "";
  repeat: ShiftRepeat = ShiftRepeat.NeverRepeat;
  every_x?: number;
  note?: string;
  on_call: boolean = false;

}

export class Shift {
  id: number = 0;
  supervisor_id: number = 0;
  employee_id?: number;
  start: DateTime = DateTime.local();
  end: DateTime = DateTime.local();
  repeat: ShiftRepeat = ShiftRepeat.NeverRepeat;
  every_x?: number;
  note?: string;
  on_call: boolean = false;

}