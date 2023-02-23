part of hermes;

class HTTPException implements Exception {

  final int statusCode;
  final String message;

  HTTPException(this.message, {this.statusCode = 500}) {
    toString();
  }

  @override
  String toString() {
    String msg = message;
    Log.exception(msg);
    return msg;
  }
}

class ClientException extends HTTPException {

  @override
  final int statusCode;
  @override
  final String message;

  ClientException(this.message, {this.statusCode = 500}) : super(message);
}

class ServerException extends HTTPException {

  @override
  final int statusCode;
  @override
  final String message;
  late String location;
  late String functionName;

  ServerException(this.message, {this.statusCode = 500}) : super(message);

  @override
  String toString() {

    var lines = StackTrace.current.toString().split('\n');

    for(var i = 0; i < lines.length; i++) {
      if(lines[i].contains("new ServerException")) {
        var parts = lines[i + 1].split(" ");
        functionName = parts[parts.length - 2];
        location = parts[parts.length - 1];
        break;
      }
    }
    
    String msg = "$message -> $location -> $functionName";
    Log.exception(msg);
    return msg;
  }
}

class Log {

  static const String _info = 'INFO';
  static const String _error = 'ERROR';
  static const String _warning = 'WARNING';
  static const String _exception = 'EXCEPTION';

  static info(String message) {
    print("$_info \t $message");
  }

  static error(String message) {
    print("$_error \t $message");
  }

  static warning(String message) {
    print("$_warning \t $message");
  }

  static exception(String message) {
    print("$_exception \t $message");
  }
}