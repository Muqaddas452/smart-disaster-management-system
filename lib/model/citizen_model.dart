class Citizen {
  final String id;
  final String name;
  final String email;
  final String phone;

  Citizen({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory Citizen.fromFirestore(Map<String, dynamic> data, String id) {
    return Citizen(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
    );
  }
}