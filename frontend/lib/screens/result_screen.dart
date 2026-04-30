import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final double price;

  const ResultScreen({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prediction Result"),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          "Predicted Price: ₹ ${price.toStringAsFixed(0)}",
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
