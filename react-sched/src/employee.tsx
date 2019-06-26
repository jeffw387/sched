import { EmployeeLevel } from "./employee_level";
import { EmployeeColor } from "./employee_color";

export default class Employee {
    id: number = 0;
    email: string = "";
    active_config?: number;
    level: EmployeeLevel = EmployeeLevel.Read;
    first: string = "";
    last: string = "";
    phone_number?: string;
    default_color: EmployeeColor = EmployeeColor.Blue;
}