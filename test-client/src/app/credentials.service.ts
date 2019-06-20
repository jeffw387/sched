import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Employee } from './employees.service';
import { LoginInfo } from './login-info';

interface LoginResult {
  employee?: Employee
}

@Injectable({
  providedIn: 'root'
})
export class CredentialsService {

  current_employee?: Employee;

  constructor(
    private http: HttpClient
  ) { }

  check() {
    return this.current_employee;
  }

  login(login_info: LoginInfo) {
    console.log(login_info);
    this.http.post<LoginResult>("/sched/api/login", login_info)
      .subscribe((data: LoginResult) => this.current_employee = data.employee);
  }

  logout() {
    return this.http.post("/sched/api/logout", {});
  }
}
