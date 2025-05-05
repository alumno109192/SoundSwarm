import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pay/pay.dart';

class GooglePayButtonWidget extends StatelessWidget {
  final bool isProduction; // Define si es producción o test

  GooglePayButtonWidget({this.isProduction = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaymentConfiguration>(
      future: _loadPaymentConfiguration(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar la configuración de Google Pay',
              style: const TextStyle(color: Colors.red),
            ),
          );
        } else if (!snapshot.hasData) {
          return const Center(
            child: Text('No se pudo cargar la configuración de Google Pay'),
          );
        }

        final paymentConfiguration = snapshot.data!;

        return GooglePayButton(
          paymentConfiguration: paymentConfiguration,
          paymentItems: [
            PaymentItem(
              label: 'Total',
              amount: '10.99',
              status: PaymentItemStatus.final_price,
            ),
          ],
          type: GooglePayButtonType.pay,
          margin: const EdgeInsets.only(top: 15.0),
          onPaymentResult: (Map<String, dynamic> result) {
            print('Resultado del pago: $result');
          },
          loadingIndicator: const CircularProgressIndicator(),
          onError: (error) {
            print('Error en el pago: $error');
          },
        );
      },
    );
  }

  Future<PaymentConfiguration> _loadPaymentConfiguration() async {
    final jsonString = await rootBundle.loadString(
      'assets/google_play_connect.json',
    );
    final jsonData = json.decode(jsonString);

    // Selecciona el entorno según `isProduction`
    final environment =
        isProduction ? jsonData['production'] : jsonData['test'];

    // Convierte el entorno seleccionado a un PaymentConfiguration
    return PaymentConfiguration.fromJsonString(json.encode(environment));
  }
}
