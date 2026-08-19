import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class PiecesScreen extends StatelessWidget {
  const PiecesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pieces'),
        actions: [
          IconButton(
            tooltip: 'Add piece',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddPieceScreen()),
              );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('available_pieces').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          docs.sort((a, b) => '${a.data()['title']}'.compareTo('${b.data()['title']}'));

          if (docs.isEmpty) {
            return const Center(child: Text('No pieces added yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              return ListTile(
                title: Text('${data['title']}'),
                subtitle: Text(
                  'Composer: ${data['composer'] ?? ''}\nMusicXML: ${data['musicXmlFileName']}\nMIDI: ${data['midiFileName']}\nPDF: ${data['pdfFileName']}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddPieceScreen(doc: doc),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _deletePiece(context, doc),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deletePiece(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete piece?'),
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
}

class AddPieceScreen extends StatefulWidget {
  const AddPieceScreen({super.key, this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  @override
  State<AddPieceScreen> createState() => _AddPieceScreenState();
}

class _AddPieceScreenState extends State<AddPieceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _composerController = TextEditingController();

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

    _titleController.text = '${data['title']}';
    _composerController.text = '${data['composer'] ?? ''}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
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
      final title = _titleController.text.trim();
      final composer = _composerController.text.trim();
      final slug = _makeSlug(title);
      final oldData = widget.doc?.data() ?? {};
      final doc = widget.doc?.reference ??
          FirebaseFirestore.instance.collection('available_pieces').doc(slug);
      final folder = oldData['storageFolder'] ?? 'pieces/$slug';
      final data = {
        'title': title,
        'composer': composer,
        'storageFolder': folder,
        'searchText': '$title $composer'.toLowerCase(),
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit piece' : 'Add piece')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Piece title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Title is required.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _composerController,
                  decoration: const InputDecoration(
                    labelText: 'Composer',
                    border: OutlineInputBorder(),
                  ),
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
                  child: Text(_isSaving ? 'Saving...' : _isEditing ? 'Update piece' : 'Save piece'),
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
