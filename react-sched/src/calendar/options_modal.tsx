import * as React from "react";

export interface IOptionsModalProps {
  isOpen: boolean;
  close(): void;
}

export interface IOptionsModalState {}

export default class OptionsModal extends React.Component<
  IOptionsModalProps,
  IOptionsModalState
> {
  constructor(props: IOptionsModalProps) {
    super(props);

    this.state = {};
  }

  close = () => {
    this.props.close();
  };

  public render() {
    return (
      <div className="modal">
        <input
          type="checkbox"
          id="options-modal"
          checked={this.props.isOpen}
          onChange={this.close}
        />
        <label
          htmlFor="options-modal"
          className="overlay"
          onClick={this.close}
        />
        <article>
          <header>Options</header>
        </article>
      </div>
    );
  }
}
