part of hermes;

class Hermes {
  
  int port;
  List<String> origins;
  late LibraryMirror lib;
  Map<String, Object> headers;
  String dynamicDelimiter;

  static Map<String, Map<String, MethodMirror>> allRoutes = {
    Route.POST: {},
    Route.GET: {},
    Route.PUT: {},
    Route.DELETE: {},
    Route.WS: {},
    Route.PATCH: {}
  };

  Hermes(String library, {this.port = 8080, this.origins = const [], this.headers = const {}, this.dynamicDelimiter = ':'}) {
    lib = currentMirrorSystem().findLibrary(Symbol(library));
    _indexRoutes();
  } 

  Future<void> serve() async {

    var handler = const Pipeline().addMiddleware(logRequests()).addHandler((req) {

      if(_isWebSocket(req.url.path)) {
        return webSocketHandler((socket) => _handleRequest(req, socket: socket), allowedOrigins: origins)(req);
      } else {
        return _handleRequest(req);
      }
    });

    var server = await shelf_io.serve(handler, 'localhost', port);

    server.autoCompress = true;

    print('Serving at http://${server.address.host}:${server.port}');
    print('Serving at ws://${server.address.host}:${server.port}');
  }

  bool _isWebSocket(String path) {
    return _getHandler(path, 'WS') != null;
  }

  Future<Response> _handleRequest(Request req, {WebSocketChannel? socket}) async {

    try {

      var path = req.url.path;

      var func = _getHandler(path, socket != null ? 'WS' : req.method);

      if(func == null) {
        throw ClientException("${req.method} $path Not Found", statusCode: HttpStatus.notFound);
      }

      MethodMirror handler = func['method'];
      Map pathParams = func['segs'];

      var params = handler.parameters;

      bool fileExpected = params.any((param) => param.type.reflectedType == File);
      dynamic body = await _getContent(req, socket: socket, fileExpected: fileExpected);

      dynamic response;

      var acceptsRequest = false;
      var acceptsSocket = false;

      if(params.isNotEmpty) {
        acceptsRequest = params.last.type.reflectedType == Request && params.last.isNamed;
        acceptsSocket = params.last.type.reflectedType == WebSocketChannel && params.last.isNamed;
      }

      Route route = handler.metadata.first.reflectee;

      if(route.dependencies.isNotEmpty) {
        await _invokeDependants(route.dependencies); 
      }

      if(fileExpected && body is File) {

        File file = body;

        var result = acceptsRequest ? lib.invoke(handler.simpleName, [file], { params.last.simpleName: req }) : lib.invoke(handler.simpleName, [file]);

        response = result.reflectee is Future ? await result.reflectee : result.reflectee;

        if(response != null) {
          response = _isUserDefined(reflect(response).type) ? json.encode(_deserializeObject(response)) : json.encode(response);
        }

        return Response.ok(response, headers: headers);
      }

      if(body == null && pathParams.isNotEmpty && params.isNotEmpty) {

        if(pathParams.length > params.length) {
          throw ClientException("Provided dynamic Segments are greater than expected params", statusCode: HttpStatus.badRequest);
        }

        List<dynamic> args = _compareArgs(params, pathParams);

        if(socket != null) {
          socket.stream.listen((event) {
            acceptsSocket ? lib.invoke(handler.simpleName, args, { params.last.simpleName: socket }) : lib.invoke(handler.simpleName, args);
          });
        } else {

          var result = acceptsRequest ? lib.invoke(handler.simpleName, args, { params.last.simpleName: req }) : lib.invoke(handler.simpleName, args);

          response = result.reflectee is Future ? await result.reflectee : result.reflectee;

          if(response != null) {
            response = _isUserDefined(reflect(response).type) ? json.encode(_deserializeObject(response)) : json.encode(response);
          }
        }

        return Response.ok(response, headers: headers);
      }
      
      if(body != null && body.isNotEmpty && params.isNotEmpty) {

        List<dynamic> args = _compareArgs(params, body);

        if(socket != null) {
          socket.stream.listen((event) {
            acceptsSocket ? lib.invoke(handler.simpleName, args, { params.last.simpleName: socket }) : lib.invoke(handler.simpleName, args);
          });
        } else {

          var result = acceptsRequest ? lib.invoke(handler.simpleName, args, { params.last.simpleName: req }) : lib.invoke(handler.simpleName, args);
          
          response = result.reflectee is Future ? await result.reflectee : result.reflectee;

          if(response != null) {
            response = _isUserDefined(reflect(response).type) ? json.encode(_deserializeObject(response)) : json.encode(response);
          }
        }

        return Response.ok(response, headers: headers);
      }

      if(socket != null) {

        socket.stream.listen((event) {
          List<dynamic> args = _compareArgs(params, event);
          acceptsSocket ? lib.invoke(handler.simpleName, args, { params.last.simpleName: socket }) : lib.invoke(handler.simpleName, args);
        });

      } else {

        var result = acceptsRequest ? lib.invoke(handler.simpleName, [], { params.last.simpleName: req }) : lib.invoke(handler.simpleName, []);
      
        response = result.reflectee is Future ? await result.reflectee : result.reflectee;

        if(response != null) {
          response = _isUserDefined(reflect(response).type) ? json.encode(_deserializeObject(response)) : json.encode(response);
        }
      }

      return Response.ok(response, headers: headers);

    } on ClientException catch(e) {

      return Response(e.statusCode, body: json.encode({
        "msg": e.message,
      }), headers: headers);

    } on ServerException catch(e) {

      return Response(e.statusCode, body: json.encode({
        "msg": e.message,
        "function": e.functionName,
        "location": e.location
      }), headers: headers);

    } catch(e, stacktrace) {

      Log.exception(e.toString());

      return Response(HttpStatus.badRequest, body: json.encode({
        "msg": e.toString(),
        "trace": stacktrace
      }), headers: headers);

    }
  }

