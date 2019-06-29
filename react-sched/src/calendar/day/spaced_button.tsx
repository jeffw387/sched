import * as React from "react";

export interface ISpacedButtonProps {
  click(): void;
  text: string;
}

export interface ISpacedButtonState {}

export default class SpacedButton extends React.Component<
  ISpacedButtonProps,
  ISpacedButtonState
> {
  constructor(props: ISpacedButtonProps) {
    super(props);

    this.state = {};
  }

  public render() {
    return (
      <span className="spaced">
        <button onClick={() => this.props.click()}>
          {this.props.text}
        </button>
      </span>
    );
  }
}
