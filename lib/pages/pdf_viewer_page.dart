import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:result_wave/utils/constants.dart';

class PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfViewerPage({Key? key, required this.filePath, required this.title})
    : super(key: key);

  @override
  _PdfViewerPageState createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isLoading = true;
  String? _errorMessage;
  PDFViewController? _pdfViewController;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    print(
      '\n================== DEBUG: PDF Viewer Page Initialized ==================',
    );
    print('  Title: ${widget.title}');
    print('  File Path: ${widget.filePath}');
    _copyAssetToTempFile();
  }

  Future<void> _copyAssetToTempFile() async {
    try {
      print('  📁 Copying asset to temporary file...');

      // Get the asset data
      final byteData = await rootBundle.load(widget.filePath);
      final bytes = byteData.buffer.asUint8List();
      print('  ✅ Asset loaded, size: ${bytes.length} bytes');

      // Create a temporary directory
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.filePath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');

      // Write the bytes to the temporary file
      await tempFile.writeAsBytes(bytes);
      _tempFilePath = tempFile.path;

      print('  ✅ Temporary file created at: $_tempFilePath');
      print('  ✅ File size: ${await tempFile.length()} bytes');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('  ❌ Error copying asset: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PDF: $e';
      });
    }
  }

  @override
  void dispose() {
    // Clean up temporary file
    if (_tempFilePath != null) {
      final tempFile = File(_tempFilePath!);
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
        print('  🗑️ Temporary file deleted: $_tempFilePath');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_errorMessage == null && _tempFilePath != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _totalPages > 0
                    ? '${_currentPage + 1} / $_totalPages'
                    : 'Loading...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage == null && _tempFilePath != null)
            PDFView(
              filePath: _tempFilePath!,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: true,
              pageFling: true,
              onRender: (pages) {
                print('  📄 onRender called: pages = $pages');
                setState(() {
                  _totalPages = pages ?? 0;
                });
                print(
                  '  ✅ PDF Rendered successfully! Total pages: $_totalPages',
                );
              },
              onViewCreated: (PDFViewController vc) {
                print('  🔧 onViewCreated called');
                _pdfViewController = vc;
                print('  ✅ PDF View Controller created successfully');
              },
              onPageChanged: (page, total) {
                print('  📖 onPageChanged: page = $page, total = $total');
                setState(() {
                  _currentPage = page ?? 0;
                  _totalPages = total ?? 0;
                });
              },
              onError: (error) {
                print('  ❌ onError called: $error');
                setState(() {
                  _errorMessage = error.toString();
                });
              },
            )
          else if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Load PDF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage ?? 'Unknown error occurred',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),

          if (_isLoading && _errorMessage == null)
            Container(
              color: isDark
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading PDF...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _errorMessage == null && _tempFilePath != null
          ? _buildBottomBar(isDark)
          : null,
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: _currentPage > 0 && !_isLoading
                ? () {
                    print(
                      '  ⬅️ Previous page button pressed, going to page: ${_currentPage - 1}',
                    );
                    _pdfViewController?.setPage(_currentPage);
                  }
                : null,
            icon: const Icon(Icons.chevron_left, size: 32),
            color: _currentPage > 0 && !_isLoading
                ? AppColors.primaryBlue
                : Colors.grey,
          ),

          Expanded(
            child: _totalPages > 0
                ? Slider(
                    value: _currentPage.toDouble(),
                    min: 0,
                    max: (_totalPages - 1).toDouble(),
                    onChanged: !_isLoading
                        ? (value) {
                            print(
                              '  🎚️ Slider moved to page: ${value.toInt() + 1}',
                            );
                            _pdfViewController?.setPage(value.toInt());
                          }
                        : null,
                    activeColor: AppColors.primaryBlue,
                    inactiveColor: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade300,
                  )
                : const SizedBox(),
          ),

          IconButton(
            onPressed: _currentPage < _totalPages - 1 && !_isLoading
                ? () {
                    print(
                      '  ➡️ Next page button pressed, going to page: ${_currentPage + 2}',
                    );
                    _pdfViewController?.setPage(_currentPage + 2);
                  }
                : null,
            icon: const Icon(Icons.chevron_right, size: 32),
            color: _currentPage < _totalPages - 1 && !_isLoading
                ? AppColors.primaryBlue
                : Colors.grey,
          ),
        ],
      ),
    );
  }
}
