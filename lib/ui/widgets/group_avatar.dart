import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';

/// 모임 동그라미: 사진이 있으면 사진, 없으면 모임 색 위에 이름 첫 글자.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.group, this.size = 44});

  final Group group;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = logoBytes(group.logo);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Color(group.color), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: bytes != null
          ? Image.memory(bytes, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
          : Text(
              group.initial,
              style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w700),
            ),
    );
  }
}

Uint8List? logoBytes(String? logo) {
  if (logo == null || logo.isEmpty) return null;
  try {
    return base64Decode(logo);
  } catch (_) {
    return null;
  }
}

/// 사진첩에서 모임 사진 고르기. 서버에 바로 넣을 수 있게 작게(256px) 줄여요.
/// 고르지 않으면 null.
Future<String?> pickGroupLogo() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 256,
    maxHeight: 256,
    imageQuality: 80,
  );
  if (file == null) return null;
  return base64Encode(await file.readAsBytes());
}

/// 모임 색 고르는 줄.
class ColorDots extends StatelessWidget {
  const ColorDots({super.key, required this.value, required this.onPick});

  final int value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        for (final c in Group.palette)
          GestureDetector(
            onTap: () => onPick(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == value ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                  width: 3,
                ),
              ),
              child: c == value ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
            ),
          ),
      ]);
}
