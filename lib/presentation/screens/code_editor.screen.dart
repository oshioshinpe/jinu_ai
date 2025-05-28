import 'dart:io'; // For File operations
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:highlight/languages/dart.dart' as dart_lang;
import 'package:highlight/languages/python.dart' as python_lang;
import 'package:highlight/languages/javascript.dart' as js_lang;
import 'package:highlight/languages/json.dart' as json_lang;
import 'package:highlight/languages/xml.dart' as xml_lang; // For HTML & XML
import 'package:file_picker/file_picker.dart';
// import 'package:path_provider/path_provider.dart'; // If you need specific directories

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Code Editor',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          foregroundColor: Colors.black87,
          iconTheme: IconThemeData(color: Colors.deepPurple.shade500),
          actionsIconTheme: IconThemeData(color: Colors.deepPurple.shade500),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
          foregroundColor: Colors.deepPurple,
          side: BorderSide(color: Colors.deepPurple.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
        )),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        // Define a color scheme for the code editor if needed,
        // or use one of the predefined themes in `flutter_code_editor`
      ),
      home: const CodeEditorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CodeEditorScreen extends StatefulWidget {
  const CodeEditorScreen({super.key});

  @override
  State<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends State<CodeEditorScreen> {
  late CodeController _codeController;
  String _currentFilePath = '';
  String _selectedLanguage = 'dart'; // Default language

  final Map<String, dynamic> _supportedLanguages = {
    'dart': dart_lang.dart,
    'python': python_lang.python,
    'javascript': js_lang.javascript,
    'json': json_lang.json,
    'html': xml_lang.xml, // XML highlighter works for HTML
    'xml': xml_lang.xml,
  };

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: '// Welcome to Flutter Code Editor!\nvoid main() {\n  print("Hello, World!");\n}',
      language: _supportedLanguages[_selectedLanguage],
      // You can also specify a theme for the editor:
      // theme: monokaiSublimeTheme, // Example theme
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dart', 'py', 'js', 'json', 'html', 'xml', 'txt', 'md'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        String content = await file.readAsString();
        String extension = path.split('.').last.toLowerCase();

        setState(() {
          _codeController.text = content;
          _currentFilePath = path;
          if (_supportedLanguages.containsKey(extension)) {
            _selectedLanguage = extension;
            _codeController.language = _supportedLanguages[extension];
          } else {
            _selectedLanguage = 'plaintext'; // Default to plaintext if extension not supported
            _codeController.language = null; // Or a plaintext highlighter if you have one
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opened: ${result.files.single.name}')),
          );
        }
      } else {
        // User canceled the picker
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  Future<void> _saveFile({bool saveAs = false}) async {
    String? filePathToSave;

    if (saveAs || _currentFilePath.isEmpty) {
      filePathToSave = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: _currentFilePath.isNotEmpty
            ? _currentFilePath.split(Platform.pathSeparator).last
            : 'untitled.$_selectedLanguage',
        allowedExtensions: [_selectedLanguage, 'txt'], // Suggest current language
      );
    } else {
      filePathToSave = _currentFilePath;
    }

    if (filePathToSave != null) {
      try {
        final file = File(filePathToSave);
        await file.writeAsString(_codeController.text);
        setState(() {
          _currentFilePath = filePathToSave!;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File saved to: $filePathToSave')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving file: $e')),
          );
        }
      }
    }
  }

  void _runCode() {
    // For Dart, this is complex. For other languages, you might integrate
    // a Javascript engine or send to a backend.
    // For this example, we'll just show the code in a dialog.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Code (Simulation)'),
        content: SingleChildScrollView(child: Text(_codeController.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _createNewFile() {
    setState(() {
      _codeController.text = '// New file content\n';
      _currentFilePath = '';
      // Optionally reset language or keep current
      // _selectedLanguage = 'dart';
      // _codeController.language = _supportedLanguages[_selectedLanguage];
    });
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New file created')),
    );
  }


  @override
  Widget build(BuildContext context) {
    String fileName = _currentFilePath.isNotEmpty
        ? _currentFilePath.split(Platform.pathSeparator).last
        : "Untitled";

    return Scaffold(
      appBar: AppBar(
        title: Text('Editor - $fileName (${_selectedLanguage.toUpperCase()})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'New File',
            onPressed: _createNewFile,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Open File',
            onPressed: _openFile,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save File',
            onPressed: () => _saveFile(),
          ),
          IconButton(
            icon: const Icon(Icons.save_as_outlined),
            tooltip: 'Save As...',
            onPressed: () => _saveFile(saveAs: true),
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined),
            tooltip: 'Run Code',
            onPressed: _runCode,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language_outlined),
            tooltip: 'Select Language',
            onSelected: (String language) {
              setState(() {
                _selectedLanguage = language;
                _codeController.language = _supportedLanguages[language];
              });
            },
            itemBuilder: (BuildContext context) {
              return _supportedLanguages.keys.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice.toUpperCase()),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0), // Some padding around the editor
        child: CodeTheme( // Optional: Apply a theme to the editor
          data: CodeThemeData(styles: monokaiSublimeTheme), // Example: Monokai theme
          child: SingleChildScrollView( // Important for long code
            child: CodeField(
              controller: _codeController,
              textStyle: const TextStyle(fontFamily: 'RobotoMono', fontSize: 14), // Monospaced font
              minLines: 15, // Make editor take up some space
              wrap: false, // Disable line wrapping by default for code
            ),
          ),
        ),
      ),
    );
  }
}