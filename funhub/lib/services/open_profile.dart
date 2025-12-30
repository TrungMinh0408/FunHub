import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/user_timeline_page.dart';

void openProfile(
    BuildContext context,
    DocumentSnapshot userDoc,
    ) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PersonalProfilePage(userDoc: userDoc),
    ),
  );
}
