export interface ICRUD<T> {
  get(): T[];
  add(t: T): ICRUD<T>;
  update(t: T): ICRUD<T>;
  remove(t: T): ICRUD<T>;
}