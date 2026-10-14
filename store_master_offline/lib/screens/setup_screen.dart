// ============================================================================
// SetupScreen
// راه‌اندازی اولیه فروشگاه + انتخاب نوع کسب‌وکار + ورود آنلاین
// ============================================================================

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/business_profile.dart';
import '../shared_src/business_catalog.dart';
import '../viewmodels/main_viewmodel.dart';


// Online credentials can be copied from Persian UI text. Convert Persian/Arabic
// numerals to ASCII before parsing user IDs or sending PINs to the API.
String _normalizeOnlineLoginDigits(String value) {
  final output = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      output.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      output.writeCharCode(0x30 + rune - 0x0660);
    } else {
      output.writeCharCode(rune);
    }
  }
  return output.toString();
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int step = 1;

  late final TextEditingController storeNameCtrl;
  late final TextEditingController adminNameCtrl;
  late final TextEditingController adminPinCtrl;
  late final TextEditingController confirmPinCtrl;

  Set<String> selectedTypes = {'SUPERMARKET'};

  String colorTheme = 'EMERALD';
  String currency = 'تومان';
  String layoutStyle = 'GRID';
  bool layoutManuallySelected = false;
  String logoBase64 = '';
  String? errorMsg;

  String get storeName => storeNameCtrl.text.trim();

  String get adminName => adminNameCtrl.text.trim();

  String get adminPin => adminPinCtrl.text.trim();

  String get confirmPin => confirmPinCtrl.text.trim();

  String get storeType => selectedTypes.join(',');

  late final Map<String, List<BusinessProfile>> businessGroups;

  @override
  void initState() {
    super.initState();

    storeNameCtrl = TextEditingController(
      text: 'فروشگاه من',
    );

    adminNameCtrl = TextEditingController(
      text: 'مدیر سیستم',
    );

    adminPinCtrl = TextEditingController(
      text: '1234',
    );

    confirmPinCtrl = TextEditingController(
      text: '1234',
    );

    businessGroups = BusinessCatalog.grouped();
    layoutStyle = BusinessCatalog.layoutStyleFor(selectedTypes.join(','));
  }

  @override
  void dispose() {
    storeNameCtrl.dispose();
    adminNameCtrl.dispose();
    adminPinCtrl.dispose();
    confirmPinCtrl.dispose();

    super.dispose();
  }

  // ==========================================================================
  // ورود آنلاین به فروشگاه موجود
  // ==========================================================================

  Future<void> _loginExistingStore() async {
    final storeCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    String? error;
    bool busy = false;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              dialogContext,
              setDialogState,
            ) {
              return AlertDialog(
                title: const Text(
                  'ورود به فروشگاه موجود',
                ),
                content: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: storeCtrl,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'کد فروشگاه',
                          prefixIcon: Icon(
                            Icons.store_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: userCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'شناسه کاربر (مثلاً 1)',
                          prefixIcon: Icon(
                            Icons.person_outline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: 'پین‌کد (۴ تا ۸ رقم)',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                          ),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                          ),
                          child: Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop(false);
                          },
                    child: const Text(
                      'انصراف',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final storeCode = _normalizeOnlineLoginDigits(
                              storeCtrl.text.trim(),
                            ).toUpperCase();

                            final userIdText = _normalizeOnlineLoginDigits(
                              userCtrl.text.trim(),
                            );
                            final userId = int.tryParse(userIdText);

                            final pin = _normalizeOnlineLoginDigits(
                              pinCtrl.text.trim(),
                            );

                            if (storeCode.isEmpty) {
                              setDialogState(() {
                                error = 'کد فروشگاه را وارد کنید.';
                              });
                              return;
                            }
                            if (userId == null || userId <= 0) {
                              setDialogState(() {
                                error = 'شناسه کاربر باید عددی و بزرگ‌تر از صفر باشد؛ همان شناسه درج‌شده در اطلاعات ورود را وارد کنید.';
                              });
                              return;
                            }
                            if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
                              setDialogState(() {
                                error = 'رمز آنلاین باید بین ۴ تا ۸ رقم باشد.';
                              });
                              return;
                            }

                            setDialogState(() {
                              busy = true;
                              error = null;
                            });

                            try {
                              final result = await context
                                  .read<MainViewModel>()
                                  .loginOnlineToStore(
                                    storeCode: storeCode,
                                    userId: userId,
                                    pin: pin,
                                  );

                              if (!dialogContext.mounted) {
                                return;
                              }

                              if (result.ok) {
                                Navigator.of(
                                  dialogContext,
                                ).pop(true);
                              } else {
                                setDialogState(() {
                                  busy = false;
                                  error = result.msg;
                                });
                              }
                            } catch (e) {
                              if (!dialogContext.mounted) {
                                return;
                              }

                              setDialogState(() {
                                busy = false;
                                error = 'ورود آنلاین ناموفق بود: $e';
                              });
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'ورود',
                          ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true && mounted) {
        setState(() {
          errorMsg = null;
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'ورود آنلاین با موفقیت انجام شد.',
              ),
            ),
          );
      }
    } finally {
      storeCtrl.dispose();
      userCtrl.dispose();
      pinCtrl.dispose();
    }
  }

  // ==========================================================================
  // Build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final vm = context.read<MainViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'راه‌اندازی اولیه فروشگاه',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepIndicator(
                  1,
                  'اطلاعات فروشگاه',
                  step,
                  () {
                    setState(() {
                      step = 1;
                    });
                  },
                ),
                _StepIndicator(
                  2,
                  'ظاهر و چیدمان',
                  step,
                  () {
                    if (storeName.isNotEmpty) {
                      setState(() {
                        step = 2;
                      });
                    }
                  },
                ),
                _StepIndicator(
                  3,
                  'مدیر سیستم',
                  step,
                  () {
                    if (storeName.isNotEmpty) {
                      setState(() {
                        step = 3;
                      });
                    }
                  },
                ),
              ],
            ),
            const Divider(
              height: 32,
            ),
            OutlinedButton.icon(
              onPressed: _loginExistingStore,
              icon: const Icon(
                Icons.cloud_download_outlined,
              ),
              label: const Text(
                'ورود به فروشگاه موجود از طریق اینترنت',
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Text(
                  errorMsg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            if (step == 1) _buildStep1(vm),
            if (step == 2) _buildStep2(vm),
            if (step == 3) _buildStep3(vm),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Step 1
  // ==========================================================================

  Widget _buildStep1(
    MainViewModel vm,
  ) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'نام و نوع کسب‌وکار را مشخص کنید:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller: storeNameCtrl,
              decoration: const InputDecoration(
                labelText: 'نام فروشگاه',
                prefixIcon: Icon(
                  Icons.storefront_outlined,
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'نوع کسب‌وکار و ترکیب مشاغل:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            const Text(
              'می‌توانید چند شغل را همزمان انتخاب کنید. '
              'دسته‌بندی کالا، خدمات و واحدها براساس انتخاب شما تنظیم می‌شود.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            ...businessGroups.entries.map(
              (group) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ExpansionTile(
                      initiallyExpanded:
                          group.key == 'خودرو' || group.key == 'فروشگاهی',
                      title: Text(
                        group.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${group.value.length} نوع کسب‌وکار',
                      ),
                      children: group.value.map(
                        (profile) {
                          final selected = selectedTypes.contains(
                            profile.code,
                          );

                          return CheckboxListTile(
                            value: selected,
                            onChanged: (_) {
                              setState(() {
                                if (selected) {
                                  if (selectedTypes.length > 1) {
                                    selectedTypes.remove(profile.code);
                                  }
                                } else {
                                  selectedTypes.add(profile.code);
                                }

                                if (!layoutManuallySelected) {
                                  layoutStyle = BusinessCatalog.layoutStyleFor(
                                    selectedTypes.join(','),
                                  );
                                }
                              });
                            },
                            secondary: Icon(
                              profile.icon,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              profile.label,
                            ),
                            subtitle: Text(
                              profile.services.isEmpty
                                  ? profile.categories.take(5).join('، ')
                                  : '${profile.categories.take(4).join('، ')}'
                                      ' | خدمات: '
                                      '${profile.services.take(3).join('، ')}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(
              height: 4,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'لوگوی فروشگاه برای فاکتور و گزارش چاپی',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: logoBase64.isEmpty
                              ? const Icon(
                                  Icons.image_outlined,
                                  size: 34,
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    base64Decode(
                                      logoBase64,
                                    ),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                onPressed: _pickLogo,
                                icon: const Icon(
                                  Icons.upload_file,
                                ),
                                label: const Text(
                                  'انتخاب لوگو',
                                ),
                              ),
                              if (logoBase64.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      logoBase64 = '';
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                  ),
                                  label: const Text(
                                    'حذف لوگو',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    const Text(
                      'فرمت‌های PNG، JPG، JPEG و WEBP — حداکثر ۲ مگابایت',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                if (storeName.isEmpty) {
                  setState(() {
                    errorMsg = 'لطفاً نام فروشگاه را وارد کنید.';
                  });
                  return;
                }

                setState(() {
                  errorMsg = null;
                  step = 2;
                });
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'مرحله بعدی: تم و چیدمان',
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Icon(
                    Icons.arrow_forward,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Logo picker
  // ==========================================================================

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final bytes = result.files.single.bytes;

      if (bytes == null || bytes.isEmpty) {
        return;
      }

      if (bytes.length > 2 * 1024 * 1024) {
        if (!mounted) return;

        setState(() {
          errorMsg = 'حجم لوگو نباید بیشتر از ۲ مگابایت باشد.';
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        logoBase64 = base64Encode(bytes);
        errorMsg = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMsg = 'انتخاب لوگو ناموفق بود: $e';
      });
    }
  }

  // ==========================================================================
  // Step 2
  // ==========================================================================

  Widget _buildStep2(
    MainViewModel vm,
  ) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'رنگ‌بندی و واحد پولی فروشگاه:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'تم رنگی اختصاصی:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ColorOption(
                    'EMERALD',
                    const Color(0xFF00897B),
                    'زمردی',
                    colorTheme,
                    (value) {
                      setState(() {
                        colorTheme = value;
                      });
                    },
                  ),
                  _ColorOption(
                    'OCEAN',
                    const Color(0xFF0288D1),
                    'اقیانوسی',
                    colorTheme,
                    (value) {
                      setState(() {
                        colorTheme = value;
                      });
                    },
                  ),
                  _ColorOption(
                    'GOLDEN',
                    const Color(0xFFFFB300),
                    'طلایی',
                    colorTheme,
                    (value) {
                      setState(() {
                        colorTheme = value;
                      });
                    },
                  ),
                  _ColorOption(
                    'PURPLE',
                    const Color(0xFF7B1FA2),
                    'ارغوانی',
                    colorTheme,
                    (value) {
                      setState(() {
                        colorTheme = value;
                      });
                    },
                  ),
                  _ColorOption(
                    'RUBY',
                    const Color(0xFFD32F2F),
                    'یاقوتی',
                    colorTheme,
                    (value) {
                      setState(() {
                        colorTheme = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(
              height: 32,
            ),
            const Text(
              'واحد پول:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final value in [
                  'تومان',
                  'ریال',
                  '\$',
                ])
                  ChoiceChip(
                    label: Text(value),
                    selected: currency == value,
                    onSelected: (_) {
                      setState(() {
                        currency = value;
                      });
                    },
                  ),
              ],
            ),
            const Divider(
              height: 32,
            ),
            const Text(
              'دسترسی‌های Trial:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'دسترسی‌های دوره آزمایشی توسط License Manager تعیین و روی لایسنس ثبت می‌شوند. کاربر در این مرحله امکان انتخاب یا تغییر دسترسی‌ها را ندارد.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Divider(
              height: 32,
            ),
            const Text(
              'سبک چیدمان منوی فروش (POS):',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            RadioGroup<String>(
              groupValue: layoutStyle,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  layoutStyle = value;
                  layoutManuallySelected = true;
                });
              },
              child: Column(
                children: [
                  _layoutOption(
                    code: 'GRID',
                    label: 'شبکه‌ای (کاشی‌های متوسط)',
                    icon: Icons.grid_view,
                    description: 'چیدمان شبکه‌ای متعادل برای بیشتر فروشگاه‌ها',
                  ),
                  _layoutOption(
                    code: 'TOUCH_TILES',
                    label: 'کاشی‌های بزرگ لمسی',
                    icon: Icons.touch_app,
                    description: 'دکمه‌های بزرگ برای لمس سریع؛ مناسب کافه و فروش سریع',
                  ),
                  _layoutOption(
                    code: 'LIST',
                    label: 'لیست فشرده',
                    icon: Icons.view_list,
                    description: 'ردیف‌های کم‌ارتفاع با بارکد، موجودی و قیمت؛ مناسب اقلام زیاد',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('پیش‌نمایش زنده چیدمان فروش:',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  SizedBox(height: 96, child: _LayoutPreview(layoutStyle: layoutStyle)),
                ],
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        step = 1;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text(
                      'قبلی',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        step = 3;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text(
                      'بعدی: تعریف مدیر',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _layoutOption({
    required String code,
    required String label,
    IconData? icon,
    String? description,
  }) {
    final selected = layoutStyle == code;
    return InkWell(
      onTap: () {
        setState(() {
          layoutStyle = code;
          layoutManuallySelected = true;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 2,
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon ?? Icons.dashboard_outlined,
                size: 30,
                color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(description,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Step 3
  // ==========================================================================

  Widget _buildStep3(
    MainViewModel vm,
  ) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تنظیم پروفایل مدیر اصلی:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller: adminNameCtrl,
              decoration: const InputDecoration(
                labelText: 'نام و نام خانوادگی مدیر',
                prefixIcon: Icon(
                  Icons.person_outline,
                ),
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller: adminPinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'پین‌کد ورود مدیر (۴ تا ۶ رقم)',
                prefixIcon: Icon(
                  Icons.lock_outline,
                ),
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller: confirmPinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'تکرار پین‌کد',
                prefixIcon: Icon(
                  Icons.lock_outline,
                ),
              ),
            ),
            if (errorMsg != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  errorMsg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            const SizedBox(
              height: 16,
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        step = 2;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text(
                      'قبلی',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.check,
                    ),
                    label: const Text(
                      'تکمیل و ورود به برنامه',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () async {
                      if (adminName.isEmpty) {
                        setState(() {
                          errorMsg = 'نام مدیر نمی‌تواند خالی باشد.';
                        });
                        return;
                      }

                      if (!RegExp(
                        r'^\d{4,6}$',
                      ).hasMatch(adminPin)) {
                        setState(() {
                          errorMsg = 'پین‌کد باید بین ۴ تا ۶ رقم باشد.';
                        });
                        return;
                      }

                      if (adminPin != confirmPin) {
                        setState(() {
                          errorMsg = 'پین‌کد و تکرار آن یکسان نیستند.';
                        });
                        return;
                      }

                      setState(() {
                        errorMsg = null;
                      });

                      try {
                        await vm.saveInitialSetup(
                          storeName: storeName,
                          storeType: storeType,
                          businessTitle: BusinessCatalog.titleFor(
                            storeType,
                          ),
                          logoBase64: logoBase64,
                          colorTheme: colorTheme,
                          currency: currency,
                          layoutStyle: layoutStyle,
                          adminName: adminName,
                          adminPin: adminPin,
                        );

                        if (!context.mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(
                          context,
                        ).hideCurrentSnackBar();

                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'راه‌اندازی با موفقیت انجام شد.',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) {
                          return;
                        }

                        setState(() {
                          errorMsg = 'ذخیره راه‌اندازی ناموفق بود: $e';
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Step Indicator
// ============================================================================

class _StepIndicator extends StatelessWidget {
  final int stepNumber;
  final String label;
  final int currentStep;
  final VoidCallback onClick;

  const _StepIndicator(
    this.stepNumber,
    this.label,
    this.currentStep,
    this.onClick,
  );

  @override
  Widget build(
    BuildContext context,
  ) {
    final isCurrent = stepNumber == currentStep;

    final isDone = currentStep > stepNumber;

    return InkWell(
      onTap: onClick,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : isDone
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: isDone
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    )
                  : Text(
                      stepNumber.toString(),
                      style: TextStyle(
                        color: isCurrent ? Colors.white : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Color Option
// ============================================================================

class _ColorOption extends StatelessWidget {
  final String code;
  final Color color;
  final String name;
  final String selectedCode;
  final ValueChanged<String> onSelect;

  const _ColorOption(
    this.code,
    this.color,
    this.name,
    this.selectedCode,
    this.onSelect,
  );

  @override
  Widget build(
    BuildContext context,
  ) {
    final selected = code == selectedCode;

    return InkWell(
      onTap: () => onSelect(code),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.black : Colors.transparent,
                  width: 3,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _LayoutPreview extends StatelessWidget {
  final String layoutStyle;
  const _LayoutPreview({required this.layoutStyle});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    if (layoutStyle == 'LIST') {
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 3),
        itemBuilder: (_, i) => Container(
          height: 18,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }
    final maxExtent = layoutStyle == 'TOUCH_TILES' ? 58.0 : 88.0;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxExtent,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: layoutStyle == 'TOUCH_TILES'
              ? primary.withValues(alpha: 0.45)
              : primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
