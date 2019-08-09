

import 'package:analyzer/dart/element/type.dart';

import '../type_helper.dart';
import 'to_from_string.dart';

class DateTimeHelper extends TypeHelper {
  const DateTimeHelper();

  @override
  String serialize(
          DartType targetType, String expression, TypeHelperContext context) =>
      dateTimeString.serialize(targetType, expression, context.nullable);

  @override
  String deserialize(
          DartType targetType, String expression, TypeHelperContext context) =>
      dateTimeString.deserialize(
          targetType, expression, context.nullable, false);
}
