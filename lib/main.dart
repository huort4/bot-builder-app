import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String kWorkerUrl =
    'https://bot-builder-saas.maryoa0001.workers.dev/api/stores';

// فقط برای تست؛ بعداً از Telegram Web App گرفته می‌شود
const int kTestAdminId = 123456789;

void main() {
  runApp(const BotBuilderSaaS());
}

class BotBuilderSaaS extends StatelessWidget {
  const BotBuilderSaaS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'راه‌اندازی فروشگاه',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF1c1c1e),
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const SetupWizardScreen(),
    );
  }
}

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  final _storeNameController = TextEditingController();
  final _channelIdController = TextEditingController();
  final _cardNumberController = TextEditingController();

  String _selectedCategory = 'فایل و دیجیتال';
  bool _enableStars = true;

  @override
  void dispose() {
    _storeNameController.dispose();
    _channelIdController.dispose();
    _cardNumberController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // اعتبارسنجی هر مرحله؛ اگر خطا داشت متنش برمی‌گردد
  String? _validateStep(int step) {
    if (step == 0) {
      final name = _storeNameController.text.trim();
      if (name.isEmpty) return 'نام فروشگاه را وارد کنید.';
      if (name.length > 64) return 'نام فروشگاه حداکثر ۶۴ حرف باشد.';
    }
    if (step == 1) {
      final card = _cardNumberController.text.replaceAll(RegExp(r'[\s-]'), '');
      if (card.isNotEmpty &&
          !RegExp(r'^(\d{16}|IR\d{24})$', caseSensitive: false).hasMatch(card)) {
        return 'شماره کارت باید ۱۶ رقم یا شبا به شکل IR و ۲۴ رقم باشد.';
      }
    }
    if (step == 2) {
      final ch = _channelIdController.text.trim();
      final ok = RegExp(r'^@[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(ch) ||
          RegExp(r'^-100\d+$').hasMatch(ch);
      if (!ok) return 'آیدی کانال را به شکل @MyStore وارد کنید.';
    }
    return null;
  }

  String _errorText(int status, String body) {
    String code = '';
    try {
      code = (jsonDecode(body) as Map)['error']?.toString() ?? '';
    } catch (_) {}

    switch (code) {
      case 'invalid_store_name':
        return 'نام فروشگاه معتبر نیست.';
      case 'invalid_channel_id':
        return 'آیدی کانال معتبر نیست.';
      case 'invalid_card_number':
        return 'شماره کارت یا شبا معتبر نیست.';
      case 'invalid_admin_id':
        return 'شناسه ادمین معتبر نیست.';
      case 'channel_already_registered':
        return 'این کانال قبلاً ثبت شده است.';
      default:
        return 'خطای سرور ($status)';
    }
  }

  Future<void> _submitStore() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    String message;
    try {
      final response = await http
          .post(
            Uri.parse(kWorkerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'admin_id': kTestAdminId,
              'store_name': _storeNameController.text.trim(),
              'category': _selectedCategory,
              'card_number': _cardNumberController.text.trim(),
              'accept_stars': _enableStars,
              'channel_id': _channelIdController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        message = 'فروشگاه شما با موفقیت ساخته شد! 🎉';
      } else {
        message = _errorText(response.statusCode, response.body);
      }
    } catch (e) {
      message = 'خطا در ارتباط با سرور!';
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _showMessage(message);
  }

  void _onContinue() {
    final error = _validateStep(_currentStep);
    if (error != null) {
      _showMessage(error);
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    } else {
      _submitStore();
    }
  }

  void _onCancel() {
    if (_currentStep > 0) setState(() => _currentStep -= 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جادوگر ساخت فروشگاه 🧙‍♂️'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
        ),
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _onContinue,
          onStepCancel: _onCancel,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_currentStep == 2
                              ? 'تکمیل و ساخت فروشگاه 🚀'
                              : 'مرحله بعد'),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _isLoading ? null : details.onStepCancel,
                      child: const Text('قبلی',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            // مرحله ۱: هویت برند
            Step(
              title: const Text('هویت برند'),
              isActive: _currentStep >= 0,
              content: Column(
                children: [
                  TextField(
                    controller: _storeNameController,
                    decoration: const InputDecoration(
                        labelText: 'نام فروشگاه شما',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                        labelText: 'حوزه کاری', border: OutlineInputBorder()),
                    items: ['فایل و دیجیتال', 'پوشاک', 'خدمات', 'کانفیگ و اکانت']
                        .map((val) =>
                            DropdownMenuItem(value: val, child: Text(val)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val!),
                  ),
                ],
              ),
            ),
            // مرحله ۲: تنظیمات مالی
            Step(
              title: const Text('تنظیمات مالی'),
              isActive: _currentStep >= 1,
              content: Column(
                children: [
                  TextField(
                    controller: _cardNumberController,
                    decoration: const InputDecoration(
                        labelText: 'شماره کارت یا شبا (اختیاری)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 15),
                  SwitchListTile(
                    title: const Text('پشتیبانی از تلگرام استارز ⭐️'),
                    subtitle: const Text('دریافت آنی وجه برای فایل‌ها'),
                    value: _enableStars,
                    onChanged: (val) => setState(() => _enableStars = val),
                    activeColor: Colors.blueAccent,
                  ),
                ],
              ),
            ),
            // مرحله ۳: اتصال کانال
            Step(
              title: const Text('اتصال جادویی کانال'),
              isActive: _currentStep >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ربات را در کانال خود ادمین کنید، سپس آیدی کانال را وارد کنید:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _channelIdController,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                        labelText: 'آیدی کانال (مثلا @MyStore)',
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
