## HERMES
This is a simple web framework named Hermes built in Dart, that allows users to easily create HTTP and WebSocket servers.

## Features
Support for multiple routes, including POST, GET, PUT, DELETE, WS, PATCH.
* A configurable dynamic delimiter to extract dynamic parameters from the URL path.
* Customizable middleware to enable logging of HTTP requests and responses.
* Support for WebSocket connections.

## Requirements
* Dart 2.12.0 or greater.

## Installation
Add hermes to your pubspec.yaml file and run pub get.

```yaml
dependencies:
  hermes: ^1.0.0
```

## Usage
* Import the library: import 'package:hermes/hermes.dart';
* Create an instance of the Hermes class:

```dart
final app = Hermes('my_library', port: 8080, origins: ['*'], headers: {}, dynamicDelimiter: ':');
```

* Here my_library is the name of the Dart library where you define your routes.
* Define your routes using the @Route annotation and the HTTP method:

```dart
@Route(Route.GET, '/hello')
String sayHello() => 'Hello, World!';
```

* Start the server with the serve method:

```dart
await app.serve();
```

* You can now visit http://localhost:8080/hello in your web browser to see the message "Hello, World!".

## Examples
There are a few examples available in the example folder in the package. Here's an example of how to create a WebSocket echo server:

```dart
@Route(Route.WS, '/echo')
void echo({WebSocketChannel socket}) {
  socket.stream.listen((data) {
    socket.sink.add(data);
  });
}
```

## Contributing
Please feel free to submit issues and pull requests.

## License
This project is licensed under the MIT License.
