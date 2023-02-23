part of hermes;

class User {

  String firstName;
  int? age;
  String lastName;

  User(this.firstName, this.lastName, int? age_) {
    age = age_;
  }
}