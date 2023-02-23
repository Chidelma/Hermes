part of hermes;

class Route {

  final List<Depends> dependencies;
  final String route;
  final String method;

  static const String GET = 'GET';
  static const String PUT = 'PUT';
  static const String POST = 'POST';
  static const String PATCH = 'PATCH';
  static const String DELETE = 'DELETE';
  static const String WS = 'WS';
  
  const Route(this.route, {this.method = GET, this.dependencies = const []});  
}

class Get extends Route {

  @override
  final List<Depends> dependencies;
  @override
  final String route;
  
  const Get(this.route, {this.dependencies = const []}) : super(route);
}

class Post extends Route {

  @override
  final String method = Route.POST;
  @override
  final String route;
  @override
  final List<Depends> dependencies;
  
  const Post(this.route, {this.dependencies = const []}) : super(route);
}

class Put extends Route {

  @override
  final String method = Route.PUT;
  @override
  final List<Depends> dependencies;
  @override
  final String route;
  
  const Put(this.route, {this.dependencies = const []}) : super(route);
}

class Patch extends Route {

  @override
  final String method = Route.PATCH;
  @override
  final List<Depends> dependencies;
  @override
  final String route;
  
  const Patch(this.route, {this.dependencies = const []}) : super(route);
}

class Delete extends Route {

  @override
  final String method = Route.DELETE;
  @override
  final List<Depends> dependencies;
  @override
  final String route;
  
  const Delete(this.route, {this.dependencies = const []}) : super(route);
}

class WS extends Route {

  @override
  final String method = Route.WS;
  @override
  final List<Depends> dependencies;
  @override
  final String route;

  const WS(this.route, {this.dependencies = const []}) : super(route);
}

class Depends {
  final Function dependency;
  final List<dynamic> params;

  const Depends(this.dependency, {this.params = const []});
}