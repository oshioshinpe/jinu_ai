import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import '../../data/services/code_analyzer_service.dart';

class CanvasModeScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  final String? language;

  const CanvasModeScreen({
    super.key,
    this.initialCode,
    this.language,
  });

  @override
  ConsumerState<CanvasModeScreen> createState() => _CanvasModeScreenState();
}

class _CanvasModeScreenState extends ConsumerState<CanvasModeScreen>
    with TickerProviderStateMixin {
  late CodeController _codeController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  bool _isFabExpanded = false;
  final CodeAnalyzerService _analyzer = CodeAnalyzerService();
  List<CodeIssue> _codeIssues = [];

  // Language configurations
  final Map<String, dynamic> _languageConfigs = {
    'dart': {'language': dart, 'extension': '.dart'},
    'javascript': {'language': javascript, 'extension': '.js'},
    'python': {'language': python, 'extension': '.py'},
    'java': {'language': java, 'extension': '.java'},
    'cpp': {'language': cpp, 'extension': '.cpp'},
  };

  String _currentLanguage = 'dart';

  @override
  void initState() {
    super.initState();
    
    // Initialize language
    _currentLanguage = widget.language ?? 'dart';
    
    // Initialize code controller
    _codeController = CodeController(
      text: widget.initialCode ?? _getDefaultCode(_currentLanguage),
      language: _languageConfigs[_currentLanguage]?['language'] ?? dart,
    );

    // Add listener for code changes to trigger analysis
    _codeController.addListener(_onCodeChanged);

    // Initialize FAB animation
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );

    // Trigger initial code analysis
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeCode();
    });
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    _analyzeCode();
  }

  Future<void> _analyzeCode() async {
    final issues = await _analyzer.analyzeCode(_codeController.text, _currentLanguage);
    if (mounted) {
      setState(() {
        _codeIssues = issues;
      });
    }
  }

  String _getDefaultCode(String language) {
    switch (language) {
      case 'dart':
        return '''void main() {
  print('Hello, World!');
}''';
      case 'javascript':
        return '''function main() {
  console.log('Hello, World!');
}

main();''';
      case 'python':
        return '''def main():
    print('Hello, World!')

if __name__ == '__main__':
    main()''';
      case 'java':
        return '''public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, World!");
    }
}''';
      case 'cpp':
        return '''#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}''';
      default:
        return '// Start coding here...';
    }
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  void _changeLanguage(String language) {
    setState(() {
      _currentLanguage = language;
      _codeController.language = _languageConfigs[language]?['language'] ?? dart;
    });
    _toggleFab(); // Close FAB menu after selection
  }

  void _runCode() {
    // TODO: Implement code execution
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Running $_currentLanguage code...'),
        backgroundColor: Colors.green,
      ),
    );
    _toggleFab();
  }

  void _saveCode() {
    // TODO: Implement code saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code saved successfully!'),
        backgroundColor: Colors.blue,
      ),
    );
    _toggleFab();
  }

  void _shareCode() {
    // TODO: Implement code sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code shared!'),
        backgroundColor: Colors.orange,
      ),
    );
    _toggleFab();
  }

  void _showIssuesPanel() {
    _toggleFab();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bug_report,
                        color: _getIssueColor(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Code Issues (${_codeIssues.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _codeIssues.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 64,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No issues found!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _codeIssues.length,
                            itemBuilder: (context, index) {
                              final issue = _codeIssues[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    _getIssueIcon(issue.severity),
                                    color: _getSeverityColor(issue.severity),
                                  ),
                                  title: Text(issue.message),
                                  subtitle: Text(
                                    'Line ${issue.line}:${issue.column} • ${issue.type.name}',
                                  ),
                                  trailing: Chip(
                                    label: Text(
                                      issue.severity.name.toUpperCase(),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: _getSeverityColor(issue.severity).withOpacity(0.2),
                                    labelStyle: TextStyle(
                                      color: _getSeverityColor(issue.severity),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    // TODO: Jump to line in editor
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getIssueIcon(IssueSeverity severity) {
    switch (severity) {
      case IssueSeverity.error:
        return Icons.error;
      case IssueSeverity.warning:
        return Icons.warning;
      case IssueSeverity.info:
        return Icons.info;
    }
  }

  Color _getSeverityColor(IssueSeverity severity) {
    switch (severity) {
      case IssueSeverity.error:
        return Colors.red;
      case IssueSeverity.warning:
        return Colors.orange;
      case IssueSeverity.info:
        return Colors.blue;
    }
  }

  void _exitCanvasMode() {
    Navigator.of(context).pop();
  }

  Color _getStatusColor() {
    if (_codeIssues.any((issue) => issue.severity == IssueSeverity.error)) {
      return Colors.red;
    } else if (_codeIssues.any((issue) => issue.severity == IssueSeverity.warning)) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  String _getStatusText() {
    if (_codeIssues.any((issue) => issue.severity == IssueSeverity.error)) {
      return 'Errors found';
    } else if (_codeIssues.any((issue) => issue.severity == IssueSeverity.warning)) {
      return 'Warnings found';
    } else {
      return 'Ready';
    }
  }

  Color _getIssueColor() {
    if (_codeIssues.any((issue) => issue.severity == IssueSeverity.error)) {
      return Colors.red;
    } else if (_codeIssues.any((issue) => issue.severity == IssueSeverity.warning)) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Canvas Mode - ${_currentLanguage.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF2D2D30) : Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitCanvasMode,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Show settings dialog
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: isDark ? const Color(0xFF2D2D30) : Colors.grey[200],
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _getStatusColor(),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                if (_codeIssues.isNotEmpty) ...[
                  Icon(
                    Icons.warning,
                    size: 12,
                    color: _getIssueColor(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_codeIssues.length} issue${_codeIssues.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getIssueColor(),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  'Lines: ${_codeController.text.split('\n').length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Code editor
          Expanded(
            child: CodeTheme(
              data: CodeThemeData(
                styles: isDark ? vs2015Theme : githubTheme,
              ),
              child: CodeField(
                controller: _codeController,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                lineNumberStyle: LineNumberStyle(
                  width: 50,
                  textStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  background: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                ),
                background: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          // Background overlay when expanded
          if (_isFabExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFab,
                child: Container(
                  color: Colors.black26,
                ),
              ),
            ),
          // FAB buttons
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Language selection FAB
                AnimatedBuilder(
                  animation: _fabAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _fabAnimation.value,
                      child: Opacity(
                        opacity: _fabAnimation.value,
                        child: FloatingActionButton.small(
                          heroTag: "language",
                          onPressed: () => _showLanguageSelector(context),
                          backgroundColor: Colors.purple,
                          child: const Icon(Icons.code, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Run code FAB
                AnimatedBuilder(
                  animation: _fabAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _fabAnimation.value,
                      child: Opacity(
                        opacity: _fabAnimation.value,
                        child: FloatingActionButton.small(
                          heroTag: "run",
                          onPressed: _runCode,
                          backgroundColor: Colors.green,
                          child: const Icon(Icons.play_arrow, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Save code FAB
                AnimatedBuilder(
                  animation: _fabAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _fabAnimation.value,
                      child: Opacity(
                        opacity: _fabAnimation.value,
                        child: FloatingActionButton.small(
                          heroTag: "save",
                          onPressed: _saveCode,
                          backgroundColor: Colors.blue,
                          child: const Icon(Icons.save, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Share code FAB
                AnimatedBuilder(
                  animation: _fabAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _fabAnimation.value,
                      child: Opacity(
                        opacity: _fabAnimation.value,
                        child: FloatingActionButton.small(
                          heroTag: "share",
                          onPressed: _shareCode,
                          backgroundColor: Colors.orange,
                          child: const Icon(Icons.share, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Issues panel FAB
                AnimatedBuilder(
                  animation: _fabAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _fabAnimation.value,
                      child: Opacity(
                        opacity: _fabAnimation.value,
                        child: FloatingActionButton.small(
                          heroTag: "issues",
                          onPressed: _showIssuesPanel,
                          backgroundColor: _getIssueColor(),
                          child: Badge(
                            isLabelVisible: _codeIssues.isNotEmpty,
                            label: Text('${_codeIssues.length}'),
                            child: const Icon(Icons.bug_report, color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Main FAB
                FloatingActionButton(
                  heroTag: "main",
                  onPressed: _toggleFab,
                  backgroundColor: theme.primaryColor,
                  child: AnimatedRotation(
                    turns: _isFabExpanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _isFabExpanded ? Icons.close : Icons.add,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...(_languageConfigs.keys.map((language) {
                return ListTile(
                  leading: Icon(
                    Icons.code,
                    color: _currentLanguage == language
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  ),
                  title: Text(
                    language.toUpperCase(),
                    style: TextStyle(
                      fontWeight: _currentLanguage == language
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _currentLanguage == language
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                  trailing: _currentLanguage == language
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _changeLanguage(language);
                  },
                );
              }).toList()),
            ],
          ),
        );
      },
    );
  }
}