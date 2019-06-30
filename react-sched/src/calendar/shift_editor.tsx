import * as React from 'react';
import { Shift } from '../shift';
import Employee from '../employee';

export interface IShiftEditorProps {
  shift: Shift,
  current_employee: Employee,
  close(): void,
  isOpen: boolean,
  updateShift(shift: Shift): void,
  removeShift(shift: Shift): void
}

export interface IShiftEditorState {
}

export default class ShiftEditor extends React.Component<IShiftEditorProps, IShiftEditorState> {
  constructor(props: IShiftEditorProps) {
    super(props);

    this.state = {
    }
  }

  updateShift = () => {
    this.props.updateShift(this.props.shift);
  };

  removeShift = () => {
    this.props.removeShift(this.props.shift);
    this.props.close();
  };

  public render() {
    return (
      <div className="modal">
        <input id="shiftEditor" type="checkbox"/>
        <label htmlFor="shiftEditor" className="overlay"/>
        <article>
          <button onClick={this.removeShift}>Remove</button>
          {JSON.stringify(this.props.shift)}
        </article>
      </div>
    );
  }
}
