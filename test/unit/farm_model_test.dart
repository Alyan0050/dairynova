import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_nova_app/models/farm_model.dart';

void main() {
  test('Farm.fromFirestore maps fields correctly', () {
    final data = {
      'farmName': 'Sunny Farm',
      'ownerName': 'Ali',
      'ownerId': 'u1',
      'location': 'Townsville',
      'cnicUrl': 'https://example.com/cnic.png',
      'farmPhotos': ['a.png', 'b.png'],
      'status': 'pending',
      'flaggedImages': [1]
    };

    final f = Farm.fromFirestore(data, 'farm1');

    expect(f.id, 'farm1');
    expect(f.name, 'Sunny Farm');
    expect(f.owner, 'Ali');
    expect(f.location, 'Townsville');
    expect(f.farmPhotos.length, 2);
    expect(f.flaggedImages, [1]);
  });
}
