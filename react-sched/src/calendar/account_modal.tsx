import * as React from "react";

export interface IAccountModalProps {
  isOpen: boolean;
  close(): void;
}

export interface IAccountModalState {}

export default class AccountModal extends React.Component<
  IAccountModalProps,
  IAccountModalState
> {
  constructor(props: IAccountModalProps) {
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
          id="account-modal"
          checked={this.props.isOpen}
          onChange={this.close}
        />
        <label
          htmlFor="account-modal"
          className="overlay"
          onClick={this.close}
        />
        <article>
          <header>Account</header>
        </article>
      </div>
    );
  }
}
