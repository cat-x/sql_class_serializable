import 'package:analyzer/dart/element/element.dart';
import 'package:sql_class_annotation/sql_class_annotation.dart';

import 'constants.dart';
import 'helper_core.dart';
import 'type_helpers/json_converter_helper.dart';
import 'unsupported_type_error.dart';

abstract class EncodeHelper implements HelperCore {
  String _fieldAccess(FieldElement field) => '$_toJsonParamName.${field.name}';

  Iterable<String> createToJson(Set<FieldElement> accessibleFields) sync* {
    assert(config.createToJson);

    final buffer = StringBuffer();

    final functionName = '${prefix}ToJson${genericClassArgumentsImpl(true)}';
    buffer.write('Map<String, dynamic> $functionName'
        '($targetClassReference $_toJsonParamName) ');

    final writeNaive = accessibleFields.every(_writeJsonValueNaive);

    if (writeNaive) {
      // write simple `toJson` method that includes all keys...
      _writeToJsonSimple(buffer, accessibleFields);
    } else {
      // At least one field should be excluded if null
      _writeToJsonWithNullChecks(buffer, accessibleFields);
    }

    yield buffer.toString();
  }

  void _writeToJsonSimple(StringBuffer buffer, Iterable<FieldElement> fields) {
    buffer.writeln('=> <String, dynamic>{');

    buffer.writeAll(fields.map((field) {
      final access = _fieldAccess(field);
      final value =
          '${safeNameAccess(field)}: ${_serializeField(field, access)}';
      return '        $value,\n';
    }));

    buffer.writeln('};');
  }

  static const _toJsonParamName = 'instance';

  void _writeToJsonWithNullChecks(
      StringBuffer buffer, Iterable<FieldElement> fields) {
    buffer.writeln('{');

    buffer.writeln('    final $generatedLocalVarName = <String, dynamic>{');

    // Note that the map literal is left open above. As long as target fields
    // don't need to be intercepted by the `only if null` logic, write them
    // to the map literal directly. In theory, should allow more efficient
    // serialization.
    var directWrite = true;

    for (final field in fields) {
      var safeFieldAccess = _fieldAccess(field);
      final safeColumnKeyString = safeNameAccess(field);

      // If `fieldName` collides with one of the local helpers, prefix
      // access with `this.`.
      if (safeFieldAccess == generatedLocalVarName ||
          safeFieldAccess == toJsonMapHelperName) {
        safeFieldAccess = 'this.$safeFieldAccess';
      }

      final expression = _serializeField(field, safeFieldAccess);
      if (_writeJsonValueNaive(field)) {
        if (directWrite) {
          buffer.writeln('      $safeColumnKeyString: $expression,');
        } else {
          buffer.writeln(
              '    $generatedLocalVarName[$safeColumnKeyString] = $expression;');
        }
      } else {
        if (directWrite) {
          // close the still-open map literal
          buffer.writeln('    };');
          buffer.writeln();

          // write the helper to be used by all following null-excluding
          // fields
          buffer.writeln('''
    void $toJsonMapHelperName(String key, dynamic value) {
      if (value != null) {
        $generatedLocalVarName[key] = value;
      }
    }
''');
          directWrite = false;
        }
        buffer.writeln(
            '    $toJsonMapHelperName($safeColumnKeyString, $expression);');
      }
    }

    buffer.writeln('    return $generatedLocalVarName;');
    buffer.writeln('  }');
  }

  String _serializeField(FieldElement field, String accessExpression) {
    try {
      return getHelperContext(field)
          .serialize(field.type, accessExpression)
          .toString();
    } on UnsupportedTypeError catch (e) {
      throw createInvalidGenerationError('toJson', field, e);
    }
  }

  /// Returns `true` if the field can be written to JSON 'naively' – meaning
  /// we can avoid checking for `null`.
  bool _writeJsonValueNaive(FieldElement field) {
    final columnKey = columnKeyFor(field);

    if (columnKey.includeIfNull) {
      return true;
    }

    if (!columnKey.nullable && !_fieldHasCustomEncoder(field)) {
      return true;
    }

    return false;
  }

  /// Returns `true` if [field] has a user-defined encoder.
  ///
  /// This can be either a `toJson` function in [ColumnKey] or a [JsonConverter]
  /// annotation.
  bool _fieldHasCustomEncoder(FieldElement field) {
    final helperContext = getHelperContext(field);

    if (helperContext.serializeConvertData != null) {
      return true;
    }

    final output = const JsonConverterHelper()
        .serialize(field.type, 'test', helperContext);

    if (output != null) {
      return true;
    }
    return false;
  }
}
