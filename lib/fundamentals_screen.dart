import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

const _path = 'fundamentals_folders/fundamentals/lessons';

class FundamentalsScreen extends StatelessWidget {
  const FundamentalsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fundamentals'), actions: [
      IconButton(tooltip: 'Add lesson', icon: const Icon(Icons.add_to_photos_outlined), onPressed: () => _open(context, const LessonEditor())),
      IconButton(tooltip: 'Add lesson exercise', icon: const Icon(Icons.music_note_outlined), onPressed: () => _open(context, const ExerciseEditor())),
    ]),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(_path).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final docs = snapshot.data?.docs ?? [];
        docs.sort((a,b) => '${a.data()['title']}'.compareTo('${b.data()['title']}'));
        if (docs.isEmpty) return const Center(child: Text('No lessons or lesson exercises yet.'));
        return ListView.separated(padding: const EdgeInsets.all(16), itemCount: docs.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (context, i) {
          final doc = docs[i]; final d = doc.data(); final exercise = d['type'] == 'exercise';
          return ListTile(leading: Icon(exercise ? Icons.music_note_outlined : Icons.slideshow_outlined), title: Text('${d['title']}'), subtitle: Text(exercise ? 'Lesson exercise · MusicXML: ${d['musicXmlFileName'] ?? 'None'}' : '${(d['slides'] as List? ?? []).length} slide(s)'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => _open(context, exercise ? ExerciseEditor(doc: doc) : LessonEditor(doc: doc))),
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, doc)),
          ]));
        });
      },
    ),
  );
  void _open(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  Future<void> _delete(BuildContext context, QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('Delete ${doc.data()['title']}?'), content: const Text('This also deletes uploaded files.'), actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete'))]));
    if (ok != true) return; final d=doc.data(); final urls=<dynamic>[d['musicXmlUrl'],d['midiUrl'],d['pdfUrl']]; for(final s in d['slides'] as List? ?? []) { if(s is Map) urls.add(s['imageUrl']); } for(final u in urls) { if(u != null) { try { await FirebaseStorage.instance.refFromURL('$u').delete(); } catch (_) {} } } await doc.reference.delete();
  }
}

class LessonEditor extends StatefulWidget { const LessonEditor({super.key,this.doc}); final QueryDocumentSnapshot<Map<String,dynamic>>? doc; @override State<LessonEditor> createState()=>_LessonEditorState(); }
class _LessonEditorState extends State<LessonEditor> {
  final form=GlobalKey<FormState>(); final title=TextEditingController(); final slides=<_Slide>[]; bool saving=false; String? error; bool get editing=>widget.doc!=null;
  @override void initState(){super.initState();final d=widget.doc?.data();if(d!=null){title.text='${d['title']??''}';for(final s in d['slides'] as List? ?? []){if(s is Map)slides.add(_Slide.data(s));}}}
  @override void dispose(){title.dispose();for(final s in slides){s.dispose();}super.dispose();}
  Future<void> image() async {final r=await FilePicker.pickFiles(type:FileType.image,withData:true);if(r!=null)setState(()=>slides.add(_Slide.image(r.files.single)));}
  Future<void> save() async {if(!form.currentState!.validate())return;setState(()=>saving=true);try{final name=title.text.trim(), folder='fundamentals/${_slug(name)}', values=<Map<String,dynamic>>[];for(var i=0;i<slides.length;i++){final s=slides[i];if(s.textual){values.add({'type':'text','content':s.text.text.trim()});}else if(s.file!=null){final ref=FirebaseStorage.instance.ref('$folder/slides/${i+1}_${s.file!.name}');await ref.putData(s.file!.bytes!);values.add({'type':'image','imageUrl':await ref.getDownloadURL(),'imageFileName':s.file!.name});}else{values.add(s.saved!);}}await (widget.doc?.reference??FirebaseFirestore.instance.collection(_path).doc(_slug(name))).set({'type':'lesson','title':name,'slides':values,'storageFolder':folder,'updatedAt':FieldValue.serverTimestamp(),if(!editing)'createdAt':FieldValue.serverTimestamp()},SetOptions(merge:true));if(mounted)Navigator.pop(context);}catch(e){setState(()=>error='Save failed: $e');}finally{if(mounted)setState(()=>saving=false);}}
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(editing ? 'Edit lesson' : 'Add lesson')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Form(key: form, child: Column(children: [
        TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Lesson title', border: OutlineInputBorder()), validator: (v) => (v ?? '').trim().isEmpty ? 'Title is required.' : null),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(onPressed: saving ? null : () => setState(() => slides.add(_Slide.text())), icon: const Icon(Icons.text_fields), label: const Text('Add text slide')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: saving ? null : image, icon: const Icon(Icons.image_outlined), label: const Text('Add image slide')),
        ]),
        for (var i = 0; i < slides.length; i++)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: slides[i].textual ? TextFormField(controller: slides[i].text, maxLines: 3, decoration: const InputDecoration(labelText: 'Slide text', border: OutlineInputBorder())) : Text(slides[i].file?.name ?? slides[i].saved?['imageFileName'] ?? 'Image slide')),
            IconButton(onPressed: saving ? null : () => setState(() { slides[i].dispose(); slides.removeAt(i); }), icon: const Icon(Icons.delete_outline)),
          ]))),
        const SizedBox(height: 16),
        FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : 'Save lesson')),
        if (error != null) Text(error!),
      ])),
    ]),
  );
}

