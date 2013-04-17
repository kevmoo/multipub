#!/usr/bin/env dart --checked

import 'dart:async';
import 'dart:io';
import 'dart:json' as json;
import 'package:pathos/path.dart' as pathos;
import 'package:yaml/yaml.dart' as yaml;

void main() {
  final options = new Options();

  if(options.arguments.isEmpty) {
    print("give me a file!");
    exit(1);
  }

  var jsonPath = options.arguments.first;

  if(pathos.isRelative(jsonPath)) {
    jsonPath = pathos.absolute(jsonPath);
  }

  assert(pathos.isAbsolute(jsonPath));

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


  return PackageStatus.create(path)
      .then((PackageStatus ps) {
        assert(ps.name == name);
        ps.printStatus();
      });
}

class PackageStatus extends PackageRef {
  final Map<String, PackageRef> _refs;

  PackageStatus._internal(String name, String path,
      Map<String, PackageRef> this._refs) :
        super(name, path) {
    assert(_refs != null);

  }

  void printStatus() {
    print(name);
    print('\t$path');
    print('\tPACKAGES:');
    _refs.forEach((k, v) {
      assert(k == v.name);
      print('\t\t${v.name}');
      print('\t\t\t${v.path}');
    });


    print('$name - **done**');
  }


  static Future<PackageStatus> create(String path) {

    final pubspecPath = pathos.join(path, 'pubspec.yaml');

    final pubspecFile = new File(pubspecPath);

    yaml.YamlMap pubspec;

    return pubspecFile.exists()
        .then((bool exists) {
          if(!exists) {
            throw new Exception('$name: pubspec does not exist at '
                '$pubspecPath');
          }

          return pubspecFile.readAsString();
        })
        .then((String pubspecYaml) {
          pubspec = yaml.loadYaml(pubspecYaml);

          return _getPackageDirs(path);
        })
        .then((Map<String, PackageRef> packageDirs) {
          return new PackageStatus._internal(pubspec['name'], path, packageDirs);
        });
  }
}

Future<Map<String, PackageRef>> _getPackageDirs(String mainPath) {

  Map<String, PackageRef> packageDirs = new Map<String, PackageRef>();

  final packagePath = pathos.join(mainPath, 'packages');
  final packageDir = new Directory(packagePath);
  return packageDir.exists()
      .then((bool exists) {
        assert(exists);

        return packageDir.list(followLinks: false).toList();
      })
      .then((List<FileSystemEntity> items) {
        assert(items.every((e) => e is Link));

        return Future.forEach(items, (Link link) {
          final linkName = pathos.basename(link.path);

          return link.target()
              .then((String path) {
                if(pathos.isRelative(path)) {
                  // need to fix the path relative to the main path
                  path = pathos.join(packagePath, path);
                  path = pathos.normalize(path);
                }
                assert(pathos.isAbsolute(path));
                //path = pathos.absolute(path);
                packageDirs[linkName] = new PackageRef(linkName, path);
              });
        });
      })
      .then((_) {
        return packageDirs;
      });
}

class PackageRef {
  final String name;
  final String path;

  PackageRef(this.name, this.path) {
    assert(name != null);
    assert(!name.isEmpty);
    //assert(pathos.isAbsolute(path));
    //assert(pathos.normalize(path) == path);
  }
}
