class Farm {
  final String id;
  final String name;
  final String owner;
  final String ownerId;
  final String location; // Added this field to fix the error
  final String cnicUrl;
  final List<String> farmPhotos;
  final String status;
  final List<int> flaggedImages;

  Farm({
    required this.id,
    required this.name,
    required this.owner,
    required this.ownerId,
    required this.location,
    required this.cnicUrl,
    required this.farmPhotos,
    required this.status,
    required this.flaggedImages,
  });

  factory Farm.fromFirestore(Map<String, dynamic> data, String id) {
    return Farm(
      id: id,
      name: data['farmName'] ?? '',
      owner: data['ownerName'] ?? '',
      ownerId: data['ownerId'] ?? '',
      location: data['location'] ?? '', // Mapping the missing field
      cnicUrl: data['cnicUrl'] ?? '',
      farmPhotos: List<String>.from(data['farmPhotos'] ?? []),
      status: data['status'] ?? 'pending',
      flaggedImages: List<int>.from(data['flaggedImages'] ?? []),
    );
  }
}