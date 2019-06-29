import Employee from "./employee";
import { EmployeeLevel } from "./employee_level";
import { EmployeeColor } from "./employee_color";

export interface ICredentials {
  get(): Employee | undefined;
  check(): Promise<Employee>;
  login(user: string, password: string): Promise<Employee>;
  logout(): void;
}

const test_me = new Employee(
  0,
  "jeffw387@gmail.com",
  0,
  EmployeeLevel.Admin,
  "Jeff",
  "Wright",
  undefined,
  EmployeeColor.LightBlue
);

export class MockCredentials implements ICredentials {
  private current_employee?: Employee;
  get(): Employee | undefined {
    return this.current_employee;
  }
  async check(): Promise<Employee> {
    this.current_employee = test_me;
    return test_me;
  }
  async login(user: string, password: string): Promise<Employee> {
    return this.check();
  }
  logout(): void {
    this.current_employee = undefined;
  }
}
