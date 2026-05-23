import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final endpoints = ['/duas', '/search?q=waking', '/all'];
  for (final ep in endpoints) {
    final uri = Uri.parse('https://dua-dhikr.vercel.app' + ep);
    final res = await http.get(uri, headers: {'Accept-Language': 'en'});
    print('Endpoint ' + ep + ' -> ' + res.statusCode.toString());
    if (res.statusCode == 200) {
      print('Length: ' + res.body.length.toString());
      if (res.body.length < 500) print(res.body);
    }
  }
}
