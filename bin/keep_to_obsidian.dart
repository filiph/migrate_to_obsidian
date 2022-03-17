import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:simplenote_to_obsidian/ascii_name.dart';
import 'package:simplenote_to_obsidian/zettel_prefix.dart';

int main(List<String> arguments) {
  if (arguments.length != 1) {
    print("Please provide the directory you wish to copy. "
        "It needs to contain JSON files (Google Takeout export directory).");
    return 2;
  }

  var dirname = arguments.single;
  var inputDirectory = Directory(dirname);

  var destinationDirname = p.join(dirname, 'converted');
  var destinationDirectory = Directory(destinationDirname);
  destinationDirectory.createSync();
  print('- created ${destinationDirectory.path}');
  var resourcesDirectory = Directory(p.join(destinationDirname, 'images'));
  resourcesDirectory.createSync();

  for (final file in inputDirectory.listSync(followLinks: false)) {
    if (file is! File) {
      print('- skipping non-file ${file.path}');
      continue;
    }

    if (p.extension(file.path) != '.json') {
      // print('- skipping ${file.path}');
      continue;
    }

    var contents = file.readAsStringSync();

    var map = json.decode(contents) as Map<String, dynamic>;

    var note = Note.fromJson(map);

    if (note.isTrashed || note.isArchived) {
      continue;
    }

    // print('${note.textContent!}\n'
    //     '${note.created.toIso8601String()}\n'
    //     'tags: ${note.tags}');

    // Copy images and other resources.
    for (final filePath in note.attachments) {
      print('copying $filePath');
      var imageSource = File(p.absolute(p.join(dirname, filePath)));
      imageSource.copySync(p.join(resourcesDirectory.path, filePath));
    }

    var asciiName = convertToAsciiName(note.title ??
        note.textContent?.split(_whitespace).take(10).join(' ') ??
        'No Name');

    var zettelPrefix = createZettelPrefix(note.created);

    var outputPath = p.join(destinationDirname, '$zettelPrefix $asciiName.md');
    print(outputPath);

    var buf = StringBuffer();
    buf.writeln('---');
    if (note.title != null) {
      buf.writeln('title: "${note.title!.replaceAll('"', '')}"');
    }
    buf.writeln('updated: ${note.updated.toIso8601String()}');
    buf.writeln('created: ${note.created.toIso8601String()}');

    buf.writeln('tags:');
    for (final tag in note.tags) {
      buf.writeln('  - ${tag.toLowerCase()}');
    }
    // Add an additional tag that clearly shows where this note came from.
    buf.writeln('  - google-keep');

    buf.writeln('---');
    buf.writeln('');

    if (note.textContent != null) {
      buf.writeln(note.textContent!);
    }

    if (note.attachments.isNotEmpty) {
      buf.writeln('');
      buf.writeln('---');
      buf.writeln('');

      for (final filePath in note.attachments) {
        buf.writeln('![$filePath](images/$filePath)');
      }
    }

    var outputFile = File(outputPath);

    try {
      outputFile.writeAsStringSync(buf.toString());
      outputFile.setLastModifiedSync(note.updated);
    } on IOException {
      print('Error writing file: $outputPath');
    }
  }

  return 0;
}

final _whitespace = RegExp(r'\s');

class Note {
  static final _jpegExtension = RegExp(r'\.jpeg$');
  final String? textContent;
  final String? title;
  final bool isTrashed;
  final bool isArchived;
  final DateTime created;
  final DateTime updated;
  final List<String> tags;

  final List<String> attachments;

  factory Note.fromJson(Map<String, dynamic> rawNote) {
    var textContent = rawNote["textContent"] as String?;
    var explicitTitle = rawNote["title"]! as String;
    String? title;
    if (explicitTitle.isNotEmpty) {
      title = explicitTitle;
    }
    // Ignoring other types of content, such as listContent.
    var isTrashed = rawNote['isTrashed']! as bool;
    var isArchived = rawNote['isArchived']! as bool;

    var created = rawNote["createdTimestampUsec"]! as int;
    var createdDate = DateTime.fromMicrosecondsSinceEpoch(created);
    var updated = rawNote["userEditedTimestampUsec"]! as int;
    var updatedDate = DateTime.fromMicrosecondsSinceEpoch(updated);

    var tags = <String>[];
    if (rawNote.containsKey("labels")) {
      var labels = (rawNote["labels"] as List<dynamic>);
      tags = labels.map((e) => e['name'] as String).toList().cast();
    }

    var attachments = <String>[];
    if (rawNote.containsKey("attachments")) {
      var attachmentsMap = (rawNote["attachments"] as List<dynamic>);

      attachments = attachmentsMap
          .map((e) => e['filePath'] as String)
          // For some reason, JPG files are referred to as '.jpeg' in the JSON,
          // but are actually included as '.jpg' files.
          .map((e) => e.replaceFirst(_jpegExtension, '.jpg'))
          .toList()
          .cast();
    }

    return Note._(textContent, title, createdDate, updatedDate, tags, isTrashed,
        isArchived, attachments);
  }

  Note._(this.textContent, this.title, this.created, this.updated, this.tags,
      this.isTrashed, this.isArchived, this.attachments);
}
