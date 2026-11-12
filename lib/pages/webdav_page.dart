import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../core/webdav_service.dart';
import '../widgets/app_toast.dart';

class WebDavPage extends StatefulWidget {
  const WebDavPage({super.key});

  @override
  State<WebDavPage> createState() => _WebDavPageState();
}

class _WebDavPageState extends State<WebDavPage> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await WebDavService.instance.load();
    if (!mounted) return;
    setState(() {
      _url.text = WebDavService.instance.url;
      _user.text = WebDavService.instance.user;
      _pass.text = WebDavService.instance.pass;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await WebDavService.instance.save(
      url: _url.text,
      user: _user.text,
      pass: _pass.text,
    );
    if (!mounted) return;
    AppToast.show(context, L.t('folderCreated'));
  }

  Future<void> _upload() async {
    await _save();
    setState(() => _busy = true);
    final r = await WebDavService.instance.upload();
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(
      context,
      r.ok ? L.t('webdavOk') : '${r.error ?? L.t('operationFailed')}',
      accent: r.ok ? null : Theme.of(context).colorScheme.error,
    );
  }

  Future<void> _download() async {
    await _save();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(L.t('restoreConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(L.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(L.t('confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await WebDavService.instance.downloadAndImport();
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(
      context,
      r.ok
          ? '${L.t('webdavOk')} (${r.count})'
          : '${r.error ?? L.t('operationFailed')}',
      accent: r.ok ? null : Theme.of(context).colorScheme.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(L.t('webdav'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppStyle.pagePadding,
          AppStyle.pagePadding,
          AppStyle.pagePadding,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              L.t('webdavHint'),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _url,
            decoration: InputDecoration(
              labelText: L.t('webdavUrl'),
              hintText: 'https://dav.example.com/jmoe',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _user,
            decoration: InputDecoration(
              labelText: L.t('webdavUser'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: L.t('webdavPass'),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: _busy ? null : _upload,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(L.t('webdavUpload')),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _download,
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text(L.t('webdavDownload')),
            ),
          ),
        ],
      ),
    );
  }
}
