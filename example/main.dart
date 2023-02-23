import 'package:hermes/hermes.dart';

void main() async {
  await Hermes('hermes', origins: ["*"]).serve();
}