class ExerciseEditor extends StatefulWidget { const ExerciseEditor({super.key,this.doc}); final QueryDocumentSnapshot<Map<String,dynamic>>? doc; @override State<ExerciseEditor> createState()=>_ExerciseEditorState(); }
class _ExerciseEditorState extends State<ExerciseEditor>{final form=GlobalKey<FormState>();final title=TextEditingController();PlatformFile? xml,midi,pdf;bool saving=false;String? error;bool get editing=>widget.doc!=null;@override void initState(){super.initState();title.text='${widget.doc?.data()['title']??''}';}@override void dispose(){title.dispose();super.dispose();}Future<void> pick(String k)async{final r=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:k=='xml'?['musicxml','xml','mxl']:k=='midi'?['mid','midi']:['pdf'],withData:true);if(r!=null)setState((){if(k=='xml')xml=r.files.single;else if(k=='midi')midi=r.files.single;else pdf=r.files.single;});}Future<void> save()async{if(!form.currentState!.validate())return;if(!editing&&(xml==null||midi==null||pdf==null)){setState(()=>error='Choose MusicXML/MXL, MIDI, and PDF files.');return;}setState(()=>saving=true);try{final name=title.text.trim(),folder='fundamentals/${_slug(name)}',data=<String,dynamic>{'type':'exercise','title':name,'storageFolder':folder,'updatedAt':FieldValue.serverTimestamp(),if(!editing)'createdAt':FieldValue.serverTimestamp()};for(final entry in [('musicXml',xml),('midi',midi),('pdf',pdf)]){final f=entry.$2;if(f!=null){final r=FirebaseStorage.instance.ref('$folder/${f.name}');await r.putData(f.bytes!);data['${entry.$1}Url']=await r.getDownloadURL();data['${entry.$1}FileName']=f.name;}}await(widget.doc?.reference??FirebaseFirestore.instance.collection(_path).doc(_slug(name))).set(data,SetOptions(merge:true));if(mounted)Navigator.pop(context);}catch(e){setState(()=>error='Save failed: $e');}finally{if(mounted)setState(()=>saving=false);}}@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(editing?'Edit lesson exercise':'Add lesson exercise')),body:ListView(padding:const EdgeInsets.all(16),children:[Form(key:form,child:Column(children:[TextFormField(controller:title,decoration:const InputDecoration(labelText:'Exercise title',border:OutlineInputBorder()),validator:(v)=>(v??'').trim().isEmpty?'Title is required.':null),const SizedBox(height:16),button('MusicXML/MXL',xml,()=>pick('xml')),button('MIDI',midi,()=>pick('midi')),button('PDF',pdf,()=>pick('pdf')),const SizedBox(height:16),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving...':'Save exercise')),if(error!=null)Text(error!)]))]));Widget button(String label,PlatformFile? f,VoidCallback tap)=>Padding(padding:const EdgeInsets.only(bottom:8),child:OutlinedButton(onPressed:saving?null:tap,child:Text(f?.name??'${editing?'Replace':'Choose'} $label file')));}

class _Slide{_Slide.text():textual=true,text=TextEditingController(),file=null,saved=null;_Slide.image(this.file):textual=false,text=TextEditingController(),saved=null;_Slide.data(Map d):textual=d['type']=='text',text=TextEditingController(text:'${d['content']??''}'),file=null,saved=Map<String,dynamic>.from(d);final bool textual;final TextEditingController text;final PlatformFile? file;final Map<String,dynamic>? saved;void dispose()=>text.dispose();}
String _slug(String value){final s=value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'),'_').replaceAll(RegExp(r'^_|_$'),'');return s.isEmpty?'untitled':s;}
