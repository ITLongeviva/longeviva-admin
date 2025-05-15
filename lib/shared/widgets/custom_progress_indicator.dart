import 'package:flutter/material.dart';

import '../utils/colors.dart';

class CustomProgressIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color color;

  const CustomProgressIndicator({
    super.key,
    this.message,
    this.size = 40.0,
    this.color = CustomColors.verdeAbisso,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If we're in a very constrained space
        if (constraints.maxHeight <= 20 || constraints.maxWidth <= 20) {
          // Just return a small spinner with no text
          return Center(
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          );
        }

        // If we have enough space and no message
        if (message == null) {
          return Center(
            child: SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          );
        }

        // If we have enough space and a message
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              if (constraints.maxHeight > 80) ...[
                const SizedBox(height: 16),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.8,
                  ),
                  child: Text(
                    message!,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}