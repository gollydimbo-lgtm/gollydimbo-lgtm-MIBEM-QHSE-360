import "dart:typed_data";
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/api.dart';
import 'services/sync_queue.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/epi_page.dart';
import 'pages/security_hub_page.dart';
import 'pages/settings_page.dart';
import 'pages/other_modules_page.dart';
import 'theme.dart';

// Clé de navigation globale : permet à Api.onUnauthorized (statique, sans
// BuildContext) de rediriger vers l'écran de connexion en cas de session expirée.
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  Api.onUnauthorized = () {
    Api().logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  };
  runApp(const QhseApp());
}

class QhseApp extends StatelessWidget{const QhseApp({super.key});@override Widget build(BuildContext c)=>MaterialApp(navigatorKey:navigatorKey,title:'Gestion QHSE 360',debugShowCheckedModeBanner:false,theme:buildQhseTheme(),darkTheme:buildQhseTheme(),themeMode:ThemeMode.dark,home:const AuthGate());}

// Vérifie au démarrage si une session est déjà ouverte (jeton stocké localement)
// et redirige vers le tableau de bord ou l'écran de connexion.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  final api = Api();
  bool? loggedIn;
  @override
  void initState() { super.initState(); check(); }
  Future<void> check() async { final t = await api.token(); setState(() => loggedIn = t != null); }
  @override
  Widget build(BuildContext c) {
    if (loggedIn == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return loggedIn! ? const HomeShell() : const LoginPage();
  }
}

// Coquille principale : tableau de bord de supervision + accès aux applications terrain,
// toutes branchées sur le même Core V4 / la même base de données.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  final api = Api();
  int index = 0;
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    api.currentUser().then((u) => setState(() => user = u));
    refreshPendingCount();
    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      final hasNetwork = result.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) syncNow(silent: true);
    });
  }

  @override
  void dispose() { _connSub?.cancel(); super.dispose(); }

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  int pendingSync = 0;
  bool syncing = false;

  Future<void> refreshPendingCount() async {
    final n = await SyncQueue.pendingCount();
    if (mounted) setState(() => pendingSync = n);
  }

  Future<void> syncNow({bool silent = false}) async {
    if (syncing) return;
    setState(() => syncing = true);
    final r = await SyncQueue.flush(api);
    await refreshPendingCount();
    setState(() => syncing = false);
    if (!silent && mounted) {
      final msg = r['synced']! > 0
          ? '${r['synced']} élément(s) synchronisé(s)${r['remaining']! > 0 ? ', ${r['remaining']} en attente' : ''}'
          : (r['remaining']! > 0 ? 'Toujours hors-ligne : ${r['remaining']} élément(s) en attente' : 'Rien à synchroniser');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> logout() async {
    await api.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
    }
  }

  static const titles = ['Tableau de bord', 'Contrôle Qualité', 'Gestion EPI', 'HSE & Sécurité', 'Autres modules'];
  final pages = const [DashboardPage(), QualityHome(), EpiPage(), SecurityHubPage(), OtherModulesPage()];

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(titles[index]),
      actions: [
        if (user != null)
          Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: Text('${user!['firstName'] ?? ''}', style: const TextStyle(fontSize: 13)))),
        Stack(clipBehavior: Clip.none, children: [
          IconButton(
            icon: syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(pendingSync > 0 ? Icons.cloud_off : Icons.cloud_done_outlined),
            tooltip: pendingSync > 0 ? '$pendingSync élément(s) en attente de synchronisation' : 'Tout est synchronisé',
            onPressed: () => syncNow(),
          ),
          if (pendingSync > 0)
            Positioned(
              right: 6, top: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text('$pendingSync', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
              ),
            ),
        ]),
        IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Réglages', onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsPage()))),
        IconButton(icon: const Icon(Icons.logout), tooltip: 'Déconnexion', onPressed: logout),
      ],
    ),
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) { setState(() => index = i); refreshPendingCount(); },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Qualité'),
        NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety), label: 'EPI'),
        NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Sécurité'),
        NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Modules'),
      ],
    ),
  );
}

