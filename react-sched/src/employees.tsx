import Employee from "./employee";
import { EmployeeLevel } from "./employee_level";
import { EmployeeColor } from "./employee_color";

export class Employees {
  employees?: Employee[] = test_data;

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

const test_data: Employee[] = [
    {
        id: 0,
        email: "jeffw387@gmail.com",
        level: EmployeeLevel.Admin,
        first: "Jeff",
        last: "Wright",
        default_color: EmployeeColor.LightBlue
    },
    {
        id: 1,
        email: "Timothy.Baker@providence.org",
        level: EmployeeLevel.Supervisor,
        first: "Tim",
        last: "Baker",
        default_color: EmployeeColor.Red
    }
];

function make_employee(first: string, last: string): Employee {
  let emp = new Employee();
  emp.first = first;
  emp.last = last;
  return emp;
}
