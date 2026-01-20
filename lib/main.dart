import 'package:flutter/material.dart';
import 'package:fawaterak_integration/fawaterak_payment_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  /* 
DOCUMENTS LINK
https://fawaterak-api.readme.io/reference/getting-started-with-your-api
*/
  runApp(
    MaterialApp(
      home: FawaterakPayment(
        customerModel: {
          'first_name': 'Mahmoud',
          'last_name': 'Amer',
          'email': 'mahmoud.amer@fwaterak.com',
          'phone': '01027639683',
          'address': 'Cairo, Egypt',
        },
        cartItems: [
          {'name': 'Test Item', 'price': '500', 'quantity': '1'},
        ],
        totalAmount: '500',
      ),
    ),
  );
}
