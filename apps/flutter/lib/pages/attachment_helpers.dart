import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api.dart';

/// Capture la position GPS courante, en gérant les permissions.
/// Retourne null si le GPS est désactivé/refusé (l'appelant doit gérer ce cas
/// sans bloquer la déclaration terrain : le GPS reste optionnel).
Future<Position?> captureGps(BuildContext context) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS désactivé')));
    return null;
  }
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission GPS refusée')));
    return null;
  }
  return Geolocator.getCurrentPosition();
}

/// Prend une photo (caméra sur mobile, sélecteur de fichier sur web/Windows),
/// l'envoie sur /attachments/base64 puis la lie à l'entité (ownerType/ownerId)
/// via /attachments/link. Commun à toutes les applications terrain.
Future<void> captureAndLinkPhoto(BuildContext context, Api api, String ownerType, String ownerId) async {
  String? name;
  Uint8List? bytes;
  const mime = 'image/jpeg';
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r == null || r.files.single.bytes == null) return;
    name = r.files.single.name;
    bytes = r.files.single.bytes;
  } else {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
    if (x == null) return;
    name = x.name;
    bytes = await x.readAsBytes();
  }
  try {
    final a = await api.post('/attachments/base64', {'fileName': name, 'mimeType': mime, 'base64': base64Encode(bytes!)});
    await api.post('/attachments/link', {'ownerType': ownerType, 'ownerId': ownerId, 'attachmentId': a['id']});
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo ajoutée')));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

/// Badge coloré générique pour sévérité/priorité/score (1 à 5+).
Widget severityChip(int value, {String prefix = 'Sévérité'}) {
  final color = value >= 4 ? Colors.red : (value >= 3 ? Colors.orange : Colors.green);
  return Chip(label: Text('$prefix $value'), backgroundColor: color.withOpacity(0.15), labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold));
}

/// Génère un code lisible du type "PREFIX-AAAAMMJJ-HHmmss".
String genCode(String prefix) {
  final now = DateTime.now();
  String p(int n) => n.toString().padLeft(2, '0');
  return '$prefix-${now.year}${p(now.month)}${p(now.day)}-${p(now.hour)}${p(now.minute)}${p(now.second)}';
}
