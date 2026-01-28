import 'package:intl/intl.dart';

// Helper function to format intYYYYMMDD to String DD-MM-YYYY
String formatIntDateToDisplay(int? dateInt) {
  if (dateInt == null) return 'N/A';
  try {
    final dateString = dateInt.toString();
    if (dateString.length != 8) return 'Invalid Date'; // Basic validation
    final dateTime = DateTime.parse(
        '${dateString.substring(0, 4)}-${dateString.substring(4, 6)}-${dateString.substring(6, 8)}');
    return DateFormat('dd-MM-yyyy').format(dateTime);
  } catch (e) {
    print('Error formatting date $dateInt: $e');
    return 'Invalid Date';
  }
}

// Helper function to parse String DD-MM-YYYY to intYYYYMMDD
int? parseDisplayDateToInt(String dateString) {
  if (dateString.isEmpty) return null;
  try {
    final dateTime = DateFormat('dd-MM-yyyy').parse(dateString);
    return int.parse(DateFormat('yyyyMMdd').format(dateTime));
  } catch (e) {
    print('Error parsing date $dateString: $e');
    return null;
  }
}
