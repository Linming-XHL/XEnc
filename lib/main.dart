import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:xenc/encrypt_utils.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XEnc 文件加密工具',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'XEnc 文件加密工具'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<File> _selectedFiles = [];
  String _status = '';

  Future<void> _selectFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.paths.map((path) => File(path!)).toList();
          _status = '已选择 ${_selectedFiles.length} 个文件';
        });
      }
    } catch (e) {
      setState(() {
        _status = '选择文件失败: $e';
      });
    }
  }

  Future<void> _encryptFiles() async {
    if (_selectedFiles.isEmpty) {
      setState(() {
        _status = '请先选择文件';
      });
      return;
    }

    setState(() {
      _status = '开始加密...';
    });

    try {
      File encryptedFile = await EncryptUtils.encryptFiles(_selectedFiles);
      setState(() {
        _status = '加密完成，文件已保存到: ${encryptedFile.path}';
      });
    } catch (e) {
      setState(() {
        _status = '加密失败: $e';
      });
    }
  }

  Future<void> _decryptFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['mp4'],
        withData: false,
      );

      if (result != null) {
        setState(() {
          _status = '开始解密...';
        });

        File encryptedFile = File(result.paths.first!);
        List<File> decryptedFiles = await EncryptUtils.decryptFile(encryptedFile);

        setState(() {
          _status = '解密完成，已提取 ${decryptedFiles.length} 个文件';
        });

        // 显示解密后的文件路径
        for (var file in decryptedFiles) {
          print('解密文件: ${file.path}');
        }
      }
    } catch (e) {
      setState(() {
        _status = '解密失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _selectFiles,
                    child: const Text('选择文件'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _encryptFiles,
                    child: const Text('加密文件'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _decryptFile,
                    child: const Text('解密文件'),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (_selectedFiles.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedFiles.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_selectedFiles[index].path.split('\\').last),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 底部版本号和作者主页
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '版本: 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('https://lmxhl.top');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      print('无法打开链接: https://lmxhl.top');
                    }
                  },
                  child: Text(
                    '作者主页',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
