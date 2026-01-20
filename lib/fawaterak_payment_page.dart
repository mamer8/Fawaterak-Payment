import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class FawaterakPayment extends StatefulWidget {
  final Map<String, dynamic> customerModel;
  final List<Map<String, dynamic>> cartItems;
  final String totalAmount;

  const FawaterakPayment({
    super.key,
    required this.customerModel,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<FawaterakPayment> createState() => _FawaterakPaymentState();
}

class _FawaterakPaymentState extends State<FawaterakPayment> {
  bool paymentCompleted = false;
  bool isLoadingMethods = true;
  bool isLoadingPayment = false;
  List<dynamic> paymentMethods = [];

  InAppWebViewController? _webViewController;
  final GlobalKey webViewKey = GlobalKey();
  final GlobalKey _globalKey = GlobalKey();

  InAppWebViewSettings settings = InAppWebViewSettings(
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    cacheEnabled: true,
    javaScriptEnabled: true,
    useHybridComposition: false,
    sharedCookiesEnabled: true,
    useShouldOverrideUrlLoading: true,
    useOnLoadResource: false,
  );

  Map<String, dynamic>? successPaymentData;

  String? initialUrl;
  // //live
  //   final apiUrl = 'https://app.fawaterk.com/api/v2/invoiceInitPay';
  //   final getPaymentMethodsUrl = 'https://app.fawaterk.com/api/v2/getPaymentmethods';
  //   final apiToken = ;

  ///staging
  final apiUrl = 'https://staging.fawaterk.com/api/v2/invoiceInitPay';
  final getPaymentMethodsUrl =
      'https://staging.fawaterk.com/api/v2/getPaymentmethods';
  final apiToken = 'd83a5d07aaeb8442dcbe259e6dae80a3f2e21a3a581e1a5acd';

  void generateFawaterksession(int selectedPaymentId) async {
    setState(() {
      isLoadingPayment = true;
    });
    final data = {
      'payment_method_id': selectedPaymentId,
      'cartTotal': widget.totalAmount,
      'currency': 'EGP',
      'customer': widget.customerModel,
      'redirectionUrls': {
        'successUrl': 'https://dev.fawaterk.com/success',
        'failUrl': 'https://dev.fawaterk.com/fail',
        'pendingUrl': 'https://dev.fawaterk.com/pending',
      },
      'cartItems': widget.cartItems,
    };

    final headers = {
      'Authorization': 'Bearer $apiToken',
      'Content-Type': 'application/json',
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: json.encode(data),
      );

      final responseData = json.decode(response.body);
      log(responseData.toString());
      if (responseData != null) {
        final paymentData = responseData['data']?['payment_data'];
        if (paymentData != null) {
          if (paymentData['redirectTo'] != null) {
            final url = paymentData['redirectTo'];

            setState(() {
              initialUrl = url;
              paymentCompleted = true;
              successPaymentData = null;
              isLoadingPayment = false;
            });
          } else if (paymentData['fawryCode'] != null) {
            setState(() {
              paymentCompleted = false;
              successPaymentData = paymentData;
              isLoadingPayment = false;
            });
          } else if (paymentData['meezaReference'] != null) {
            setState(() {
              paymentCompleted = false;
              successPaymentData = paymentData;
              isLoadingPayment = false;
            });
          } else {
            // Handle other info-based payments or generic success
            setState(() {
              paymentCompleted = false;
              successPaymentData = paymentData;
              isLoadingPayment = false;
            });
          }
        } else {
          print('Payment data missing: $responseData');
        }
      }
    } catch (error) {
      print(error);
      setState(() {
        isLoadingPayment = false;
      });
    }
  }

  void fetchPaymentMethods() async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiToken',
    };

    try {
      final response = await http.get(
        Uri.parse(getPaymentMethodsUrl),
        headers: headers,
      );
      final responseData = json.decode(response.body);
      print('Payment Methods: ${json.encode(responseData)}');
      if (responseData['data'] != null) {
        setState(() {
          paymentMethods = responseData['data'];
          isLoadingMethods = false;
        });
      }
    } catch (error) {
      print('Error fetching payment methods: $error');
      setState(() {
        isLoadingMethods = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchPaymentMethods();
  }

  void handleNavigationStateChange(String newUrl) {
    // Check if the URL has changed to handle the response or perform further actions
    print('newUrl: $newUrl');

    // Replace 'https://dev.fawaterk.com/' with your redirectionUrls
    if (newUrl.contains('https://dev.fawaterk.com/')) {
      // Handle the response or perform any required actions here
      if (newUrl.contains('success')) {
        print('success');
        // You might want to pop here or show a success message
        Navigator.pop(context, true);
      } else {
        print('Cancelled');
        Navigator.pop(context, false);
      }
    }
  }

  Future<void> _captureAndSharePng() async {
    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/payment_receipt.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Payment Receipt');
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        actions: successPaymentData != null
            ? [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _captureAndSharePng,
                ),
              ]
            : null,
      ),
      body: successPaymentData != null
          ? Center(
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _globalKey,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 80,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Payment Initiated Successfully!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (successPaymentData!['fawryCode'] != null) ...[
                          const Text(
                            'Fawry Code:',
                            style: TextStyle(fontSize: 18),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${successPaymentData!['fawryCode']}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          '${successPaymentData!['fawryCode']}',
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Fawry Code copied to clipboard',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Expire Date: ${successPaymentData!['expireDate']}',
                          ),
                        ],
                        if (successPaymentData!['meezaReference'] != null) ...[
                          const Text(
                            'Meeza Reference:',
                            style: TextStyle(fontSize: 18),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${successPaymentData!['meezaReference']}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          '${successPaymentData!['meezaReference']}',
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Meeza Reference copied to clipboard',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (successPaymentData!['meezaQrCode'] != null) ...[
                            const SizedBox(height: 20),
                            QrImageView(
                              data: successPaymentData!['meezaQrCode']
                                  .toString(),
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          ],
                        ],
                        // Add generic data display for other methods if needed
                        if (successPaymentData!['fawryCode'] == null &&
                            successPaymentData!['meezaReference'] == null)
                          Text(successPaymentData.toString()),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              successPaymentData = null;
                              paymentCompleted = false; // Reset to methods
                            });
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : paymentCompleted && initialUrl != null
          ? InAppWebView(
              key: webViewKey,
              initialUrlRequest: URLRequest(url: WebUri(initialUrl!)),
              initialSettings: settings,
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onNavigationResponse: (controller, navigationResponse) async {
                return NavigationResponseAction.ALLOW;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url.toString();
                handleNavigationStateChange(url);
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStop: (controller, url) async {
                if (url != null) {
                  handleNavigationStateChange(url.toString());
                }
              },
            )
          : isLoadingMethods || isLoadingPayment
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: paymentMethods.length,
              itemBuilder: (context, index) {
                final method = paymentMethods[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: Image.network(
                      method['logo'],
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.payment),
                    ),
                    title: Text(method['name_en'] ?? method['name_ar'] ?? ""),
                    subtitle: Text(
                      method['name_ar'] ?? method['name_en'] ?? "",
                    ),
                    onTap: () {
                      generateFawaterksession(method['paymentId']);
                    },
                  ),
                );
              },
            ),
    );
  }
}
