

import 'package:analyzer/dart/element/type.dart';

import '../type_helper.dart';
import 'to_from_string.dart';

class BigIntHelper extends TypeHelper {
  const BigIntHelper();

  @override
  String serialize(
          DartType targetType, String expression, TypeHelperContext context) =>
      bigIntString.serialize(targetType, expression, context.nullable);

  @override
  String deserialize(
          DartType targetType, String expression, TypeHelperContext context) =>
      bigIntString.deserialize(targetType, expression, context.nullable, false);
}
