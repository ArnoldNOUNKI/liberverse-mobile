// Choix d'une photo (appareil photo ou galerie), compressée avant l'envoi
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/i18n.dart';

Future<XFile?> pickImage(BuildContext context, {bool cameraFirst = false, bool front = false}) async {
  final src = await showModalBottomSheet<ImageSource>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_rounded), title: Text(tr('Prendre une photo')), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded), title: Text(tr('Choisir dans la galerie')), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        const SizedBox(height: 8),
      ])));
  if (src == null) return null;
  final x = await ImagePicker().pickImage(source: src, maxWidth: 2000, maxHeight: 2000, imageQuality: 88,
      preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear);
  return x;
}