  Future<dynamic> _getContent(Request req, {WebSocketChannel? socket, bool fileExpected = false}) async {

    dynamic reqData;

    if(req.url.queryParameters.isNotEmpty) {
      reqData = req.url.queryParameters;
    }

    if(reqData == null && socket == null) {
      String body = await req.readAsString();
      if(fileExpected) {
        reqData = await File('temp').writeAsString(body);
      } else {
        if(body.isNotEmpty) reqData = json.decode(body);
      }
    }

    return reqData;
  }

  List<dynamic> _compareArgs(List<ParameterMirror> params, dynamic body) {

    List<dynamic> args = [];

    if(params.length <= 2 && !params.first.isNamed && _isUserDefined(params.first.type) && body is Map) {

      Map data = Map.from(body);

      var clazz = reflectClass(params.first.type.reflectedType);

      var constructor = clazz.declarations[clazz.simpleName];
      var constructorMirror = constructor as MethodMirror;
      var constructParams = constructorMirror.parameters;

      List<dynamic> posArgs = [];

      for(var param in constructParams) {

        var field = MirrorSystem.getName(param.simpleName);

        bool isNullable = false;

        if(field.endsWith('_')) {
          isNullable = true;
          field = field.substring(0, field.length - 1);
        }

        if(!data.containsKey(field) && !isNullable) {
          throw ClientException("Property $field does not exist in request body", statusCode: HttpStatus.unprocessableEntity);
        }

        if(!data.containsKey(field) && isNullable) {
          posArgs.add(null);
        } else if(data.containsKey(field) && data[field].runtimeType != param.type.reflectedType) {
          posArgs.add(_parseString(data[field], param.type.reflectedType));
        } else {
          posArgs.add(data[field]);
        }
      }

      args = [clazz.newInstance(constructorMirror.constructorName, posArgs).reflectee]; 
    
    } else if(params.isNotEmpty && params.any((param) => !param.isNamed) && body is Map) {

      Map data = Map.from(body);

      params = params.where((param) => !param.isNamed).toList();

      for(var param in params) {

        var field = MirrorSystem.getName(param.simpleName);

        bool isNullable = false;

        if(field.endsWith('_')) {
          isNullable = true;
          field = field.substring(0, field.length - 1);
        }

        if(!data.containsKey(field) && !isNullable) {
          throw ClientException("Property $field does not exist in request body", statusCode: HttpStatus.unprocessableEntity);
        }

        if(!data.containsKey(field) && isNullable) {
          args.add(null);
        } else if(data.containsKey(field) && data[field].runtimeType != param.type.reflectedType) {
          args.add(_parseString(data[field], param.type.reflectedType));
        } else {
          args.add(data[field]);
        }
      }
    } 

    return args.isEmpty && !params.first.isNamed ? [body] : args;
  }

