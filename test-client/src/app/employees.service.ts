import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

export enum EmployeeLevel {
  Read,
  Supervisor,
  Admin
}

export enum EmployeeColor {
  Red,
  LightRed,
  Green,
  LightGreen,
  Blue,
  LightBlue,
  Yellow,
  LightYellow,
  Grey,
  LightGrey,
  Black,
  Brown,
  Purple,
}

export class Employee {
  id: number;
  email: string;
  active_config?: number;
  level: EmployeeLevel;
  first: string;
  last: string;
  phone_number?: string;
  default_color: EmployeeColor;
}

@Injectable({
  providedIn: 'root'
})
export class EmployeesService {
  employees: Employee[];
  constructor(
    private http: HttpClient
  ) { }

  fetch() {
    this.http.post<Employee[]>("/sched/api/get_employees", {})
      .subscribe((data: Employee[]) => this.employees = { ...data });
  }

  getEmployees() {
    return this.employees;
  }
}
