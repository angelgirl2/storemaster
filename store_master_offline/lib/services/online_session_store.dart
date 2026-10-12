import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OnlineSessionStore {
  static final instance=OnlineSessionStore._(); OnlineSessionStore._();
  Future<File> _file() async { final d=await getApplicationSupportDirectory(); final f=Directory(p.join(d.path,'StoreMaster')); await f.create(recursive:true); return File(p.join(f.path,'online_session.json')); }
  Future<void> save(Map<String,dynamic> x) async => (await _file()).writeAsString(jsonEncode(x),flush:true);
  Future<Map<String,dynamic>> read() async { final f=await _file(); if(!await f.exists())return <String,dynamic>{}; try{final x=jsonDecode(await f.readAsString()); return x is Map?Map<String,dynamic>.from(x):<String,dynamic>{};}catch(_){return <String,dynamic>{};}}
  Future<void> clear() async {final f=await _file(); if(await f.exists())await f.delete();}
}
