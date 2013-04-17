#!/usr/bin/env dart --checked

import 'dart:async';
import 'dart:io';
import 'dart:json' as json;
import 'package:pathos/path.dart' as pathos;
import 'package:yaml/yaml.dart' as yaml;

void main() {
  final options = new Options();
  print("Hello, World!");
  print(pathos.current);

  if(options.arguments.isEmpty) {
    print("give me a file!");
    exit(1);
  }

  var jsonPath = options.arguments.first;

  print('looking at $jsonPath');

  if(pathos.isRelative(jsonPath)) {
    jsonPath = pathos.absolute(jsonPath);
  }

  assert(pathos.isAbsolute(jsonPath));

  print(jsonPath);

  final jsonFile = new File(jsonPath);
  assert(jsonFile.existsSync());

  jsonFile.readAsString()
    .then(json.parse)
    .then(_processJson);
}

void _processJson(Map<String, String> map) {

  Future.forEach(map.keys, (String pkgName) {
    return _validatePackage(pkgName, map[pkgName]);
  });
}

Future _validatePackage(String name, String path) {
  print("$name\tat\t$path");

  final pubspecPath = pathos.join(path, 'pubspec.yaml');

  final pubspecFile = new File(pubspecPath);

  return pubspecFile.exists()
      .then((bool exists) {
        if(!exists) {
          throw new Exception('$name: pubspec does not exist at '
              '$pubspecPath');
        }
        print('we have a pubspec: $pubspecPath');

        return pubspecFile.readAsString();
      })
      .then((String pubspecYaml) {
        final pubspec = yaml.loadYaml(pubspecYaml);

        if(pubspec['name'] != name) {
          throw new Exception('$name: pubspec file at $pubspecPath has name '
              '${pubspec["name"]} which is not expected');
        }

      });

  // dir exists

  // pubspec.yaml exists

  // first line parses to something like 'name:[space?]expectedName
}
