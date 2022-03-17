import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:simplenote_to_obsidian/ascii_name.dart';
import 'package:simplenote_to_obsidian/zettel_prefix.dart';

int main(List<String> arguments) {
  if (arguments.length != 1) {
    print("Please provide the JSON from SimpleNote's export");
    return 2;
  }

  var filename = arguments.single;
  var inputFile = File(filename);
  String contents;

  try {
    contents = inputFile.readAsStringSync();
  } on IOException {
    print("Could not read from $filename");
    return 1;
  }

  var map = json.decode(contents);

  var notesJson =
      (map["activeNotes"] as List<dynamic>).cast<Map<String, dynamic>>();

  List<Note> notes =
      notesJson.map(Note.fromJson).cast<Note>().toList(growable: false);

  var outputDir = inputFile.parent;

  for (final note in notes) {
    var asciiName = convertToAsciiName(note.title);

    var zettelPrefix = createZettelPrefix(note.created);

    var outputPath = p.join(outputDir.path, '$zettelPrefix $asciiName.md');
    print(outputPath);

    var buf = StringBuffer();
    buf.writeln('---');
    buf.writeln('title: "${note.title.replaceAll('"', '')}"');
    buf.writeln('updated: ${note.updated.toIso8601String()}');
    buf.writeln('created: ${note.created.toIso8601String()}');

    buf.writeln('tags:');
    for (final tag in note.tags) {
      buf.writeln('  - $tag');
    }
    // Add an additional tag that clearly shows where this note came from.
    buf.writeln('  - simplenote');

    buf.writeln('---');
    buf.writeln('');

    buf.writeln(note.content);

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

class Note {
  final String content;
  final String title;
  final DateTime created;
  final DateTime updated;
  final List<String> tags;

  Note._(this.content, this.title, this.created, this.updated, this.tags);

  factory Note.fromJson(Map<String, dynamic> rawNote) {
    var content = rawNote["content"]! as String;
    var title = content.split('\r\n').first;

    var created = rawNote["creationDate"]! as String;
    var createdDate = DateTime.parse(created);
    var updated = rawNote["lastModified"]! as String;
    var updatedDate = DateTime.parse(updated);

    var tags = <String>[];

    if (rawNote.containsKey("tags")) {
      tags = (rawNote["tags"] as List<dynamic>).cast();
    }

    return Note._(content, title, createdDate, updatedDate, tags);
  }
}
