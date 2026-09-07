import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: [
          IconButton(
            tooltip: 'Add level',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddLevelScreen()));
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('challenge_levels')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final levels = snapshot.data?.docs ?? [];
          levels.sort((a, b) {
            return (a.data()['level'] as int).compareTo(
              b.data()['level'] as int,
            );
          });

          if (levels.isEmpty) {
            return const Center(child: Text('No levels added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: levels.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final level = levels[index].data()['level'] as int;

              return ListTile(
                title: Text('Level $level'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit level',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AddLevelScreen(doc: levels[index])),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete level',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteLevel(context, levels[index]),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LevelItemsScreen(level: level),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteLevel(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> levelDoc,
  ) async {
    final level = levelDoc.data()['level'] as int;
    final items = await FirebaseFirestore.instance
        .collection('challenge_items')
        .where('level', isEqualTo: level)
        .limit(1)
        .get();
    if (items.docs.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete this level\'s items before deleting the level.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Level $level?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await levelDoc.reference.delete();
  }
}

class LevelItemsScreen extends StatelessWidget {
  const LevelItemsScreen({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Level $level')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddChallengeItemScreen(level: level),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('challenge_items')
            .where('level', isEqualTo: level)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          docs.sort((a, b) {
            final aData = a.data();
            final bData = b.data();
            final categoryCompare = '${aData['category']}'.compareTo(
              '${bData['category']}',
            );
            if (categoryCompare != 0) return categoryCompare;
            return '${aData['title']}'.compareTo('${bData['title']}');
          });

          final exercises = docs
              .where((doc) => doc.data()['category'] == 'exercises')
              .toList();
          final pieces = docs
              .where((doc) => doc.data()['category'] == 'pieces')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CategoryList(title: 'Exercises', docs: exercises),
              const SizedBox(height: 16),
              _CategoryList(title: 'Pieces', docs: pieces),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.title, required this.docs});

  final String title;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  Future<void> _deleteItem(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete item?'),
          content: Text('Delete "${data['title']}" and its uploaded files?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await FirebaseStorage.instance.refFromURL(data['musicXmlUrl']).delete();
    } catch (_) {}

    try {
      await FirebaseStorage.instance.refFromURL(data['midiUrl']).delete();
    } catch (_) {}

    try {
      await FirebaseStorage.instance.refFromURL(data['pdfUrl']).delete();
    } catch (_) {}

    await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return ListTile(
        title: Text(title),
        subtitle: const Text('No items yet.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final doc in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('${doc.data()['title']}'),
              subtitle: Text(
                'Points: ${doc.data()['points'] ?? 0}\nMusicXML: ${doc.data()['musicXmlFileName']}\nMIDI: ${doc.data()['midiFileName']}\nPDF: ${doc.data()['pdfFileName'] ?? 'None'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddChallengeItemScreen(
                            level: doc.data()['level'] as int,
                            doc: doc,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _deleteItem(context, doc),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }
}

class AddLevelScreen extends StatefulWidget {
  const AddLevelScreen({super.key, this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<AddLevelScreen> createState() => _AddLevelScreenState();
}

class _AddLevelScreenState extends State<AddLevelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _levelController = TextEditingController();
  bool _isSaving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final level = widget.doc?.data()['level'];
    if (level != null) _levelController.text = '$level';
  }

  @override
  void dispose() {
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final level = int.parse(_levelController.text.trim());
      final oldLevel = widget.doc?.data()['level'] as int?;
      final doc = widget.doc?.reference ??
          FirebaseFirestore.instance.collection('challenge_levels').doc('level_$level');
      await doc.set({
        'level': level,
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.doc == null) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (oldLevel != null && oldLevel != level) {
        final items = await FirebaseFirestore.instance
            .collection('challenge_items')
            .where('level', isEqualTo: oldLevel)
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (final item in items.docs) {
          batch.update(item.reference, {'level': level});
        }
        await batch.commit();
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _message = 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.doc == null ? 'Add level' : 'Edit level')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _levelController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Level number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final level = int.tryParse(value?.trim() ?? '');
                    if (level == null || level <= 0) {
                      return 'Enter a valid level number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Saving...' : widget.doc == null ? 'Save level' : 'Update level'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddChallengeItemScreen extends StatefulWidget {
  const AddChallengeItemScreen({super.key, required this.level, this.doc});

  final int level;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<AddChallengeItemScreen> createState() => _AddChallengeItemScreenState();
}

class _AddChallengeItemScreenState extends State<AddChallengeItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _pointsController = TextEditingController();

  String _category = 'exercises';
  PlatformFile? _musicXmlFile;
  PlatformFile? _midiFile;
  PlatformFile? _pdfFile;
  bool _isSaving = false;
  String? _message;

  bool get _isEditing => widget.doc != null;

  @override
  void initState() {
    super.initState();

    final data = widget.doc?.data();
    if (data == null) return;

    _category = '${data['category']}';
    _titleController.text = '${data['title']}';
    _pointsController.text = '${data['points'] ?? 0}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _pickMusicXml() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['musicxml', 'xml', 'mxl'],
      withData: true,
    );

    if (result != null) setState(() => _musicXmlFile = result.files.single);
  }

  Future<void> _pickMidi() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mid', 'midi'],
      withData: true,
    );

    if (result != null) setState(() => _midiFile = result.files.single);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) setState(() => _pdfFile = result.files.single);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEditing &&
        (_musicXmlFile?.bytes == null ||
            _midiFile?.bytes == null ||
            _pdfFile?.bytes == null)) {
      setState(() => _message = 'Choose MusicXML, MIDI, and PDF files.');
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final level = widget.level;
      final title = _titleController.text.trim();
      final points = int.parse(_pointsController.text.trim());
      final itemId = 'level_${level}_${_category}_${_makeSlug(title)}';
      final oldData = widget.doc?.data() ?? {};
      final doc = widget.doc?.reference ??
          FirebaseFirestore.instance.collection('challenge_items').doc(itemId);
      final folder = oldData['storageFolder'] ??
          'challenges/level_$level/$_category/${_makeSlug(title)}';
      final data = {
        'level': level,
        'category': _category,
        'title': title,
        'points': points,
        'storageFolder': folder,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_isEditing) data['createdAt'] = FieldValue.serverTimestamp();

      if (_musicXmlFile?.bytes != null) {
        await _deleteOldFile(oldData['musicXmlUrl']);
        final ref = FirebaseStorage.instance.ref('$folder/${_musicXmlFile!.name}');
        await ref.putData(_musicXmlFile!.bytes!);
        data['musicXmlUrl'] = await ref.getDownloadURL();
        data['musicXmlFileName'] = _musicXmlFile!.name;
      }

      if (_midiFile?.bytes != null) {
        await _deleteOldFile(oldData['midiUrl']);
        final ref = FirebaseStorage.instance.ref('$folder/${_midiFile!.name}');
        await ref.putData(_midiFile!.bytes!);
        data['midiUrl'] = await ref.getDownloadURL();
        data['midiFileName'] = _midiFile!.name;
      }

      if (_pdfFile?.bytes != null) {
        await _deleteOldFile(oldData['pdfUrl']);
        final ref = FirebaseStorage.instance.ref('$folder/${_pdfFile!.name}');
        await ref.putData(_pdfFile!.bytes!);
        data['pdfUrl'] = await ref.getDownloadURL();
        data['pdfFileName'] = _pdfFile!.name;
      }

      await doc.set(data, SetOptions(merge: true));

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() => _message = 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _makeSlug(String text) {
    final slug = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return slug.isEmpty ? 'untitled' : slug;
  }

  Future<void> _deleteOldFile(dynamic url) async {
    if (url == null || '$url'.isEmpty) return;
    try {
      await FirebaseStorage.instance.refFromURL('$url').delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_isEditing ? 'Edit' : 'Add'} item to Level ${widget.level}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'exercises',
                      child: Text('Exercises'),
                    ),
                    DropdownMenuItem(value: 'pieces', child: Text('Pieces')),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _category = value);
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Exercise or piece title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Title is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final points = int.tryParse(value?.trim() ?? '');
                    if (points == null || points < 0) return 'Enter valid points.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _isSaving ? null : _pickMusicXml,
                  child: Text(
                    _musicXmlFile == null
                        ? _isEditing
                            ? 'Replace MusicXML file'
                            : 'Choose MusicXML file'
                        : _musicXmlFile!.name,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isSaving ? null : _pickMidi,
                  child: Text(
                    _midiFile == null
                        ? _isEditing
                            ? 'Replace MIDI file'
                            : 'Choose MIDI file'
                        : _midiFile!.name,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isSaving ? null : _pickPdf,
                  child: Text(
                    _pdfFile == null
                        ? _isEditing
                            ? 'Replace PDF file'
                            : 'Choose PDF file'
                        : _pdfFile!.name,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Saving...' : _isEditing ? 'Update' : 'Save'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
