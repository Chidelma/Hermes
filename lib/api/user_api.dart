part of hermes;

@Get('/user/get/:id', dependencies: [Depends(verifyUser, params: ["Hello World"])])
Future<Map> retrieve(int id, { required Request request }) async {

  await Future.delayed(Duration(seconds: 2));

  print("User Id $id");

  return request.headers;
}

@Post('/user/create')
Future<User> create(User user) async {

  await Future.delayed(Duration(seconds: 2));

  print("${user.firstName} ${user.lastName} is ${user.age}");

  return user;
}

@Patch('/user/update')
Future<Map> update(String firstName, String lastName, int? age_) async {

  await Future.delayed(Duration(seconds: 2));

  print("$firstName $lastName is $age_");

  return {
    "firstName": firstName,
    "lastName": lastName,
    "age": age_
  };
}

@Put('/file/upload')
Future<void> upload(File file) async {

  print(await file.length());
}

@Delete('/delete/user/:id')
Future<void> deleteUser(int id) async  {


}

Future<void> verifyUser(String message) async {
  await Future.delayed(Duration(seconds: 2));
  
  if(message.isEmpty) {
    throw ServerException("Empty string", statusCode: HttpStatus.preconditionFailed);
  }

  print(message);
}