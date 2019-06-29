import Employee from "./employee";
import { EmployeeLevel } from "./employee_level";
import { EmployeeColor } from "./employee_color";
import { ICRUD } from "./icrud";

const test_data: Employee[] = [
  {
    id: 0,
    email: "jeffw387@gmail.com",
    level: EmployeeLevel.Admin,
    first: "Jeff",
    last: "Wright",
    default_color: EmployeeColor.LightBlue,
    printName: Employee.prototype.printName
  },
  {
    id: 1,
    email: "Timothy.Baker@providence.org",
    level: EmployeeLevel.Supervisor,
    first: "Tim",
    last: "Baker",
    default_color: EmployeeColor.Red,
    printName: Employee.prototype.printName
  }
];

export class MockEmployees implements ICRUD<Employee> {
  private employees: Employee[] = test_data;

  get(): Employee[] {
    return this.employees;
  }
  add(t: Employee): void {
    this.employees.push(t);
  }
  update(t: Employee): void {
    this.employees = this.employees.map((e: Employee) => {
      if (e.id === t.id) {
        return t;
      } else {
        return e;
      }
    });
  }
  remove(t: Employee): void {
    this.employees = this.employees.filter((e: Employee) => {
      return e.id !== t.id;
    });
  }
}

export class Employees {
  private employees?: Employee[];

  fetch() {
    window
      .fetch("/sched/api/get_employees", { method: "POST" })
      .then(data => {
        return data.json();
      })
      .then((json: Employee[]) => {
        this.employees = json;
      })
      .catch(err => console.log(err));
  }
}