class QualityHome extends StatefulWidget{const QualityHome({super.key});@override State<QualityHome> createState()=>_QualityHomeState();}
class _QualityHomeState extends State<QualityHome>{final api=Api();List controls=[];bool loading=true;@override void initState(){super.initState();load();}Future<void>load()async{try{final x=await api.get('/quality/controls');controls=List.from(x); }catch(e){}setState(()=>loading=false);} @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Contrôle Qualité')),floatingActionButton:FloatingActionButton.extended(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const NewControlPage())).then((_)=>load()),icon:const Icon(Icons.add),label:const Text('Nouveau contrôle')),body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(12),children:[Card(child:ListTile(title:const Text('Contrôles enregistrés'),trailing:Text('${controls.length}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)))),...controls.map((x)=>Card(child:ListTile(title:Text('${x['code']} — ${x['status']}'),subtitle:Text('${x['lotNumber']??''} • ${x['controlDate']??''}'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ControlPage(controlId:x['id'])))))) ])));}

class NewControlPage extends StatefulWidget{const NewControlPage({super.key});@override State<NewControlPage> createState()=>_NewControlPageState();}
class _NewControlPageState extends State<NewControlPage>{final api=Api();final code=TextEditingController(text:'CTRL-${DateTime.now().millisecondsSinceEpoch}'),lot=TextEditingController();List sites=[],products=[],shifts=[],templates=[];String? siteId,lineId,machineId,productId,formatId,shiftId,templateId;List lines=[],machines=[],formats=[];double? lat,lon;bool busy=false;
Future<void> init()async{try{final r=await api.get('/quality/catalogs');sites=List.from(r[0]);products=List.from(r[1]);shifts=List.from(r[2]);templates=List.from(r[3]);setState((){});}catch(e){_msg('$e');}}
@override void initState(){super.initState();init();}
Future<void>gps()async{if(!await Geolocator.isLocationServiceEnabled()){_msg('GPS désactivé');return;}var p=await Geolocator.checkPermission();if(p==LocationPermission.denied)p=await Geolocator.requestPermission();if(p==LocationPermission.denied||p==LocationPermission.deniedForever){_msg('Permission GPS refusée');return;}final x=await Geolocator.getCurrentPosition();setState((){lat=x.latitude;lon=x.longitude;});}
Future<void>create()async{if(lineId==null||productId==null||shiftId==null||lot.text.isEmpty||templateId==null){_msg('Ligne, produit, quart, lot et modèle sont obligatoires');return;}setState(()=>busy=true);try{final x=await api.post('/quality/controls',{'code':code.text,'siteId':siteId,'lineId':lineId,'machineId':machineId,'productId':productId,'formatId':formatId,'shiftId':shiftId,'lotNumber':lot.text,'templateId':templateId,'latitude':lat,'longitude':lon});if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ControlPage(controlId:x['id'])));}catch(e){_msg('$e');}setState(()=>busy=false);}
void _msg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Nouveau contrôle')),body:ListView(padding:const EdgeInsets.all(16),children:[TextField(controller:code,decoration:const InputDecoration(labelText:'Code contrôle')),TextField(controller:lot,decoration:const InputDecoration(labelText:'Numéro de lot')),const SizedBox(height:10),_drop('Site',siteId,sites.map((x)=>DropdownMenuItem<String>(value:x['id'] as String,child:Text(x['name']))).toList(),(v){siteId=v;final s=sites.firstWhere((x)=>x['id']==v);setState((){lines=List.from(s['lines']??[]);lineId=null;machineId=null;});}),_drop('Ligne',lineId,lines.map((x)=>DropdownMenuItem<String>(value:x['id'] as String,child:Text(x['name']))).toList(),(v){lineId=v;final l=lines.firstWhere((x)=>x['id']==v);setState(()=>machines=List.from(l['machines']??[]));}),_drop('Machine',machineId,machines.map((x)=>DropdownMenuItem<String>(value:x['id'] as String,child:Text(x['name']))).toList(),(v)=>setState(()=>machineId=v)),_drop('Produit',productId,products.map((x)=>DropdownMenuItem<String>(value:x['id'] as String,child:Text(x['name']))).toList(),(v){productId=v;final p=products.firstWhere((x)=>x['id']==v);setState(()=>formats=List.from(p['formats']??[]));}),_drop('Format',formatId,formats.map((x)=>DropdownMenuItem<String>(value:x['id'] as String,child:Text(x['label']))).toList(),(v)=>setState(()=>formatId=v)),_drop('Quart',shiftId,shifts.map((x)=>DropdownMenuItem<String>(value:x['id'] as String,child:Text(x['name']))).toList(),(v)=>setState(()=>shiftId=v)),_drop('Modèle de contrôle',templateId,templates.map((x)=>DropdownMenuItem<String>(value:x['id'] as String,child:Text(x['name']))).toList(),(v)=>setState(()=>templateId=v)),const SizedBox(height:12),OutlinedButton.icon(onPressed:gps,icon:const Icon(Icons.gps_fixed),label:Text(lat==null?'Capturer GPS':'GPS ${lat!.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}')),const SizedBox(height:18),FilledButton.icon(onPressed:busy?null:create,icon:const Icon(Icons.play_arrow),label:Text(busy?'Création...':'Démarrer le contrôle'))]));
Widget _drop(String label,String? value,List<DropdownMenuItem<String>> items,ValueChanged<String?> onChanged)=>DropdownButtonFormField<String>(value:value,decoration:InputDecoration(labelText:label),items:items,onChanged:onChanged);
}

