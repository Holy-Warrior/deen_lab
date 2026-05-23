import 'lib/features/dua/service/dua_service.dart';

void main() async {
  final service = DuaService();
  try {
    print('Fetching duas...');
    final list = await service.fetchDuasForCategory('morning-dhikr');
    print('Fetched ' + list.length.toString() + ' items');
  } catch(e, st) {
    print('Error: ' + e.toString());
    print(st);
  }
}
