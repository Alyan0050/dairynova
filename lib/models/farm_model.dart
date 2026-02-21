class Farm {
  final String id;
  final String name;
  final String owner;
  final String location;
  final String status;
  final String cnicUrl;
  final List<String> farmPhotos;
  final String adminFeedback; // New field
  final List<int> flaggedImages; // New field

  Farm({
    required this.id, 
    required this.name, 
    required this.owner, 
    required this.location, 
    required this.status,
    required this.cnicUrl,
    required this.farmPhotos,
    this.adminFeedback = '',
    this.flaggedImages = const [],
  });

  factory Farm.fromFirestore(Map<String, dynamic> data, String id) {
    return Farm(
      id: id,
      name: data['farmName'] ?? 'Unnamed Farm', 
      owner: data['ownerName'] ?? 'Unknown Owner',
      location: data['location'] ?? 'No Location',
      status: data['status'] ?? 'pending',
      cnicUrl: data['cnicUrl'] ?? '',
      farmPhotos: List<String>.from(data['farmPhotos'] ?? []),
      adminFeedback: data['adminFeedback'] ?? '',
      flaggedImages: List<int>.from(data['flaggedImages'] ?? []),
    );
  }
}