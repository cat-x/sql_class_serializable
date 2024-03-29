import 'package:analyzer/dart/element/element.dart';
import 'package:sql_class_annotation/sql_class_annotation.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

import 'json_key_utils.dart';
import 'type_helper.dart';
import 'type_helper_ctx.dart';
import 'unsupported_type_error.dart';
import 'utils.dart';

abstract class HelperCore {
  final ClassElement element;
  final TableSerializable config;

  HelperCore(this.element, this.config);

  Iterable<TypeHelper> get allTypeHelpers;

  void addMember(String memberContent);

  @protected
  String get targetClassReference =>
      '${element.name}${genericClassArgumentsImpl(false)}';

  @protected
  String nameAccess(FieldElement field) => columnKeyFor(field).name;

  @protected
  String safeNameAccess(FieldElement field) =>
      escapeDartString(nameAccess(field));

  @protected
  String get prefix => '_\$${element.name}';

  /// Returns a [String] representing the type arguments that exist on
  /// [element].
  ///
  /// Returns the output of calling [genericClassArguments] with [element].
  @protected
  String genericClassArgumentsImpl(bool withConstraints) =>
      genericClassArguments(element, withConstraints);

  @protected
  ColumnKey columnKeyFor(FieldElement field) => columnKeyForField(field, config);

  @protected
  TypeHelperCtx getHelperContext(FieldElement field) =>
      typeHelperContext(this, field, columnKeyFor(field));
}

InvalidGenerationSourceError createInvalidGenerationError(
    String targetMember, FieldElement field, UnsupportedTypeError e) {
  var message = 'Could not generate `$targetMember` code for `${field.name}`';
  if (field.type != e.type) {
    message = '$message because of type `${e.type}`';
  }
  message = '$message.\n${e.reason}';

  final todo = 'Make sure all of the types are serializable.';
  return InvalidGenerationSourceError(message, todo: todo, element: field);
}

/// Returns a [String] representing the type arguments that exist on
/// [element].
///
/// If [withConstraints] is `null` or if [element] has no type arguments, an
/// empty [String] is returned.
///
/// If [withConstraints] is true, any type constraints that exist on [element]
/// are included.
///
/// For example, for class `class Sample<T as num, S>{...}`
///
/// For [withConstraints] = `false`:
///
/// ```
/// "<T, S>"
/// ```
///
/// For [withConstraints] = `true`:
///
/// ```
/// "<T as num, S>"
/// ```
String genericClassArguments(ClassElement element, bool withConstraints) {
  if (withConstraints == null || element.typeParameters.isEmpty) {
    return '';
  }
  final values = element.typeParameters
      .map((t) => withConstraints ? t.toString() : t.name)
      .join(', ');
  return '<$values>';
}
