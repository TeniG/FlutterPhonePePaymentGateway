import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String environment = "SANDBOX";
  String appId = "";
  String merchantId = "PGTESTPAYUAT";
  bool enableLogging = true;

  String packageName = "";
  String checksum = "";
  String saltkey = "099eb0cd-02cf-4e2a-8aca-3e6c6aff0399";
  String saltIndex = "1";
  String callbackurl = "https://webhook.site/callback-url";

  String body = "";
  String apiEndPoint = "/pg/v1/pay";

  Object? _result;

  @override
  void initState() {
    phonepePaymentInit();
    body = getCheckSum().toString();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("PhonePe Payment Gateway App"),
        ),
        body: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                startPGTransaction();
              },
              child: const Text("Start Transcation"),
            ),
            Text("Result \n $_result"),
          ],
        ));
  }

  void phonepePaymentInit() {
    PhonePePaymentSdk.init(environment, appId, merchantId, enableLogging)
        .then((val) => {
              setState(() {
                _result = 'PhonePe SDK Initialized - $val';
              })
            })
        .catchError((error) {
      handleError(error);
      return <dynamic>{};
    });
  }

  void handleError(error) {
    setState(() {
      _result = {"error": error};
    });
  }

  void startPGTransaction() async {
    PhonePePaymentSdk.startTransaction(body, callbackurl, checksum, packageName)
        .then((response) => {
              setState(() {
                if (response != null) {
                  String status = response['status'].toString();
                  String error = response['error'].toString();
                  if (status == 'SUCCESS') {
                    _result = "Flow Completed - Status: Success!";
                  } else {
                    _result =
                        "Flow Completed - Status: $status and Error: $error";
                  }
                } else {
                  _result = "Flow Incomplete";
                }
              })
            })
        .catchError((error) {
      // handleError(error)
      return <dynamic>{};
    });
  }

  String getCheckSum() {
    final requestData = {
      "merchantId": merchantId,
      "merchantTransactionId": "MT7850590068188104",
      "merchantUserId": "MUID123",
      "amount": 10000,
      "callbackUrl": callbackurl,
      "mobileNumber": "9999999999",
      "paymentInstrument": {"type": "PAY_PAGE"}
    };

    String base64Body = base64.encode(utf8.encode(json.encode(requestData)));
    checksum =
        '${sha256.convert(utf8.encode(base64Body + apiEndPoint + saltkey)).toString()}###$saltIndex';

    return base64Body;
  }
}
