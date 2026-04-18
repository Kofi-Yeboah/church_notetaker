import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ChurchNotesApp());
}

class ChurchNotesApp extends StatelessWidget {
  const ChurchNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Notetaker',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const NoteListScreen(),
    );
  }
}

// Model for a single block of content
class NoteBlock {
  String content;
  bool isVerse;
  TextEditingController? controller;

  NoteBlock({required this.content, this.isVerse = false}) {
    if (!isVerse) {
      controller = TextEditingController(text: content);
    }
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'isVerse': isVerse,
      };

  factory NoteBlock.fromJson(Map<String, dynamic> json) => NoteBlock(
        content: json['content'],
        isVerse: json['isVerse'],
      );
}

class Note {
  String id;
  String title;
  String preacher;
  DateTime sermonDate;
  List<NoteBlock> blocks;
  DateTime date;

  Note({
    required this.id,
    required this.title,
    required this.preacher,
    required this.sermonDate,
    required this.blocks,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'preacher': preacher,
        'sermonDate': sermonDate.toIso8601String(),
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'date': date.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        preacher: json['preacher'],
        sermonDate: DateTime.parse(json['sermonDate']),
        blocks: (json['blocks'] as List).map((b) => NoteBlock.fromJson(b)).toList(),
        date: DateTime.parse(json['date']),
      );
}

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  _NoteListScreenState createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('notes');
    if (notesJson != null) {
      final List<dynamic> decoded = json.decode(notesJson);
      setState(() {
        _notes = decoded.map((item) => Note.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_notes.map((note) => note.toJson()).toList());
    await prefs.setString('notes', encoded);
  }

  void _openEditor({Note? note}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(note: note),
      ),
    );

    if (result != null && result is Note) {
      setState(() {
        if (note == null) {
          _notes.add(result);
        } else {
          final int index = _notes.indexWhere((n) => n.id == note.id);
          if (index != -1) _notes[index] = result;
        }
      });
      _saveNotes();
    }
  }

  void _deleteNote(String id) {
    setState(() {
      _notes.removeWhere((n) => n.id == id);
    });
    _saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Church Notes'),
      ),
      body: _notes.isEmpty
          ? const Center(child: Text('No notes yet. Tap + to start writing.'))
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[_notes.length - 1 - index];
                return ListTile(
                  title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "${note.preacher} • ${note.sermonDate.day}/${note.sermonDate.month}/${note.sermonDate.year}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onLongPress: () => _deleteNote(note.id),
                  onTap: () => _openEditor(note: note),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  _NoteEditorScreenState createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _preacherController;
  late DateTime _selectedDate;
  List<NoteBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _preacherController = TextEditingController(text: widget.note?.preacher ?? '');
    _selectedDate = widget.note?.sermonDate ?? DateTime.now();
    
    if (widget.note != null) {
      _blocks = widget.note!.blocks.map((b) => NoteBlock(content: b.content, isVerse: b.isVerse)).toList();
    } else {
      _blocks = [NoteBlock(content: '')];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _preacherController.dispose();
    for (var block in _blocks) {
      block.controller?.dispose();
    }
    super.dispose();
  }

  void _showBiblePicker() async {
    final verse = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const BiblePickerSheet(),
    );

    if (verse != null) {
      setState(() {
        _blocks.add(NoteBlock(content: verse, isVerse: true));
        _blocks.add(NoteBlock(content: ''));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.book),
            onPressed: _showBiblePicker,
            tooltip: 'Insert Bible Verse',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              for (var block in _blocks) {
                if (block.controller != null) {
                  block.content = block.controller!.text;
                }
              }
              
              final note = Note(
                id: widget.note?.id ?? DateTime.now().toString(),
                title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
                preacher: _preacherController.text.isEmpty ? 'Unknown Preacher' : _preacherController.text,
                sermonDate: _selectedDate,
                blocks: _blocks.where((b) => b.content.isNotEmpty || b.isVerse).toList(),
                date: DateTime.now(),
              );
              Navigator.pop(context, note);
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _blocks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Sermon Title',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _preacherController,
                  decoration: const InputDecoration(
                    hintText: 'Preacher Name',
                    prefixIcon: Icon(Icons.person, size: 20),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
              ],
            );
          }

          final blockIndex = index - 1;
          final block = _blocks[blockIndex];

          if (block.isVerse) {
            return VerseCallout(
              content: block.content,
              onDelete: () {
                setState(() {
                  _blocks[blockIndex].controller?.dispose();
                  _blocks.removeAt(blockIndex);
                });
              },
            );
          } else {
            return TextField(
              controller: block.controller,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Start writing...',
                border: InputBorder.none,
              ),
              keyboardType: TextInputType.multiline,
              onChanged: (text) => block.content = text,
            );
          }
        },
      ),
    );
  }
}

class VerseCallout extends StatelessWidget {
  final String content;
  final VoidCallback onDelete;

  const VerseCallout({super.key, required this.content, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Colors.indigo, width: 5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.format_quote, color: Colors.indigo),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDelete,
              ),
            ],
          ),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class BiblePickerSheet extends StatefulWidget {
  const BiblePickerSheet({super.key});

  @override
  _BiblePickerSheetState createState() => _BiblePickerSheetState();
}

class _BiblePickerSheetState extends State<BiblePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _result = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchVerse() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final response = await http.get(Uri.parse('https://bible-api.com/${_searchController.text}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _result = "${data['text']}\n— ${data['reference']}";
        });
      } else {
        setState(() {
          _result = 'Verse not found.';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error fetching verse.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Search Bible Verse',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(hintText: 'e.g. John 3:16'),
                  onSubmitted: (_) => _searchVerse(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _searchVerse,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const CircularProgressIndicator()
          else if (_result.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_result),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _result),
              child: const Text('Insert as Callout'),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
