import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../viewmodels/main_viewmodel.dart';

class AdvancedScannerScreen extends StatefulWidget { const AdvancedScannerScreen({super.key}); @override State<AdvancedScannerScreen> createState()=>_AdvancedScannerScreenState(); }
class _AdvancedScannerScreenState extends State<AdvancedScannerScreen>{
  final code=TextEditingController(); final focus=FocusNode(); final Map<int,int> counts={}; String status='آماده اسکن USB-HID / ورود دستی';
  void scan(MainViewModel vm,String raw){final c=raw.trim();if(c.isEmpty)return;final p=vm.products.cast<Product?>().firstWhere((x)=>x?.barcode==c,orElse:()=>null);if(p==null){setState(()=>status='بارکد $c پیدا نشد');}else{setState(()=>counts[p.id]=(counts[p.id]??0)+1);status='${p.name} × ${counts[p.id]}';}code.clear();FocusScope.of(context).requestFocus(focus);}
  @override void initState(){super.initState();Future.delayed(const Duration(milliseconds:200),()=>FocusScope.of(context).requestFocus(focus));}
  @override void dispose(){code.dispose();focus.dispose();super.dispose();}
  @override Widget build(BuildContext context){final vm=context.watch<MainViewModel>();final selected=vm.products.where((p)=>counts.containsKey(p.id)).toList();return Scaffold(appBar:AppBar(title:const Text('اسکن پیشرفته')),body:Column(children:[Card(margin:const EdgeInsets.all(12),child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[const Icon(Icons.qr_code_scanner,size:48),const SizedBox(height:8),Text(status),TextField(controller:code,focusNode:focus,autofocus:true,onSubmitted:(v)=>scan(vm,v),decoration:const InputDecoration(labelText:'بارکد را اسکن کنید',prefixIcon:Icon(Icons.keyboard_alt)),)]))),Expanded(child:ListView(children:selected.map((p)=>ListTile(leading:const Icon(Icons.inventory),title:Text(p.name),subtitle:Text('بارکد: ${p.barcode}'),trailing:Text('×${counts[p.id]}'))).toList())),if(selected.isNotEmpty)Padding(padding:const EdgeInsets.all(12),child:ElevatedButton.icon(onPressed:()=>setState(counts.clear),icon:const Icon(Icons.clear_all),label:const Text('پاک کردن سبد اسکن')))]));}
}
