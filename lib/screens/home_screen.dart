import 'package:attendance_app/screens/student_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

StudentHomeScreen studentHomeScreen = StudentHomeScreen(
  universityId: '',
  departmentId: '',
  batch: '',
  roll: 0,
  role: '',
);
