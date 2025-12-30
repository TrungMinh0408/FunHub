import 'dart:io';

class EditableMedia {
  final File? file;        // nếu là file mới chọn
  final String? url;       // nếu là media cũ đã upload
  final String type;       // "image" | "video"
  final String publicId;   // public_id từ Cloudinary (media cũ)

  EditableMedia({
    this.file,
    this.url,
    required this.type,
    this.publicId = '',
  });
}
