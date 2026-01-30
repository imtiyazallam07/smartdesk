import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  double _loadingProgress = 0; // 0.0 to 1.0

  @override
  void initState() {
    super.initState();

    // 1. Get the URI object
    final Uri uri = Uri.parse(widget.url);

    // 2. Configure the WebViewController
    final WebViewController controller = WebViewController();

    // 3. Set up the controller properties
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update the loading progress
            setState(() {
              _loadingProgress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            setState(() => _loadingProgress = 0); // Reset progress on new page start
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            setState(() => _loadingProgress = 1); // Set to 100% when finished
            debugPrint('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
              Page resource error:
              code: ${error.errorCode}
              description: ${error.description}
              errorType: ${error.errorType}
              isForMainFrame: ${error.isForMainFrame}
            ''');
          },
          // Optional: Handle navigation requests (e.g., block links or launch external apps)
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://youtube.com/')) {
              debugPrint('blocking navigation to ${request.url}');
              // return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(uri); // 4. Load the requested URL

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        // Optional: Add controls for navigation
        actions: [
          _buildWebViewNavigationControls(context),
        ],
        // Show loading progress in the AppBar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: _loadingProgress < 1.0
              ? LinearProgressIndicator(
            value: _loadingProgress,
            backgroundColor: Colors.transparent,
            color: Theme.of(context).colorScheme.secondary,
          )
              : const SizedBox.shrink(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  /// Helper widget to include back/forward buttons
  Widget _buildWebViewNavigationControls(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () async {
            if (await _controller.canGoBack()) {
              await _controller.goBack();
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No back history item')),
                );
              }
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () async {
            if (await _controller.canGoForward()) {
              await _controller.goForward();
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No forward history item')),
                );
              }
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.replay),
          onPressed: () => _controller.reload(),
        ),
      ],
    );
  }
}
