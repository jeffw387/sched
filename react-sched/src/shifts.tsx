import { Shift, ShiftRepeat, ShiftMessage } from "./shift";
import { ICRUD } from "./icrud";
import { DateTime } from "luxon";

const test_data: Shift[] = [
  {
    id: 0,
    supervisor_id: 1,
    employee_id: 0,
    start: DateTime.local(2019, 6, 27, 8, 30),
    end: DateTime.local(2019, 6, 27, 19, 0),
    repeat: ShiftRepeat.NeverRepeat,
    on_call: false
  },
  {
    id: 1,
    supervisor_id: 1,
    employee_id: 1,
    start: DateTime.local(2019, 6, 27, 7, 0),
    end: DateTime.local(2019, 6, 27, 17, 0),
    repeat: ShiftRepeat.NeverRepeat,
    on_call: false
  }
];

export class MockShifts implements ICRUD<Shift> {
  private shifts: Shift[] = test_data;
  get(): Shift[] {
    return this.shifts;
  }
  update(shift: Shift): MockShifts {
    this.shifts = this.shifts.map((s: Shift) => {
      if (s.id === shift.id) {
        return s;
      } else {
        return shift;
      }
    });
    return this;
  }
  add(shift: Shift): MockShifts {
    let maxShift =
      this.shifts.length === 0
        ? shift
        : this.shifts.reduce(
            (
              prev: Shift,
              current: Shift,
              index: number,
              arr: Shift[]
            ) => {
              return {
                ...prev,
                ...{
                  id: current.id > prev.id ? current.id : prev.id
                }
              };
            }
          );

    this.shifts.push({
      ...shift,
      ...{ id: maxShift.id + 1 }
    });
    return this;
  }
  remove(shift: Shift): MockShifts {
    this.shifts = this.shifts.filter((s: Shift) => {
      return s.id !== shift.id;
    });
    return this;
  }
}

function fromShift(shift: Shift): ShiftMessage {
  return {
    id: shift.id,
    supervisor_id: shift.supervisor_id,
    employee_id: shift.employee_id,
    start: shift.start.toISO(),
    end: shift.end.toISO(),
    repeat: shift.repeat,
    every_x: shift.every_x,
    note: shift.note,
    on_call: shift.on_call
  };
}

function fromMsg(msg: ShiftMessage): Shift {
  return {
    id: msg.id,
    supervisor_id: msg.supervisor_id,
    employee_id: msg.employee_id,
    start: DateTime.fromISO(msg.start),
    end: DateTime.fromISO(msg.end),
    repeat: msg.repeat,
    every_x: msg.every_x,
    note: msg.note,
    on_call: msg.on_call
  };
}
