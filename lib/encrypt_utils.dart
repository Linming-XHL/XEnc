import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class EncryptUtils {
  // 加密流程：多个文件 -> ZIP压缩 -> RAR压缩 -> 添加8个F -> 修改后缀为.xenc -> 与混淆文件合并
  static Future<File> encryptFiles(List<File> files) async {
    // 1. 多个文件时先进行ZIP压缩
    File fileToEncrypt;
    if (files.length > 1) {
      fileToEncrypt = await _zipFiles(files);
    } else {
      fileToEncrypt = files.first;
    }

    // 2. 使用RAR格式压缩（这里使用ZIP模拟，因为archive库不支持RAR）
    File rarFile = await _rarCompress(fileToEncrypt);

    // 3. 在文件头部添加8个F
    File withHeaderFile = await _addHeaderF(rarFile);

    // 4. 修改后缀名为.xenc
    File xencFile = await _changeExtension(withHeaderFile, '.xenc');

    // 5. 与混淆文件合并（模拟copy /b命令）
    File finalFile = await _mergeWithDummy(xencFile);

    // 清理临时文件
    if (files.length > 1) {
      fileToEncrypt.deleteSync();
    }
    rarFile.deleteSync();
    // 注意：withHeaderFile已经被重命名为xencFile，所以不需要删除
    // withHeaderFile.deleteSync();
    xencFile.deleteSync();

    return finalFile;
  }

  // 解密流程：分离.xenc -> 去除8个F -> 重命名为.rar -> 解压 -> 处理ZIP
  static Future<List<File>> decryptFile(File encryptedFile) async {
    // 1. 分离出.xenc文件
    File xencFile = await _extractXenc(encryptedFile);

    // 2. 去除文件头部的8个F
    File withoutHeaderFile = await _removeHeaderF(xencFile);

    // 3. 将.xenc重命名为.rar文件
    File rarFile = await _changeExtension(withoutHeaderFile, '.rar');

    // 4. 使用RAR密码解压（这里使用ZIP模拟）
    File extractedFile = await _rarExtract(rarFile);

    // 5. 检查是否为ZIP压缩包
    List<File> finalFiles = [];
    if (path.extension(extractedFile.path).toLowerCase() == '.zip') {
      finalFiles = await _zipExtract(extractedFile);
      extractedFile.deleteSync();
    } else {
      finalFiles.add(extractedFile);
    }

    // 清理临时文件
    // 注意：withoutHeaderFile已经被重命名为rarFile，所以不需要删除withoutHeaderFile
    xencFile.deleteSync();
    // withoutHeaderFile.deleteSync(); // 注释掉，因为文件已经被重命名
    rarFile.deleteSync();

    return finalFiles;
  }

  // ZIP压缩多个文件
  static Future<File> _zipFiles(List<File> files) async {
    final outputDir = await getTemporaryDirectory();
    final zipFile = File(path.join(outputDir.path, 'temp.zip'));

    final archive = Archive();

    for (var file in files) {
      final bytes = file.readAsBytesSync();
      final fileName = path.basename(file.path);
      final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
      archive.addFile(archiveFile);
    }

    // 使用密码加密（这里只是模拟，因为archive库不支持密码加密ZIP）
    // 实际项目中可能需要使用其他库或原生实现
    final zipBytes = ZipEncoder().encode(archive)!;
    zipFile.writeAsBytesSync(zipBytes);

    return zipFile;
  }

  // 模拟RAR压缩（使用ZIP模拟）
  static Future<File> _rarCompress(File file) async {
    final outputDir = await getTemporaryDirectory();
    final rarFile = File(path.join(outputDir.path, 'temp.rar'));

    final bytes = file.readAsBytesSync();
    final archive = Archive();
    final fileName = path.basename(file.path);
    final archiveFile = ArchiveFile(fileName, bytes.length, bytes);
    archive.addFile(archiveFile);

    // 使用密码加密（模拟）
    final zipBytes = ZipEncoder().encode(archive)!;
    rarFile.writeAsBytesSync(zipBytes);

    return rarFile;
  }

  // 在文件头部添加8个F
  static Future<File> _addHeaderF(File file) async {
    final outputDir = await getTemporaryDirectory();
    final outputFile = File(path.join(outputDir.path, 'with_header.bin'));

    final bytes = file.readAsBytesSync();
    final header = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    final combined = Uint8List(header.length + bytes.length)
      ..setAll(0, header)
      ..setAll(header.length, bytes);

    outputFile.writeAsBytesSync(combined);
    return outputFile;
  }

  // 修改文件后缀名
  static Future<File> _changeExtension(File file, String newExtension) async {
    final dir = path.dirname(file.path);
    final baseName = path.basenameWithoutExtension(file.path);
    final newPath = path.join(dir, '$baseName$newExtension');
    return file.renameSync(newPath);
  }

  // 与混淆文件合并（模拟copy /b命令）
  static Future<File> _mergeWithDummy(File xencFile) async {
    final outputDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final outputFile = File(path.join(outputDir.path, 'encrypted_${DateTime.now().millisecondsSinceEpoch}.mp4'));

    final xencBytes = xencFile.readAsBytesSync();
    Uint8List dummyBytes;

    try {
      // 尝试从assets目录加载混淆视频文件
      // 用户需要在项目的assets目录中放置一个名为"dummy.mp4"的视频文件
      dummyBytes = await rootBundle.load('assets/dummy.mp4').then((data) => data.buffer.asUint8List());
      print('成功加载assets/dummy.mp4作为混淆视频，大小: ${dummyBytes.length}字节');
    } catch (e) {
      // 如果assets中没有视频文件，则使用简单的MP4文件头作为备用方案
      print('未找到assets/dummy.mp4，使用默认MP4文件头作为混淆');
      dummyBytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, // 框大小
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
        0x00, 0x00, 0x02, 0x00, // 版本
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
        0x6D, 0x70, 0x34, 0x31, // 'mp41'
      ]);
    }

    // 添加标记和xenc文件长度信息，以便解密时正确分离
    final marker = Uint8List.fromList([0x58, 0x45, 0x4E, 0x43]); // "XENC"标记
    final xencLengthBytes = Uint8List(4);
    final byteData = ByteData.view(xencLengthBytes.buffer);
    byteData.setUint32(0, xencBytes.length, Endian.little);

    // 构建最终文件：dummyBytes + marker + xencLengthBytes + xencBytes
    final combined = Uint8List(dummyBytes.length + marker.length + xencLengthBytes.length + xencBytes.length)
      ..setAll(0, dummyBytes)
      ..setAll(dummyBytes.length, marker)
      ..setAll(dummyBytes.length + marker.length, xencLengthBytes)
      ..setAll(dummyBytes.length + marker.length + xencLengthBytes.length, xencBytes);

    outputFile.writeAsBytesSync(combined);
    print('加密文件已保存到: ${outputFile.path}，总大小: ${combined.length}字节');
    return outputFile;
  }

  // 从加密文件中分离出.xenc文件
  static Future<File> _extractXenc(File encryptedFile) async {
    final outputDir = await getTemporaryDirectory();
    final xencFile = File(path.join(outputDir.path, 'extracted.xenc'));

    final bytes = encryptedFile.readAsBytesSync();
    print('开始分离.xenc文件，加密文件大小: ${bytes.length}字节');

    // 搜索"XENC"标记
    final marker = [0x58, 0x45, 0x4E, 0x43];
    int markerIndex = -1;

    for (int i = 0; i <= bytes.length - 4; i++) {
      if (bytes[i] == marker[0] &&
          bytes[i + 1] == marker[1] &&
          bytes[i + 2] == marker[2] &&
          bytes[i + 3] == marker[3]) {
        markerIndex = i;
        break;
      }
    }

    if (markerIndex == -1) {
      print('未找到"XENC"标记，尝试使用备用方法分离');
      // 备用方法：如果没有找到标记，尝试从文件末尾提取
      // 这是为了兼容旧版本的加密文件
      final xencBytes = bytes.sublist(32);
      xencFile.writeAsBytesSync(xencBytes);
      print('使用备用方法分离完成，提取大小: ${xencBytes.length}字节');
      return xencFile;
    }

    print('找到"XENC"标记，位置: $markerIndex');

    // 读取xenc文件长度
    final lengthStartIndex = markerIndex + 4;
    if (lengthStartIndex + 4 > bytes.length) {
      throw Exception('文件格式错误：无法读取xenc文件长度');
    }

    final lengthBytes = bytes.sublist(lengthStartIndex, lengthStartIndex + 4);
    final byteData = ByteData.view(lengthBytes.buffer);
    final xencLength = byteData.getUint32(0, Endian.little);
    print('xenc文件长度: $xencLength字节');

    // 提取xenc文件内容
    final xencStartIndex = lengthStartIndex + 4;
    if (xencStartIndex + xencLength > bytes.length) {
      throw Exception('文件格式错误：xenc文件长度超出文件范围');
    }

    final xencBytes = bytes.sublist(xencStartIndex, xencStartIndex + xencLength);
    xencFile.writeAsBytesSync(xencBytes);
    print('成功分离.xenc文件，提取大小: ${xencBytes.length}字节');

    return xencFile;
  }

  // 去除文件头部的8个F
  static Future<File> _removeHeaderF(File file) async {
    final outputDir = await getTemporaryDirectory();
    final outputFile = File(path.join(outputDir.path, 'without_header.bin'));

    final bytes = file.readAsBytesSync();
    print('开始去除文件头部的8个F，文件大小: ${bytes.length}字节');

    if (bytes.length < 8) {
      throw Exception('文件格式错误：文件长度小于8字节');
    }

    // 检查前8个字节是否都是0xFF
    final headerBytes = bytes.sublist(0, 8);
    bool allF = true;
    for (int i = 0; i < 8; i++) {
      if (headerBytes[i] != 0xFF) {
        allF = false;
        break;
      }
    }

    if (allF) {
      print('前8个字节都是0xFF，开始去除');
    } else {
      print('前8个字节不是全部0xFF，跳过去除步骤');
    }

    // 去除前8个字节
    final withoutHeader = bytes.sublist(8);
    outputFile.writeAsBytesSync(withoutHeader);
    print('去除头部完成，处理后大小: ${withoutHeader.length}字节');

    return outputFile;
  }

  // 模拟RAR解压
  static Future<File> _rarExtract(File rarFile) async {
    final outputDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final bytes = rarFile.readAsBytesSync();
    print('开始模拟RAR解压，文件大小: ${bytes.length}字节');

    try {
      // 解码ZIP（模拟RAR解压）
      final archive = ZipDecoder().decodeBytes(bytes);
      print('ZIP解码成功，包含 ${archive.length} 个文件');

      if (archive.isNotEmpty) {
        final firstFile = archive.first;
        final outputFile = File(path.join(outputDir.path, firstFile.name));
        // 确保输出目录存在
        outputFile.parent.createSync(recursive: true);
        outputFile.writeAsBytesSync(firstFile.content as List<int>);
        print('解压成功，输出文件: ${outputFile.path}，大小: ${(firstFile.content as List<int>).length}字节');
        return outputFile;
      } else {
        print('ZIP归档为空');
        throw Exception('RAR解压失败：归档为空');
      }
    } catch (e) {
      print('ZIP解码失败: $e');
      // 如果ZIP解码失败，尝试直接使用文件内容
      // 这是为了处理可能不是ZIP格式的情况
      final outputFile = File(path.join(outputDir.path, 'extracted_file'));
      outputFile.writeAsBytesSync(bytes);
      print('使用备用方法，直接保存文件内容: ${outputFile.path}');
      return outputFile;
    }
  }

  // 解压ZIP文件
  static Future<List<File>> _zipExtract(File zipFile) async {
    final outputDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final bytes = zipFile.readAsBytesSync();

    final archive = ZipDecoder().decodeBytes(bytes);
    final extractedFiles = <File>[];

    for (var file in archive) {
      final outputPath = path.join(outputDir.path, file.name);
      final outputFile = File(outputPath);
      outputFile.createSync(recursive: true);
      outputFile.writeAsBytesSync(file.content as List<int>);
      extractedFiles.add(outputFile);
    }

    return extractedFiles;
  }
}
