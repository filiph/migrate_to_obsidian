import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:simplenote_to_obsidian/ascii_name.dart';
import 'package:simplenote_to_obsidian/zettel_prefix.dart';
import 'package:yaml/yaml.dart';

Future<int> main(List<String> arguments) async {
  if (arguments.length != 1) {
    print("Please provide the directory you wish to copy. "
        "It needs to contain Markdown files with front matter.");
    return 2;
  }

  var dirname = arguments.single;
  var inputDirectory = Directory(dirname);

  var destinationDirname = p.join(dirname, 'filtered');
  var destinationDirectory = Directory(destinationDirname);
  await destinationDirectory.create();
  print('- created ${destinationDirectory.path}');
  var resourcesDirectory = Directory(p.join(destinationDirname, 'images'));
  await resourcesDirectory.create();

  /// Covers newline characters from Mac, Unix, Windows, and old Macs.
  final newline = RegExp(r'(\r\n|\r|\n)');

  /// Parses image tags in Markdown.
  final resourceLink = RegExp(r'\[(.+?)\]\((\.\.\/_resources/(.+?))\)');

  await for (final file in inputDirectory.list(followLinks: false)) {
    if (file is! File) {
      print('- skipping non-file ${file.path}');
      continue;
    }

    if (p.extension(file.path) != '.md') {
      print('- skipping ${file.path}');
      continue;
    }

    var contents = await file.readAsString();

    var lines = contents.split(newline);

    if (lines.first != '---') {
      print("- file ${file.path} doesn't start with front matter");
      continue;
    }

    var frontMatterLines =
        lines.skip(1).takeWhile((line) => line != '---').toList();
    var doc = loadYaml(frontMatterLines.join('\n'));

    /// Lines of the file, but without the front matter.
    var contentLines =
        lines.skip(1).skipWhile((line) => line != '---').skip(1).toList();

    var title = doc['title'] as String;
    var author = doc['author'] as String?;
    var created = DateTime.parse(doc['created'] as String);
    var updated = DateTime.parse(doc['updated'] as String);
    var source = doc['source'] as String?;

    var tagsYaml = doc['tags'] as YamlList?;
    List<String>? tags;
    if (tagsYaml != null) {
      tags = List<String>.from(tagsYaml.value);
    }

    if (source != null) {
      // We're filtering out Evernote notes that have a 'source',
      // which is to say, a URL. These are basically bookmarks,
      // and so they don't constitute true "notes" the way I see them
      // these days. There's also way too many of them.
    } else if (author == 'Instapaper <no-reply@instapaper.com>') {
      // Instapaper notes are also, technically, bookmarks.
    } else {
      // Source is null, therefore this is a true note.

      // Add 'evernote' tag to each note.
      if (tags == null) {
        // If there are no tags, add them.
        frontMatterLines.add('tags:');
        tags = <String>[];
      }
      frontMatterLines.add('  - evernote');
      tags.add('evernote');

      for (int i = 0; i < contentLines.length; i++) {
        var resourceCopies = <String, String>{};
        contentLines[i] =
            contentLines[i].replaceAllMapped(resourceLink, (match) {
          var destinationPath = p.join('images', match.group(3)!);
          resourceCopies[match.group(2)!] = destinationPath;
          return '[${match.group(1)!}]($destinationPath)';
        });

        // Copy images and other resources.
        for (final copy in resourceCopies.entries) {
          var imageSource = File(p.absolute(p.join(dirname, copy.key)));
          await imageSource.copy(p.join(destinationDirname, copy.value));
        }
      }

      // Create new file contents.
      var outputLines = ['---']
          .followedBy(frontMatterLines)
          .followedBy(['---'])
          .followedBy(contentLines)
          .followedBy(['']);

      // Create copy of the note.
      var filename =
          '${createZettelPrefix(created)} ${convertToAsciiName(title)}.md';
      var file = File(p.join(destinationDirname, filename));
      await file.writeAsString(outputLines.join('\n'));
      await file.setLastModified(updated);
    }
  }

  return 0;
}
