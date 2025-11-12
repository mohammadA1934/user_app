// 📝 ملف: rating_display.dart

import 'package:flutter/material.dart';

class RatingDisplay extends StatelessWidget {
  const RatingDisplay({
    super.key,
    required this.avgRating,
    this.ratingsCount,
    this.starSize = 16,
    this.textSize = 14,
  });

  final double avgRating;
  final int? ratingsCount;
  final double starSize;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    // تنسيق التقييم ليعرض رقمين بعد الفاصلة كحد أقصى (مثلاً 4.5 أو 4)
    final ratingText = avgRating.toStringAsFixed(avgRating == avgRating.toInt() ? 0 : 1);

    // إذا كان التقييم صفراً، نعرض "New" أو أي نص تفضلينه
    if (avgRating == 0.0 && (ratingsCount ?? 0) == 0) {
      return Text(
        'New',
        style: TextStyle(fontSize: textSize, color: Colors.grey),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          color: Colors.amber,
          size: starSize,
        ),
        const SizedBox(width: 4),
        Text(
          ratingText,
          style: TextStyle(
            fontSize: textSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        // عرض عدد التقييمات
        if (ratingsCount != null && ratingsCount! > 0)
          Text(
            ' (${ratingsCount})',
            style: TextStyle(
              fontSize: textSize * 0.9,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }
}