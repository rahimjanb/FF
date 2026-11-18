import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'food_camera_screen.dart';

enum FoodPhotoSource { camera, gallery }

/// Why a picked photo cannot be used: [camera] — no camera (e.g. the iOS simulator); [permission] — access denied.
enum FoodPhotoProblem { unreadable, tooSmall, camera, permission }

class FoodPhotoException implements Exception {
  const FoodPhotoException(this.problem);
  final FoodPhotoProblem problem;
}

/// Returns a JPEG ready for upload, or null when the user cancelled. [label]: the photo is of a package label.
typedef FoodPhotoPicker = Future<Uint8List?> Function(BuildContext context, FoodPhotoSource source, {bool label});

/// The longer side sent for analysis: enough detail for the vision model, which scales larger images down anyway.
const foodMaxSide = 1568;

/// The shorter side below which a dish cannot be recognized (the server rejects it too).
const foodMinSide = 320;

/// Upload size cap; the server accepts up to 6 MB, a smaller photo uploads faster on mobile data.
const foodMaxBytes = 1536 * 1024;

/// Decodes the photo, applies the EXIF orientation, drops all metadata (EXIF may hold the GPS position of the
/// phone), scales the longer side down to [foodMaxSide] and encodes a JPEG of at most [foodMaxBytes]: lower quality
/// first, then a smaller size. Pure Dart: runs in a background isolate.
(Uint8List?, FoodPhotoProblem?) prepareFoodPhoto(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return (null, FoodPhotoProblem.unreadable);
  final image = img.bakeOrientation(decoded);
  if (math.min(image.width, image.height) < foodMinSide) return (null, FoodPhotoProblem.tooSmall);
  for (final side in const [foodMaxSide, 1280, 1024]) {
    final scaled = math.max(image.width, image.height) <= side
        ? image
        : image.width >= image.height
        ? img.copyResize(image, width: side, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: side, interpolation: img.Interpolation.average);
    if (math.min(scaled.width, scaled.height) < foodMinSide) return (null, FoodPhotoProblem.tooSmall);
    // Without this the encoder writes the original EXIF block (camera, time, GPS) back into the JPEG.
    scaled.exif = img.ExifData();
    for (var quality = 85; quality >= 55; quality -= 10) {
      final jpeg = img.encodeJpg(scaled, quality: quality);
      if (jpeg.length <= foodMaxBytes) return (jpeg, null);
    }
  }
  return (null, FoodPhotoProblem.unreadable);
}

/// Takes a photo with the app's own camera screen ([FoodCameraScreen], never the system camera app) or picks one
/// from the gallery, and prepares it for upload.
Future<Uint8List?> pickFoodPhoto(BuildContext context, FoodPhotoSource source, {bool label = false}) {
  if (source == FoodPhotoSource.gallery) return pickFoodPhotoFromGallery();
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => FoodCameraScreen(label: label)),
  );
}

/// The system photo picker (only the chosen photo is shared with the app), then the same preparation as a camera shot.
Future<Uint8List?> pickFoodPhotoFromGallery() async {
  final XFile? file;
  try {
    // The native picker scales and re-encodes first (HEIC from the gallery becomes JPEG), so Dart decodes less.
    file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
      requestFullMetadata: false,
    );
  } on PlatformException catch (e) {
    throw FoodPhotoException(e.code.contains('denied') ? FoodPhotoProblem.permission : FoodPhotoProblem.camera);
  }
  if (file == null) return null;
  final (jpeg, problem) = await compute(prepareFoodPhoto, await file.readAsBytes());
  if (problem != null) throw FoodPhotoException(problem);
  return jpeg;
}

String foodPhotoProblemText(AppLocalizations t, FoodPhotoProblem p) => switch (p) {
  FoodPhotoProblem.unreadable => t.foodPhotoUnreadable,
  FoodPhotoProblem.tooSmall => t.foodPhotoTooSmall,
  FoodPhotoProblem.camera => t.foodPhotoNoCamera,
  FoodPhotoProblem.permission => t.foodPhotoPermission,
};
