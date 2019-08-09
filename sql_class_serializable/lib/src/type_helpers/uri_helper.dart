

import 'package:analyzer/dart/element/type.dart';

import '../type_helper.dart';
import 'to_from_string.dart';

class UriHelper extends TypeHelper {
  const UriHelper();

  @override
  String serialize(
          DartType targetType, String expression, TypeHelperContext context) =>
      uriString.serialize(targetType, expression, context.nullable);

  @override
  String deserialize(
          DartType targetType, String expression, TypeHelperContext context) =>
      uriString.deserialize(targetType, expression, context.nullable, false);
}
