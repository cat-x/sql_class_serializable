

class LambdaResult {
  final String expression;
  final String lambda;

  LambdaResult(this.expression, this.lambda);

  @override
  String toString() => '$lambda($expression)';

  static String process(Object subField, String closureArg) =>
      (subField is LambdaResult && closureArg == subField.expression)
          ? subField.lambda
          : '($closureArg) => $subField';
}
