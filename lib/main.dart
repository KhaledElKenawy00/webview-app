import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String kSiteUrl = 'https://service-sharqia.ai.studio';
// Domain used to decide which links stay inside the app vs. open externally.
const String kSiteHost = 'service-sharqia.ai.studio';

// Android's WebView has no Web Speech API, so the site's "read the news
// aloud" feature calls window.speechSynthesis.cancel() on an undefined
// object and crashes the whole page on load. Stub it out before the site's
// own script runs so that call becomes a harmless no-op instead.
const String kSpeechSynthesisShim = '''
if (!window.speechSynthesis) {
  window.speechSynthesis = {
    cancel: function () {},
    speak: function () {},
    pause: function () {},
    resume: function () {},
    getVoices: function () { return []; },
    paused: false,
    pending: false,
    speaking: false,
    onvoiceschanged: null,
    addEventListener: function () {},
    removeEventListener: function () {}
  };
}
if (!window.SpeechSynthesisUtterance) {
  window.SpeechSynthesisUtterance = function (text) {
    this.text = text;
  };
}
''';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sharkya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const WebViewHome(),
    );
  }
}

class WebViewHome extends StatefulWidget {
  const WebViewHome({super.key});

  @override
  State<WebViewHome> createState() => _WebViewHomeState();
}

class _WebViewHomeState extends State<WebViewHome> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _progress = progress / 100);
          },
          onPageStarted: (_) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            _controller.runJavaScript(kSpeechSynthesisShim);
          },
          onPageFinished: (_) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // Ignore errors from sub-resources (ads, fonts, etc.); only the
            // main frame failing should show the full error screen.
            if (error.isForMainFrame ?? true) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;

            // Keep navigation inside the app for the app's own domain.
            if (uri.host == kSiteHost || uri.host.endsWith('.$kSiteHost')) {
              return NavigationDecision.navigate;
            }

            // Anything else (external sites, mailto:, tel:, whatsapp, etc.)
            // is handed off to the OS.
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(kSiteUrl));
  }

  Future<void> _reload() async {
    setState(() => _hasError = false);
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المركز الإعلامي لمحافظة الشرقية'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (!_hasError) WebViewWidget(controller: _controller),
              if (_isLoading && !_hasError)
                LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              if (_hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'تعذّر تحميل الصفحة، تأكد من الاتصال بالإنترنت',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
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