class ControlPage extends StatefulWidget{final String controlId;const ControlPage({super.key,required this.controlId});@override State<ControlPage> createState()=>_ControlPageState();}
class _ControlPageState extends State<ControlPage>{final api=Api();Map<String,dynamic>? c;Map<String,bool?> vals={};bool loading=true;@override void initState(){super.initState();load();}Future<void>load()async{try{c=Map<String,dynamic>.from(await api.get('/quality/controls/${widget.controlId}'));}catch(e){}setState(()=>loading=false);}Future<void>result(dynamic p)async{bool? v=vals[p['id']];try{final x=await api.post('/quality/controls/${widget.controlId}/results',{'pointId':p['id'],'value':v,'compliant':v});vals[p['id']]=v;setState((){});}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
Future<void>photo()async{String? name;Uint8List? bytes;String mime='image/jpeg';if(kIsWeb||defaultTargetPlatform==TargetPlatform.windows){final r=await FilePicker.platform.pickFiles(type:FileType.image,withData:true);if(r==null||r.files.single.bytes==null)return;name=r.files.single.name;bytes=r.files.single.bytes;}else{final x=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:75);if(x==null)return;name=x.name;bytes=await x.readAsBytes();}try{final a=await api.post('/attachments/base64',{'fileName':name,'mimeType':mime,'base64':base64Encode(bytes!)});await api.post('/quality/controls/${widget.controlId}/attachments',{'attachmentId':a['id']});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Photo ajoutée au contrôle')));}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
Future<void>submit()async{try{await api.post('/quality/controls/${widget.controlId}/submit',{});await load();}catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}}
Future<void>sign()async{final controller=TextEditingController();final s=await showDialog<String>(context:context,builder:(_)=>AlertDialog(title:const Text('Signature numérique'),content:TextField(controller:controller,decoration:const InputDecoration(labelText:'Nom / signature')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),FilledButton(onPressed:()=>Navigator.pop(context,controller.text),child:const Text('Signer'))]));if(s!=null&&s.isNotEmpty){await api.post('/quality/controls/${widget.controlId}/signatures',{'type':'CONTROLLER','signatureData':s});}}
@override Widget build(BuildContext context){if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));final pts=List.from(c?['template']?['points']??[]);return Scaffold(appBar:AppBar(title:Text('${c?['code']}')),body:ListView(padding:const EdgeInsets.all(12),children:[Card(child:ListTile(title:Text('${c?['productRef']?['name']??''} • lot ${c?['lotNumber']??''}'),subtitle:Text('${c?['productionLine']?['name']??''} • ${c?['shiftRef']?['name']??''}'))),...pts.map((p)=>Card(child:ListTile(title:Text('${p['label']}${p['required']==true?' *':''}'),subtitle:Text(p['critical']==true?'Point critique':'Point de contrôle'),trailing:p['type']=='BOOLEAN'?Switch(value:vals[p['id']]??false,onChanged:(v){vals[p['id']]=v;result(p);}):const Icon(Icons.edit)))),const SizedBox(height:8),OutlinedButton.icon(onPressed:photo,icon:const Icon(Icons.camera_alt),label:const Text('Ajouter une photo')),OutlinedButton.icon(onPressed:sign,icon:const Icon(Icons.draw),label:const Text('Signer')),FilledButton.icon(onPressed:submit,icon:const Icon(Icons.check_circle),label:const Text('Soumettre et générer les NC'))]));}}


