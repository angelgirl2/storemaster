import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'shamsi_date_utils.dart';

String _normalizeDigits(String value) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var result = value;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(fa[i], '$i');
    result = result.replaceAll(ar[i], '$i');
  }
  return result;
}

/// Persian/Jalali date picker used everywhere user enters or selects a date.
/// Storage continues to use epoch milliseconds; only the user-facing calendar
/// is Jalali/Persian.
Future<DateTime?> showPersianDatePicker({
  required BuildContext context,
  DateTime? initialDate,
}) async {
  final initial = initialDate ?? DateTime.now();
  final initialJalali = Jalali.fromDateTime(initial);

  final yearController = TextEditingController(
    text: initialJalali.year.toString(),
  );
  final monthController = TextEditingController(
    text: initialJalali.month.toString(),
  );
  final dayController = TextEditingController(
    text: initialJalali.day.toString(),
  );

  try {
    return await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        String? error;

        return StatefulBuilder(
          builder: (context, setState) {
            DateTime? parseDate() {
              final year = int.tryParse(_normalizeDigits(yearController.text.trim()));
              final month = int.tryParse(_normalizeDigits(monthController.text.trim()));
              final day = int.tryParse(_normalizeDigits(dayController.text.trim()));

              if (year == null || month == null || day == null) {
                setState(() => error = 'سال، ماه و روز را صحیح وارد کنید.');
                return null;
              }
              if (year < 1300 || year > 1600) {
                setState(() => error = 'سال شمسی باید بین ۱۳۰۰ و ۱۶۰۰ باشد.');
                return null;
              }
              if (month < 1 || month > 12) {
                setState(() => error = 'ماه باید بین ۱ تا ۱۲ باشد.');
                return null;
              }
              if (day < 1 || day > 31) {
                setState(() => error = 'روز باید بین ۱ تا ۳۱ باشد.');
                return null;
              }

              try {
                final date = Jalali(year, month, day).toDateTime();
                final check = Jalali.fromDateTime(date);
                if (check.year != year || check.month != month || check.day != day) {
                  setState(() => error = 'تاریخ شمسی واردشده معتبر نیست.');
                  return null;
                }
                return DateTime(
                  date.year,
                  date.month,
                  date.day,
                  initial.hour,
                  initial.minute,
                  initial.second,
                  initial.millisecond,
                );
              } catch (_) {
                setState(() => error = 'تاریخ شمسی واردشده معتبر نیست.');
                return null;
              }
            }

            return AlertDialog(
              title: const Text('انتخاب تاریخ شمسی'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'تاریخ را به صورت سال / ماه / روز وارد کنید.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'سال شمسی',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: monthController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'ماه',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: dayController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'روز',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'نمونه: ${faDate(initial)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = parseDate();
                    if (parsed != null) {
                      Navigator.pop(dialogContext, parsed);
                    }
                  },
                  child: const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
  }
}

Future<DateTime?> showPersianDateTimePicker({
  required BuildContext context,
  DateTime? initialDate,
}) async {
  final date = await showPersianDatePicker(
    context: context,
    initialDate: initialDate,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
