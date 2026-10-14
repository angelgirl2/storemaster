// ============================================================================
// LoginScreen - انتخاب پروفایل و ورود پین‌کد
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int? selectedUserId;
  String pinInput = '';
  String? errorMsg;
  bool loginInProgress = false;

  late final TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _onlineLogin() async {
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
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('ورود آنلاین به فروشگاه'),
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
                          prefixIcon: Icon(Icons.store),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: userCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'شناسه کاربر (مثلاً 1)',
                          prefixIcon: Icon(Icons.person_outline),
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
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
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
                    onPressed: busy
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('انصراف'),
                  ),
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final store = _normalizeOnlineLoginDigits(
                              storeCtrl.text.trim(),
                            ).toUpperCase();
                            final userIdText = _normalizeOnlineLoginDigits(
                              userCtrl.text.trim(),
                            );
                            final uid = int.tryParse(userIdText);
                            final pin = _normalizeOnlineLoginDigits(
                              pinCtrl.text.trim(),
                            );

                            if (store.isEmpty) {
                              setDialogState(() {
                                error = 'کد فروشگاه را وارد کنید.';
                              });
                              return;
                            }
                            if (uid == null || uid <= 0) {
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
                              final r = await context
                                  .read<MainViewModel>()
                                  .loginOnlineToStore(
                                    storeCode: store,
                                    userId: uid,
                                    pin: pin,
                                  );

                              if (!dialogContext.mounted) return;

                              if (r.ok) {
                                Navigator.of(dialogContext).pop(true);
                              } else {
                                setDialogState(() {
                                  busy = false;
                                  error = r.msg;
                                });
                              }
                            } catch (e) {
                              if (!dialogContext.mounted) return;

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
                        : const Text('ورود'),
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
          loginInProgress = false;
        });
      }
    } finally {
      storeCtrl.dispose();
      userCtrl.dispose();
      pinCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MainViewModel>();
    final users = vm.users;
    final config = vm.config;

    final selectedUser = selectedUserId == null
        ? null
        : users.where((u) => u.id == selectedUserId).isEmpty
            ? null
            : users.firstWhere((u) => u.id == selectedUserId);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.storefront,
                  color: Theme.of(context).colorScheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                config?.storeName ?? 'سامانه مدیریت فروشگاه',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Text(
                'لطفاً جهت ورود پروفایل خود را انتخاب کنید',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // ورود آنلاین
              OutlinedButton.icon(
                onPressed: loginInProgress ? null : _onlineLogin,
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('ورود آنلاین به حساب فروشگاه'),
              ),

              const SizedBox(height: 24),

              if (users.isEmpty) const CircularProgressIndicator(),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (final u in users)
                    _UserTile(
                      user: u,
                      selected: selectedUserId == u.id,
                      onTap: () {
                        setState(() {
                          selectedUserId = u.id;
                          pinInput = '';
                          _pinController.clear();
                          errorMsg = null;
                        });
                      },
                    ),
                ],
              ),

              const SizedBox(height: 24),

              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: selectedUser == null
                    ? const SizedBox.shrink()
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                'ورود به عنوان ${selectedUser.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'پین‌کد ورود',
                                  prefixIcon: Icon(Icons.key),
                                ),
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                maxLength: 6,
                                controller: _pinController,
                                onChanged: (value) {
                                  setState(() {
                                    pinInput = value;
                                    errorMsg = null;
                                  });
                                },
                              ),
                              if (errorMsg != null)
                                Text(
                                  errorMsg!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.login),
                                  label: const Text('ورود به سامانه'),
                                  onPressed: loginInProgress
                                      ? null
                                      : () async {
                                          if (pinInput.isEmpty) {
                                            setState(() {
                                              errorMsg =
                                                  'لطفاً پین‌کد را وارد کنید';
                                            });
                                            return;
                                          }

                                          setState(() {
                                            loginInProgress = true;
                                            errorMsg = null;
                                          });

                                          try {
                                            final result =
                                                await vm.loginWithPin(
                                              pinInput,
                                              userId: selectedUserId,
                                            );

                                            if (!mounted) return;

                                            setState(() {
                                              loginInProgress = false;

                                              if (!result.ok) {
                                                errorMsg = result.msg;
                                              }
                                            });
                                          } catch (e) {
                                            if (!mounted) return;

                                            setState(() {
                                              loginInProgress = false;
                                              errorMsg = 'ورود ناموفق بود: $e';
                                            });
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final dynamic user;
  final bool selected;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = <String>[
      'OWNER',
      'ADMIN',
      'MANAGER',
    ].contains(user.role);

    final roleLabel = user.role == 'MANAGER'
        ? 'مدیر'
        : isAdmin
            ? 'مدیر کل'
            : user.role == 'WAREHOUSE'
                ? 'انباردار'
                : user.role == 'ACCOUNTANT'
                    ? 'حسابدار'
                    : user.role == 'CASHIER'
                        ? 'صندوق'
                        : 'فروشنده';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: isAdmin
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                roleLabel,
                style: const TextStyle(fontSize: 11),
              ),
              backgroundColor: isAdmin
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15)
                  : Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }
}
