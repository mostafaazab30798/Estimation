import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    print('Assets directory not found');
    return;
  }

  print('Starting compression of theme images...');
  
  final themeDirs = assetsDir.listSync().whereType<Directory>().where((d) => d.path.contains('theme_'));
  
  int totalSaved = 0;
  int processedCount = 0;

  for (final dir in themeDirs) {
    print('Processing ${dir.path}...');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.png'));
    
    for (final file in files) {
      final originalSize = file.lengthSync();
      // Skip if already small (< 150KB)
      if (originalSize < 150 * 1024) continue;
      
      final imageBytes = file.readAsBytesSync();
      final image = img.decodeImage(imageBytes);
      
      if (image != null) {
        // Resize to a maximum width of 350px (plenty for high-res mobile screens)
        final resized = img.copyResize(image, width: 350);
        
        // Encode back to PNG
        final compressedBytes = img.encodePng(resized, level: 6);
        
        final newSize = compressedBytes.length;
        
        if (newSize < originalSize) {
          file.writeAsBytesSync(compressedBytes);
          final saved = originalSize - newSize;
          totalSaved += saved;
          processedCount++;
          print('Compressed ${file.path.split(Platform.pathSeparator).last}: ${(originalSize/1024).toStringAsFixed(1)}KB -> ${(newSize/1024).toStringAsFixed(1)}KB (Saved ${(saved/1024).toStringAsFixed(1)}KB)');
        }
      }
    }
  }
  
  print('Done! Compressed $processedCount files.');
  print('Total space saved: ${(totalSaved / 1024 / 1024).toStringAsFixed(2)} MB');
}
