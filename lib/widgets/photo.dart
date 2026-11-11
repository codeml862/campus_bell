import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../services/services.dart';
import 'common.dart';

/// Profile photos, stored small (about 20–40 KB JPEG) in Firestore
/// `photos/{uid}` so no paid file storage is needed.
class PhotoService {
  static final _col = db.collection('photos');
  static final _cache = <String, Future<Uint8List?>>{};
  static final changed = ValueNotifier<int>(0);

  /// The photo of [uid], or null (cached for this app run).
  static Future<Uint8List?> of(String uid) => _cache.putIfAbsent(uid, () async {
    try {
      final d = await _col.doc(uid).get();
      final b64 = d.data()?['b64'];
      return b64 is String && b64.isNotEmpty ? base64Decode(b64) : null;
    } catch (_) {
      return null;
    }
  });

  /// Lets the user pick / take a photo and saves it as their profile photo.
  static Future<bool> pickAndSave(BuildContext context, String uid) async {
    final source = await showCupertinoModalPopup<Object>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: const Text('Profile photo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(c, ImageSource.camera),
            child: const Text('Take photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(c, ImageSource.gallery),
            child: const Text('Choose from gallery'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, 'remove'),
            child: const Text('Remove photo'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (source == null) return false;
    try {
      if (source == 'remove') {
        await _col.doc(uid).delete();
        _set(uid, null);
        if (context.mounted) showSnack(context, 'Photo removed.');
        return true;
      }
      final file = await ImagePicker().pickImage(
        source: source as ImageSource,
        maxWidth: 360,
        maxHeight: 360,
        imageQuality: 72,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return false;
      final bytes = await file.readAsBytes();
      if (bytes.length > 220 * 1024) {
        if (context.mounted) {
          showSnack(context, 'That photo is too large. Try another one.');
        }
        return false;
      }
      await _col.doc(uid).set({
        'b64': base64Encode(bytes),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _set(uid, bytes);
      if (context.mounted) showSnack(context, 'Photo updated.');
      return true;
    } catch (e) {
      if (context.mounted) showSnack(context, 'Could not update photo: $e');
      return false;
    }
  }

  static void _set(String uid, Uint8List? bytes) {
    _cache[uid] = Future.value(bytes);
    changed.value++;
  }
}

/// Circle with the person's photo, or [fallback] (initials) if none.
class UserPhoto extends StatelessWidget {
  final String uid;
  final double size;
  final Widget fallback;
  const UserPhoto({
    super.key,
    required this.uid,
    required this.size,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: PhotoService.changed,
    builder: (_, _, _) => FutureBuilder<Uint8List?>(
      future: PhotoService.of(uid),
      builder: (_, snap) {
        final bytes = snap.data;
        if (bytes == null) return fallback;
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      },
    ),
  );
}

/// Own photo with a small camera badge; tap to change.
class EditablePhoto extends StatelessWidget {
  final String uid;
  final double size;
  final Widget fallback;
  const EditablePhoto({
    super.key,
    required this.uid,
    required this.size,
    required this.fallback,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => PhotoService.pickAndSave(context, uid),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        UserPhoto(uid: uid, size: size, fallback: fallback),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: size * .38,
            height: size * .38,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              CupertinoIcons.camera_fill,
              size: size * .19,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
