import 'package:flutter/material.dart';

bool isMobile(BuildContext context) => MediaQuery.sizeOf(context).width < 768;
bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).width < 1100;
