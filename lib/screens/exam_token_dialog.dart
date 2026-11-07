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
          Icon(Icons.key_rounded, color: Color(0xFF0F172A), size: 22),
          SizedBox(width: 8),
          Text('Masukkan Token Ujian', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Ujian: ${widget.examTitle}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Silakan minta 6 digit token ujian kepada pengawas di ruangan.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tokenController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4, color: Color(0xFF0F172A)),
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
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _tokenController.text.trim().toUpperCase());
            }
          },
          child: const Text('Mulai'),
        ),
      ],
    );
  }
}
