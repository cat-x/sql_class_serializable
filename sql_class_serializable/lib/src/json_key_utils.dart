import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:sql_class_annotation/sql_class_annotation.dart';
import 'package:source_gen/source_gen.dart';

import 'json_literal_generator.dart';
import 'utils.dart';

final _columnKeyExpando = Expando<ColumnKey>();

ColumnKey columnKeyForField(FieldElement field, TableSerializable classAnnotation) =>
    _columnKeyExpando[field] ??= _from(field, classAnnotation);

/// Will log "info" if [element] has an explicit value for [ColumnKey.nullable]
/// telling the programmer that it will be ignored.
void logFieldWithConversionFunction(FieldElement element) {
  final columnKey = _columnKeyExpando[element];
  if (_explicitNullableExpando[columnKey] ?? false) {
    log.info(
      'The `ColumnKey.nullable` value on '
      '`${element.enclosingElement.name}.${element.name}` will be ignored '
      'because a custom conversion function is being used.',
    );

    _explicitNullableExpando[columnKey] = null;
  }
}

ColumnKey _from(FieldElement element, TableSerializable classAnnotation) {
  // If an annotation exists on `element` the source is a 'real' field.
  // If the result is `null`, check the getter – it is a property.
  // TODO(kevmoo) setters: github.com/dart-lang/json_serializable/issues/24
  final obj = columnKeyAnnotation(element);

  if (obj == null) {
    return _populateColumnKey(
      classAnnotation,
      element,
      ignore: classAnnotation.ignoreUnannotated,
    );
  }

  /// Returns a literal value for [dartObject] if possible, otherwise throws
  /// an [InvalidGenerationSourceError] using [typeInformation] to describe
  /// the unsupported type.
  Object literalForObject(
    DartObject dartObject,
    Iterable<String> typeInformation,
  ) {
    if (dartObject.isNull) {
      return null;
    }

    final reader = ConstantReader(dartObject);

    String badType;
    if (reader.isSymbol) {
      badType = 'Symbol';
    } else if (reader.isType) {
      badType = 'Type';
    } else if (dartObject.type is FunctionType) {
      // TODO(kevmoo): Support calling function for the default value?
      badType = 'Function';
    } else if (!reader.isLiteral) {
      badType = dartObject.type.name;
    }

    if (badType != null) {
      badType = typeInformation.followedBy([badType]).join(' > ');
      throwUnsupported(
          element, '`defaultValue` is `$badType`, it must be a literal.');
    }

    final literal = reader.literalValue;

    if (literal is num || literal is String || literal is bool) {
      return literal;
    } else if (literal is List<DartObject>) {
      return [
        for (var e in literal)
          literalForObject(e, [
            ...typeInformation,
            'List',
          ])
      ];
    } else if (literal is Map<DartObject, DartObject>) {
      final mapTypeInformation = [
        ...typeInformation,
        'Map',
      ];
      return literal.map(
        (k, v) => MapEntry(
          literalForObject(k, mapTypeInformation),
          literalForObject(v, mapTypeInformation),
        ),
      );
    }

    badType = typeInformation.followedBy(['$dartObject']).join(' > ');

    throwUnsupported(
        element,
        'The provided value is not supported: $badType. '
        'This may be an error in package:json_serializable. '
        'Please rerun your build with `--verbose` and file an issue.');
  }

  /// Returns a literal object representing the value of [fieldName] in [obj].
  ///
  /// If [mustBeEnum] is `true`, throws an [InvalidGenerationSourceError] if
  /// either the annotated field is not an `enum` or if the value in
  /// [fieldName] is not an `enum` value.
  Object _annotationValue(String fieldName, {bool mustBeEnum = false}) {
    final annotationValue = obj.getField(fieldName);

    final enumFields = iterateEnumFields(annotationValue.type);
    if (enumFields != null) {
      if (mustBeEnum && !isEnum(element.type)) {
        throwUnsupported(
          element,
          '`$fieldName` can only be set on fields of type enum.',
        );
      }
      final enumValueNames =
          enumFields.map((p) => p.name).toList(growable: false);

      final enumValueName = enumValueForDartObject<String>(
          annotationValue, enumValueNames, (n) => n);

      return '${annotationValue.type.name}.$enumValueName';
    } else {
      final defaultValueLiteral = literalForObject(annotationValue, []);
      if (defaultValueLiteral == null) {
        return null;
      }
      if (mustBeEnum) {
        throwUnsupported(
          element,
          'The value provided for `$fieldName` must be a matching enum.',
        );
      }
      return jsonLiteralAsDart(defaultValueLiteral);
    }
  }

  return _populateColumnKey(
    classAnnotation,
    element,
    defaultValue: _annotationValue('defaultValue'),
    disallowNullValue: obj.getField('disallowNullValue').toBoolValue(),
    ignore: obj.getField('ignore').toBoolValue(),
    includeIfNull: obj.getField('includeIfNull').toBoolValue(),
    name: obj.getField('name').toStringValue(),
    nullable: obj.getField('nullable').toBoolValue(),
    required: obj.getField('required').toBoolValue(),
    unknownEnumValue: _annotationValue('unknownEnumValue', mustBeEnum: true),
  );
}

ColumnKey _populateColumnKey(
  TableSerializable classAnnotation,
  FieldElement element, {
  Object defaultValue,
  bool disallowNullValue,
  bool ignore,
  bool includeIfNull,
  String name,
  bool nullable,
  bool required,
  Object unknownEnumValue,
}) {
  if (disallowNullValue == true) {
    if (includeIfNull == true) {
      throwUnsupported(
          element,
          'Cannot set both `disallowNullvalue` and `includeIfNull` to `true`. '
          'This leads to incompatible `toJson` and `fromJson` behavior.');
    }
  }

  final columnKey = ColumnKey(
    defaultValue: defaultValue,
    disallowNullValue: disallowNullValue ?? false,
    ignore: ignore ?? false,
    includeIfNull: _includeIfNull(
        includeIfNull, disallowNullValue, classAnnotation.includeIfNull),
    name: _encodedFieldName(classAnnotation, name, element),
    nullable: nullable ?? classAnnotation.nullable,
    required: required ?? false,
    unknownEnumValue: unknownEnumValue,
  );

  _explicitNullableExpando[columnKey] = nullable != null;

  return columnKey;
}

final _explicitNullableExpando = Expando<bool>('explicit nullable');

String _encodedFieldName(TableSerializable classAnnotation,
    String columnKeyNameValue, FieldElement fieldElement) {
  if (columnKeyNameValue != null) {
    return columnKeyNameValue;
  }

  switch (classAnnotation.fieldRename) {
    case FieldRename.none:
      return fieldElement.name;
    case FieldRename.snake:
      return snakeCase(fieldElement.name);
    case FieldRename.kebab:
      return kebabCase(fieldElement.name);
    case FieldRename.pascal:
      return pascalCase(fieldElement.name);
  }

  throw ArgumentError.value(
    classAnnotation,
    'classAnnotation',
    'The provided `fieldRename` (${classAnnotation.fieldRename}) is not '
        'supported.',
  );
}

bool _includeIfNull(
    bool keyIncludeIfNull, bool keyDisallowNullValue, bool classIncludeIfNull) {
  if (keyDisallowNullValue == true) {
    assert(keyIncludeIfNull != true);
    return false;
  }
  return keyIncludeIfNull ?? classIncludeIfNull;
}
