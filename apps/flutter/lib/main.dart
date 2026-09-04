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
import 'pages/settings_page.dart';
import 'pages/other_modules_page.dart';
import 'pages/ged_page.dart';
import 'pages/safety_events_page.dart';
import 'pages/risks_page.dart';
import 'pages/audits_page.dart';
import 'pages/non_conformities_page.dart';
import 'pages/actions_page.dart';
import 'pages/safety_talk_page.dart';
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

  // Même regroupement que le tableau de bord web (Gestion QHSE 360) : les
  // modules déjà réels côté app renvoient vers leur écran existant ; ceux qui
  // n'ont pas encore d'équivalent (même statut que côté web, voir
  // ROADMAP-CONSOLIDATION.md) ouvrent une page "Bientôt disponible" honnête
  // plutôt que de cacher leur absence.
  List<_NavGroup> get navGroups => [
    _NavGroup('PILOTAGE', [_NavItem('Tableau de bord', Icons.dashboard_outlined, null)]),
    _NavGroup('QUALITÉ (ISO 9001:2015)', [
      _NavItem('Contrôles qualité', Icons.fact_check_outlined, const QualityHome()),
      _NavItem('Processus & indicateurs', Icons.assignment_outlined, const ComingSoonPage(title: 'Processus & indicateurs')),
      _NavItem('Réclamations clients', Icons.notifications_outlined, const ComingSoonPage(title: 'Réclamations clients')),
      _NavItem('Fournisseurs', Icons.science_outlined, const ComingSoonPage(title: 'Fournisseurs')),
    ]),
    _NavGroup('SÉCURITÉ (ISO 45001:2018)', [
      _NavItem('Accidents & incidents', Icons.warning_amber_outlined, const SafetyEventsPage()),
      _NavItem('EPI, formations, permis', Icons.health_and_safety_outlined, const EpiPage()),
      _NavItem('Hygiène au travail', Icons.favorite_outline, const ComingSoonPage(title: 'Hygiène au travail')),
    ]),
    _NavGroup('ENVIRONNEMENT (ISO 14001:2026)', [_NavItem('Environnement', Icons.eco_outlined, const EnvironmentPage())]),
    _NavGroup('RISQUES & AUDITS', [
      _NavItem('Registre des risques', Icons.report_problem_outlined, const RisksPage()),
      _NavItem('Audits', Icons.assignment_turned_in_outlined, const AuditsPage()),
      _NavItem('Non-conformités', Icons.error_outline, const NonConformitiesPage()),
      _NavItem('Actions CAPA', Icons.build_outlined, const ActionsPage()),
    ]),
    _NavGroup('SYSTÈME', [
      _NavItem('Documentation (GED)', Icons.folder_open_outlined, const GedPage()),
      _NavItem("Quart d'heure sécurité", Icons.shield_outlined, const SafetyTalkPage()),
      _NavItem('HACCP', Icons.restaurant_menu_outlined, const HaccpPage()),
      _NavItem('Équipements', Icons.precision_manufacturing_outlined, const EquipmentPage()),
      _NavItem('Veille réglementaire', Icons.search_outlined, const ComingSoonPage(title: 'Veille réglementaire')),
      _NavItem('Objectifs QHSE', Icons.flag_outlined, const ComingSoonPage(title: 'Objectifs QHSE')),
    ]),
  ];

  void openItem(_NavItem item) {
    if (item.page == null) return; // Tableau de bord = déjà affiché
    Navigator.push(context, MaterialPageRoute(builder: (_) => item.page!));
  }

  Widget _syncAction() => Stack(clipBehavior: Clip.none, children: [
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
      ]);

  Widget _sidebarContent(BuildContext c, {required bool inDrawer}) => Container(
        width: 260,
        color: QhseColors.bg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: QhseColors.blue, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.shield, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Gestion QHSE 360', style: TextStyle(color: QhseColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Qualité · Sécurité · Hygiène · Environnement', style: TextStyle(color: QhseColors.textSecondary, fontSize: 10)),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final group in navGroups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                        child: Text(group.label, style: const TextStyle(color: QhseColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                      ),
                      for (final item in group.items)
                        ListTile(
                          dense: true,
                          leading: Icon(item.icon, size: 18, color: item.page == null ? QhseColors.blue : QhseColors.textSecondary),
                          title: Text(item.label, style: TextStyle(fontSize: 13, color: item.page == null ? QhseColors.blue : QhseColors.textPrimary)),
                          selected: item.page == null,
                          selectedTileColor: QhseColors.blue.withOpacity(0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () { if (inDrawer) Navigator.pop(c); openItem(item); },
                        ),
                    ],
                  ],
                ),
              ),
              const Divider(color: QhseColors.border, height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined, size: 18, color: QhseColors.textSecondary),
                title: const Text('Réglages', style: TextStyle(fontSize: 13, color: QhseColors.textPrimary)),
                onTap: () { if (inDrawer) Navigator.pop(c); Navigator.push(c, MaterialPageRoute(builder: (_) => const SettingsPage())); },
              ),
              ListTile(
                leading: const Icon(Icons.logout, size: 18, color: QhseColors.textSecondary),
                title: const Text('Déconnexion', style: TextStyle(fontSize: 13, color: QhseColors.textPrimary)),
                onTap: logout,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext c) {
    final wide = MediaQuery.of(c).size.width >= 900;
    final appBar = AppBar(
      title: const Text('Tableau de bord'),
      actions: [
        if (user != null)
          Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: Text('${user!['firstName'] ?? ''}', style: const TextStyle(fontSize: 13)))),
        _syncAction(),
      ],
    );
    if (wide) {
      return Scaffold(
        body: Row(children: [
          _sidebarContent(c, inDrawer: false),
          const VerticalDivider(width: 1, color: QhseColors.border),
          Expanded(child: Scaffold(appBar: appBar, body: const DashboardPage())),
        ]),
      );
    }
    return Scaffold(
      appBar: appBar,
      drawer: Drawer(child: _sidebarContent(c, inDrawer: true)),
      body: const DashboardPage(),
    );
  }
}

class _NavGroup { final String label; final List<_NavItem> items; _NavGroup(this.label, this.items); }
class _NavItem { final String label; final IconData icon; final Widget? page; _NavItem(this.label, this.icon, this.page); }

// Page honnête pour les modules qui n'ont pas encore de table dédiée côté
// API (voir ROADMAP-CONSOLIDATION.md) — jamais d'écran vide silencieux.
class ComingSoonPage extends StatelessWidget {
  final String title;
  const ComingSoonPage({super.key, required this.title});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.hourglass_empty, size: 48, color: QhseColors.textSecondary),
              const SizedBox(height: 16),
              Text('$title n\'est pas encore connecté', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: QhseColors.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Ce module nécessite une nouvelle table dans la base — il sera activé lors d\'une prochaine mise à jour.', style: TextStyle(fontSize: 13, color: QhseColors.textSecondary), textAlign: TextAlign.center),
            ]),
          ),
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


