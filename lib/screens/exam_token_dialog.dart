import 'package:flutter/material.dart';

class ExamTokenDialog extends StatefulWidget {
  final String examTitle;

  const ExamTokenDialog({super.key, required this.examTitle});

  @override
  State<ExamTokenDialog> createState() => _ExamTokenDialogState();
}

class _ExamTokenDialogState extends State<ExamTokenDialog> {
  final _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.key, color: Color(0xFF1E3A8A)),
          SizedBox(width: 8),
          Text('Masukkan Token'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ujian: ${widget.examTitle}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Minta 6 digit token ujian kepada pengawas di ruangan Anda.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tokenController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'TOKEN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Token tidak boleh kosong';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _tokenController.text.trim().toUpperCase());
            }
          },
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}
