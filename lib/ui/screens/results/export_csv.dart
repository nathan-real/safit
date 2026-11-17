import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/results/csv_export.dart';
import '../../../models/test_result.dart';
import '../../../services/app_services.dart';

/// Crée le CSV d'un test et ouvre le menu de partage d'Android
/// (mail, Drive, WhatsApp, enregistrer dans les fichiers…).
Future<void> exportResultCsv(BuildContext context, TestResult result) async {
  final services = AppServices.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final recording = await services.results.getRecording(result.id);
    final csv = buildTestCsv(
      result,
      recording: recording,
      athlete: services.account.profile.value?.fullName,
    );
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${csvFileName(result)}');
    // BOM UTF-8 : Excel affiche alors correctement les accents.
    await file.writeAsString('﻿$csv');
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'SAFiT · ${result.protocol.title}',
    ));
  } on Exception catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export impossible : $e')));
  }
}
