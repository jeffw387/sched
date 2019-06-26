import * as React from "react";

export interface IViewsModalProps {
  isOpen: boolean;
  close(): void;
}

export interface IViewsModalState {}

export default class ViewsModal extends React.Component<
  IViewsModalProps,
  IViewsModalState
> {
  constructor(props: IViewsModalProps) {
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
          id="views-modal"
          checked={this.props.isOpen}
        />
        <label
          htmlFor="views-modal"
          className="overlay"
          onClick={this.close}
        />
        <article>
          <header>Select View</header>
        </article>
      </div>
    );
  }
}