  Map _deserializeObject(Object result) {

    Map json = {};

    var clazz = reflect(result);

    var fields = clazz.type.declarations.values.whereType<VariableMirror>();

    for (var field in fields) {
      json[MirrorSystem.getName(field.simpleName)] = clazz.getField(field.simpleName).reflectee;
    }

    return json;
  }

  bool _isUserDefined(TypeMirror paramType) {

    return !paramType.isSubtypeOf(reflectType(num)) &&
      !paramType.isSubtypeOf(reflectType(int)) && 
      !paramType.isSubtypeOf(reflectType(double)) && 
      !paramType.isSubtypeOf(reflectType(String)) && 
      !paramType.isSubtypeOf(reflectType(bool)) && 
      !paramType.isSubtypeOf(reflectType(Map)) && 
      !paramType.isSubtypeOf(reflectType(List));
  }

  dynamic _parseString(String value, Type expected) {

    if (expected == int) {
      return int.parse(value);
    } else if (expected == double) {
      return double.parse(value);
    } else if (expected == String) {
      return value;
    } else if (expected == bool) {
      return value == 'true';
    } else {
      throw ClientException("Unsupported type: $expected", statusCode: HttpStatus.notAcceptable);
    }
  }

  void _indexRoutes() {

    var methods = lib.declarations.values.whereType<MethodMirror>().toList();

    for(var method in methods) {

      var metadataList = method.metadata;

      for(var metadata in metadataList) {

        if(metadata.type.isSubclassOf(reflectClass(Route))) {

          Route path = metadata.reflectee;

          if(!_isDuplicate(path.route, allRoutes[path.method]!)) {
            var route = path.route;
            if(route.startsWith('/')) route = route.substring(1);
            allRoutes[path.method]![route] = method;
          } else {
            throw ClientException("${path.method} ${path.route} already exist");
          }
        } else {
          continue;
        }
      }
    }
  }

  bool _isDuplicate(String path, Map<String, MethodMirror> routes) {

    if(routes.containsKey(path)) {
      return true;
    }

    if(path.contains(dynamicDelimiter)) {

      var segments = path.split('/');
      var paths = routes.keys;

      for(var path in paths) {

        var pathSegments = path.split('/');

        if(pathSegments.length == segments.length) {

          var isMatch = true;

          for(var i = 0; i < pathSegments.length; i++) {

            var pathSegment = pathSegments[i];
            var currSegment = segments[i];

            if(pathSegment != currSegment && !pathSegment.startsWith(dynamicDelimiter)) {
              isMatch = false;
              break;
            }
          }

          if(isMatch) {
            return true;
          }
        }
      }
    }

    return false;
  }

  dynamic _getHandler(String path, String method) {

    if(allRoutes[method]!.containsKey(path)) {
      return {
        "method": allRoutes[method]![path],
        "segs": {},
      };
    }

    for(var route in allRoutes[method]!.keys) {

      final routeSegments = route.split('/');
      final pathSegments = path.split('/');

      if(routeSegments.length != pathSegments.length) {
        continue;
      }

      final pathParams = <String, String>{};
      var isMatch = true;

      for(var i = 0; i < routeSegments.length; i++) {
        if(routeSegments[i].startsWith(dynamicDelimiter)) {
          pathParams[routeSegments[i].substring(1)] = pathSegments[i];
        } else if(routeSegments[i] != pathSegments[i]) {
          isMatch = false;
          break;
        }
      }

      if(isMatch) {
        return {
          "method": allRoutes[method]![route],
          "segs": pathParams,
        };
      }
    }

    return null;
  }

  Future<List<dynamic>> _invokeDependants(List<Depends> dependants) async {

    final result = <dynamic>[];

    List<Depends> modDepends = [];

    modDepends.addAll(dependants);

    while(modDepends.isNotEmpty) {

      var dep = modDepends.removeLast();

      var func = reflect(dep.dependency) as ClosureMirror;
      
      var res = func.apply(dep.params);

      if(res.reflectee is Future) {
        result.add(await res.reflectee);
      } else {
        result.add(res);
      }
    }

    return result;
  }
}