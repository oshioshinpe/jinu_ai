import 'dart:async';

class CodeAnalyzerService {
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  Timer? _debounceTimer;

  // Analyze code and return issues
  Future<List<CodeIssue>> analyzeCode(String code, String language) async {
    final completer = Completer<List<CodeIssue>>();
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Start new timer
    _debounceTimer = Timer(_debounceDelay, () {
      final issues = _performAnalysis(code, language);
      completer.complete(issues);
    });
    
    return completer.future;
  }

  List<CodeIssue> _performAnalysis(String code, String language) {
    final issues = <CodeIssue>[];
    final lines = code.split('\n');

    switch (language.toLowerCase()) {
      case 'dart':
        issues.addAll(_analyzeDart(lines));
        break;
      case 'javascript':
        issues.addAll(_analyzeJavaScript(lines));
        break;
      case 'python':
        issues.addAll(_analyzePython(lines));
        break;
      case 'java':
        issues.addAll(_analyzeJava(lines));
        break;
      case 'cpp':
        issues.addAll(_analyzeCpp(lines));
        break;
    }

    // Add general issues
    issues.addAll(_analyzeGeneral(lines));

    return issues;
  }

  List<CodeIssue> _analyzeDart(List<String> lines) {
    final issues = <CodeIssue>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineNumber = i + 1;

      // Check for missing semicolons
      if (line.isNotEmpty && 
          !line.endsWith(';') && 
          !line.endsWith('{') && 
          !line.endsWith('}') &&
          !line.startsWith('//') &&
          !line.startsWith('/*') &&
          !line.startsWith('*') &&
          !line.startsWith('import') &&
          !line.startsWith('library') &&
          !line.startsWith('part') &&
          !line.contains('=>') &&
          !line.contains('if') &&
          !line.contains('for') &&
          !line.contains('while') &&
          !line.contains('switch') &&
          !line.contains('try') &&
          !line.contains('catch') &&
          !line.contains('finally') &&
          !line.contains('class') &&
          !line.contains('enum') &&
          !line.contains('mixin') &&
          !line.contains('extension')) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: line.length,
          message: 'Missing semicolon',
          severity: IssueSeverity.error,
          type: IssueType.syntax,
        ));
      }

      // Check for unused variables (simple heuristic)
      if (line.contains('var ') || line.contains('final ') || line.contains('const ')) {
        final variableName = _extractVariableName(line);
        if (variableName != null && !_isVariableUsed(variableName, lines, i)) {
          issues.add(CodeIssue(
            line: lineNumber,
            column: line.indexOf(variableName),
            message: 'Unused variable: $variableName',
            severity: IssueSeverity.warning,
            type: IssueType.unused,
          ));
        }
      }
    }

    return issues;
  }

  List<CodeIssue> _analyzeJavaScript(List<String> lines) {
    final issues = <CodeIssue>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineNumber = i + 1;

      // Check for missing semicolons
      if (line.isNotEmpty && 
          !line.endsWith(';') && 
          !line.endsWith('{') && 
          !line.endsWith('}') &&
          !line.startsWith('//') &&
          !line.startsWith('/*') &&
          !line.startsWith('*') &&
          !line.contains('if') &&
          !line.contains('for') &&
          !line.contains('while') &&
          !line.contains('function') &&
          !line.contains('class') &&
          !line.contains('try') &&
          !line.contains('catch') &&
          !line.contains('finally')) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: line.length,
          message: 'Consider adding semicolon',
          severity: IssueSeverity.info,
          type: IssueType.style,
        ));
      }

      // Check for == vs ===
      if (line.contains('==') && !line.contains('===')) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: line.indexOf('=='),
          message: 'Consider using === for strict equality',
          severity: IssueSeverity.warning,
          type: IssueType.style,
        ));
      }
    }

    return issues;
  }

  List<CodeIssue> _analyzePython(List<String> lines) {
    final issues = <CodeIssue>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      // Check for mixed tabs and spaces
      if (line.contains('\t') && line.contains('  ')) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: 0,
          message: 'Mixed tabs and spaces for indentation',
          severity: IssueSeverity.error,
          type: IssueType.style,
        ));
      }

      // Check for long lines
      if (line.length > 79) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: 79,
          message: 'Line too long (${line.length} > 79 characters)',
          severity: IssueSeverity.info,
          type: IssueType.style,
        ));
      }
    }

    return issues;
  }

  List<CodeIssue> _analyzeJava(List<String> lines) {
    final issues = <CodeIssue>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineNumber = i + 1;

      // Check for missing semicolons
      if (line.isNotEmpty && 
          !line.endsWith(';') && 
          !line.endsWith('{') && 
          !line.endsWith('}') &&
          !line.startsWith('//') &&
          !line.startsWith('/*') &&
          !line.startsWith('*') &&
          !line.startsWith('package') &&
          !line.startsWith('import') &&
          !line.contains('if') &&
          !line.contains('for') &&
          !line.contains('while') &&
          !line.contains('class') &&
          !line.contains('interface') &&
          !line.contains('try') &&
          !line.contains('catch') &&
          !line.contains('finally')) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: line.length,
          message: 'Missing semicolon',
          severity: IssueSeverity.error,
          type: IssueType.syntax,
        ));
      }
    }

    return issues;
  }

  List<CodeIssue> _analyzeCpp(List<String> lines) {
    final issues = <CodeIssue>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lineNumber = i + 1;

      // Check for missing semicolons
      if (line.isNotEmpty && 
          !line.endsWith(';') && 
          !line.endsWith('{') && 
          !line.endsWith('}') &&
          !line.startsWith('//') &&
          !line.startsWith('/*') &&
          !line.startsWith('*') &&
          !line.startsWith('#') &&
          !line.contains('if') &&
          !line.contains('for') &&
          !line.contains('while') &&
          !line.contains('class') &&
          !line.contains('struct') &&
          !line.contains('try') &&
          !line.contains('catch')) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: line.length,
          message: 'Missing semicolon',
          severity: IssueSeverity.error,
          type: IssueType.syntax,
        ));
      }
    }

    return issues;
  }

  List<CodeIssue> _analyzeGeneral(List<String> lines) {
    final issues = <CodeIssue>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNumber = i + 1;

      // Check for trailing whitespace
      if (line.endsWith(' ') || line.endsWith('\t')) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: line.length,
          message: 'Trailing whitespace',
          severity: IssueSeverity.info,
          type: IssueType.style,
        ));
      }

      // Check for TODO comments
      if (line.toLowerCase().contains('todo')) {
        issues.add(CodeIssue(
          line: lineNumber,
          column: line.toLowerCase().indexOf('todo'),
          message: 'TODO comment found',
          severity: IssueSeverity.info,
          type: IssueType.todo,
        ));
      }
    }

    return issues;
  }

  String? _extractVariableName(String line) {
    final patterns = [
      RegExp(r'var\s+(\w+)'),
      RegExp(r'final\s+(\w+)'),
      RegExp(r'const\s+(\w+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  bool _isVariableUsed(String variableName, List<String> lines, int declarationLine) {
    for (int i = declarationLine + 1; i < lines.length; i++) {
      if (lines[i].contains(variableName)) {
        return true;
      }
    }
    return false;
  }
}

class CodeIssue {
  final int line;
  final int column;
  final String message;
  final IssueSeverity severity;
  final IssueType type;

  const CodeIssue({
    required this.line,
    required this.column,
    required this.message,
    required this.severity,
    required this.type,
  });

  @override
  String toString() {
    return 'Line $line:$column - ${severity.name.toUpperCase()}: $message';
  }
}

enum IssueSeverity {
  error,
  warning,
  info,
}

enum IssueType {
  syntax,
  style,
  unused,
  todo,
}