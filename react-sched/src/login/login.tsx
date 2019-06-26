import * as React from 'react';

export interface ILoginProps {
  onLogin: any
}

export default class Login extends React.Component<ILoginProps, any> {
  constructor(
    props: Readonly<ILoginProps>,
  ) {
    super(props)
  }

  handleLogin = (e: React.SyntheticEvent) => {
    // alert("submit");
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
          <input type="email" placeholder="Email"/>
          <input type="password" placeholder="Password"/>
          <input 
            type="submit" 
            value="Submit" 
          />
        </form>
      </div>
    );
  }
}
