/// Model class representing an emergency contact
class EmergencyContact {
  final String name;
  final String phoneNumber;

  const EmergencyContact({
    required this.name,
    required this.phoneNumber,
  });

  bool get isValid => name.trim().isNotEmpty && phoneNumber.trim().isNotEmpty;

  @override
  String toString() => 'EmergencyContact(name: $name, phone: $phoneNumber)';
}
