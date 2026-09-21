import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api.dart';
import '../theme.dart';
import 'attachment_helpers.dart';

String _attachmentUrl(String baseUrl, String path) {
  if (path.startsWith('http')) return path;
  final origin = baseUrl.replaceAll(RegExp(r'/api/v4/?$'), '');
  return '$origin$path';
}

/// Section réutilisable "Pièces jointes / photos" (chantier issu de
/// l'audit, finding #22) — le mécanisme d'upload/liaison existait déjà côté
/// mobile (captureAndLinkPhoto, déjà branché sur Non-conformités et
/// Accidents) mais rien n'affichait jamais les photos une fois envoyées :
/// on pouvait ajouter, jamais consulter. Ce widget ferme cet écart, avec la
/// même convention d'appel que CapaLinksSection/DocumentLinksSection
/// (sourceModule/sourceEntityId — ici ownerType/ownerId, noms du modèle
/// Attachment côté API).
class AttachmentsSection extends StatefulWidget {
  final String ownerType;
  final String ownerId;
  const AttachmentsSection({super.key, required this.ownerType, required this.ownerId});
  @override
  State<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<AttachmentsSection> {
  final api = Api();
  List links = [];
  bool loading = true;
  String baseUrl = '';

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    baseUrl = await Api.currentBaseUrl();
    await load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      links = List.from(await api.get('/attachments/for?ownerType=${widget.ownerType}&ownerId=${widget.ownerId}'));
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> addPhoto() async {
    await captureAndLinkPhoto(context, api, widget.ownerType, widget.ownerId);
    load();
  }

  Future<void> removeLink(Map l) async {
    try {
      await api.delete('/attachments/link/${l['id']}');
      load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Pièces jointes / photos (${links.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        TextButton.icon(onPressed: addPhoto, icon: const Icon(Icons.add_a_photo_outlined, size: 16), label: const Text('Ajouter')),
      ]),
      if (loading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
      else if (links.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Aucune pièce jointe', style: TextStyle(color: QhseColors.textSecondary, fontSize: 12)))
      else
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: links.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final l = links[i];
              final a = l['attachment'] ?? {};
              final isImage = ('${a['mimeType'] ?? ''}').startsWith('image/');
              final url = a['url'] != null ? _attachmentUrl(baseUrl, a['url']) : null;
              return GestureDetector(
                onTap: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                onLongPress: () => removeLink(l),
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(border: Border.all(color: QhseColors.border), borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                  child: isImage && url != null
                      ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
                      : const Center(child: Icon(Icons.insert_drive_file_outlined, size: 28)),
                ),
              );
            },
          ),
        ),
      if (links.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Appui long pour retirer une pièce jointe', style: TextStyle(color: QhseColors.textSecondary, fontSize: 10))),
    ]),
  );
}
