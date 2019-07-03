  import { Employee } from "./employee";
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
  },
  {
    id: 1,
    email: "Timothy.Baker@providence.org",
    level: EmployeeLevel.Supervisor,
    first: "Tim",
    last: "Baker",
    default_color: EmployeeColor.Red,
  }
];

export class MockEmployees implements ICRUD<Employee> {
  private employees: Employee[] = test_data;

  get(): Employee[] {
    return this.employees;
  }
  add(t: Employee): MockEmployees {
    this.employees.push(t);
    return this;
  }
  update(t: Employee): MockEmployees {
    this.employees = this.employees.map((e: Employee) => {
      if (e.id === t.id) {
        return t;
      } else {
        return e;
      }
    });
    return this;
  }
  remove(t: Employee): MockEmployees {
    this.employees = this.employees.filter((e: Employee) => {
      return e.id !== t.id;
    });
    return this;
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
