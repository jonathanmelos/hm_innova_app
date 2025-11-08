import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum MediaKind { selfie, obra }

class MediaService {
  final ImagePicker _picker = ImagePicker();

  Future<Directory> _ensureDir(String sub) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, sub));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> takeSelfie({String prefix = 'start'}) async {
    // Cámara frontal
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (photo == null) return null;

    final dir = await _ensureDir('selfies');
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savePath = p.join(dir.path, fileName);
    await File(photo.path).copy(savePath);
    return savePath;
  }

  Future<String?> takeSitePhoto({String prefix = 'start'}) async {
    // Cámara trasera
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );
    if (photo == null) return null;

    final dir = await _ensureDir('site_photos');
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savePath = p.join(dir.path, fileName);
    await File(photo.path).copy(savePath);
    return savePath;
  }
}

