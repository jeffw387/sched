import * as React from 'react';

export interface ILoginProps {
  onLogin: any
}

export default class Login extends React.Component<ILoginProps, any> {
  handleLogin = (e: React.SyntheticEvent) => {
    this.props.onLogin();
    e.preventDefault();
  }

  public render() {
    return (
      <div>
        <header>
            <h2>Log into Scheduler</h2>
        </header>
        <form onSubmit={this.handleLogin}>
          <input type="email" placeholder="Email" className="stack"/>
          <input type="password" placeholder="Password" className="stack"/>
          <input 
            type="submit" 
            value="Submit" 
            className="stack"
          />
        </form>
      </div>
    );
  }
}
