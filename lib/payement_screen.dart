import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import 'package:http/http.dart' as http;

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  TextEditingController _amountTextEditingController = TextEditingController();

  String environment = "SANDBOX";
  String appId = "";
  String merchantId = "PGTESTPAYUAT";
  bool enableLogging = true;

  String packageName = "";
  String saltkey = "099eb0cd-02cf-4e2a-8aca-3e6c6aff0399";
  String saltIndex = "1";
  String callbackurl = "https://webhook.site/callback-url";

  String body = "";
  String apiEndPoint = "/pg/v1/pay";

  Object? _result;
  String _paymentStatus = "";

  @override
  void initState() {
    phonepePaymentInit();
    super.initState();
  }

  void _onPayNowClicked() {
    startPGTransaction();
    setState(() {
      _paymentStatus = "";
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("PhonePe Payment App",
              style: TextStyle(fontWeight: FontWeight.bold)),
          foregroundColor: Colors.white,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountTextEditingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixText: "₹",
                  labelText: "Amount",
                  labelStyle: TextStyle(
                    fontSize: 24,
                  ),
                ),
                onChanged: (value) {
                  _amountTextEditingController.text = value;
                },
              ),
              const SizedBox(
                height: 24,
              ),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 248, 229, 23),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _onPayNowClicked,
                  child: const Text("Pay Now"),
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              const Text(
                "Result:",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text("$_result"),
              const SizedBox(
                height: 24,
              ),
              if (_paymentStatus != "")
                const Text(
                  "Transaction Status: ",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (_paymentStatus != "") Text("$_paymentStatus"),
            ],
          ),
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
    final String transactionId =
        DateTime.now().millisecondsSinceEpoch.toString();
    Map<String, Object> requestData = getRequestData(transactionId);

    String body = getBase64Body(requestData);
    String checksum = getCheckSum(requestData);

    PhonePePaymentSdk.startTransaction(body, callbackurl, checksum, packageName)
        .then((response) async {
      String message = "";
      if (response != null) {
        String status = response['status'].toString();
        String error = response['error'].toString();
        if (status == 'SUCCESS') {
          message = "Flow Completed - Status: Success!";
          await checkPaymentStatus(transactionId);
        } else {
          message = "Flow Completed - Status: $status and Error: $error";
        }
      } else {
        message = "Flow Incomplete";
      }

      setState(() {
        _result = message;
      });
    }).catchError((error) {
      handleError(error);
      // return <dynamic>{};
    });
  }

  Map<String, Object> getRequestData(String transactionId) {
    var amount = int.parse(_amountTextEditingController.text) * 100;

    print("amount = $amount");
    final requestData = {
      "merchantId": merchantId,
      "merchantTransactionId": transactionId,
      "merchantUserId": "MUID123",
      "amount": amount,
      "callbackUrl": callbackurl,
      "mobileNumber": "9999999999",
      "paymentInstrument": {"type": "PAY_PAGE"}
    };

    return requestData;
  }

  String getBase64Body(Map<String, Object> requestData) {
    String base64Body = base64.encode(utf8.encode(json.encode(requestData)));
    return base64Body;
  }

  String getCheckSum(Map<String, Object> requestData) {
    String base64Body = base64.encode(utf8.encode(json.encode(requestData)));
    String checksum =
        '${sha256.convert(utf8.encode(base64Body + apiEndPoint + saltkey)).toString()}###$saltIndex';

    return checksum;
  }

  checkPaymentStatus(String transactionId) async {
    try {
      String url =
          "https://api-preprod.phonepe.com/apis/pg-sandbox/pg/v1/status/$merchantId/$transactionId";

      String xVerifyString = "/pg/v1/status/$merchantId/$transactionId$saltkey";
      var bytes = utf8.encode(xVerifyString);
      var digest = sha256.convert(bytes).toString();

      String xVerify = '$digest###$saltIndex';

      Map<String, String> requestHeader = {
        "Content-Type": "application/json",
        "X-VERIFY": xVerify,
        "X-CLIENT-ID": merchantId
      };

      await http.get(Uri.parse(url), headers: requestHeader).then((value) {
        Map<String, dynamic> response = jsonDecode(value.body);

        try {
          if (response["success"] &&
              response["code"] == "PAYMENT_SUCCESS" &&
              response["data"]["paymentState"] == "COMPLETED") {
            _paymentStatus =
                "${response["message"]} \n TransactionId: $transactionId";
          } else {
            _paymentStatus =
                "${response["message"]} \n TransactionId: $transactionId";
          }
        } catch (e) {
          _paymentStatus = "Error : ${e.toString()}";
        }
      });
    } catch (e) {
      _paymentStatus = "Error : Something went wrong}";
    }
  }
}
