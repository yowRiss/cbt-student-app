import 'package:flutter/material.dart';
import '../core/security/cbt_security.dart';

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
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.key_rounded, color: Color(0xFF0F172A), size: 22),
          SizedBox(width: 8),
          Text('Masukkan Token Ujian', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
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
                'Silakan minta token ujian kepada guru atau pengawas di ruangan.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 6),
                        Text(
                          'Keamanan Ujian Aktif',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dilarang menahan tombol Home / membuka Google Assistant selama ujian.',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => CbtSecurity.openAssistSettings(),
                      child: const Text(
                        'Ketuk di sini jika ingin mematikan Asisten Digital HP',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _tokenController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'MASUKKAN TOKEN',
                  hintStyle: const TextStyle(fontSize: 13, letterSpacing: 1.5, color: Color(0xFF94A3B8)),
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
