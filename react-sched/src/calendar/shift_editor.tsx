import * as React from "react";
import { Shift } from "../shift";
import { Employee, printEmployeeName } from "../employee";
import { LastNameStyle } from "../last_name_style";

export interface IShiftEditorProps {
  shift: Shift;
  current_employee: Employee;
  visible_employees: (Employee | undefined)[];
  close(): void;
  isOpen: boolean;
  updateShift(shift: Shift): void;
  removeShift(shift: Shift): void;
}

export interface IShiftEditorState {}

export default class ShiftEditor extends React.Component<
  IShiftEditorProps,
  IShiftEditorState
> {
  constructor(props: IShiftEditorProps) {
    super(props);

    this.state = {};
  }

  updateShift = (shift: Shift) => {
    this.props.updateShift(shift);
  };

  removeShift = () => {
    this.props.removeShift(this.props.shift);
    this.props.close();
  };

  employeeOptions = () => {
    return this.props.visible_employees.map(
      (employee?: Employee) => {
        if (employee !== undefined) {
          return (
            <option key={employee.id}>
              {printEmployeeName(employee, LastNameStyle.Full)}
            </option>
          );
        } else {
          return <option>Employee Error!</option>;
        }
      }
    );
  };

  public render() {
    return (
      <div className="modal">
        <input id="shiftEditor" type="checkbox" />
        <label htmlFor="shiftEditor" className="overlay" />
        <article>
          <header>
            <h2>Edit shift:</h2>
          </header>
          <section className="content">
            <select value={this.props.shift.employee_id}
                            onSelect={(e) => {
                              
                              this.updateShift({
                                ...this.props.shift,
                                ...{ employee_id: employee.id }
                              });
                            }}
            >
              {this.employeeOptions()}
            </select>
          </section>
          <footer>
            <button
              onClick={this.removeShift}
              className="dangerous"
            >
              Remove
            </button>
          </footer>
        </article>
      </div>
    );
  }
}
