import { Component, OnInit } from '@angular/core';
import { FormControl } from '@angular/forms';
import { CredentialsService } from '../credentials.service';
import { LoginInfo } from '../login-info';

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.css']
})
export class LoginComponent implements OnInit {
  email = new FormControl('');
  password = new FormControl('');
  constructor(
    private cred: CredentialsService
  ) { }

  ngOnInit() {
  }

  submit() {
    this.cred.login(new LoginInfo(this.email.value, this.password.value));
  }

}
