import 'dart:io';

void main() async {
  final file = File('d:\\PROJECTS\\estimation\\assets\\spade_1.png');
  final bytes = await file.readAsBytes();
  // We can just read the basic PNG headers to find width and height.
  // PNG IHDR chunk is right after the 8-byte signature.
  // Signature: 89 50 4E 47 0D 0A 1A 0A
  // IHDR length: 4 bytes (always 13)
  // IHDR type: 4 bytes (IHDR)
  // Width: 4 bytes
  // Height: 4 bytes
  if (bytes.length > 24) {
    final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    stdout.writeln('Width: $width, Height: $height, Aspect Ratio: ${width / height}');
  }
}
