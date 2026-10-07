/// A person the user splits expenses with. Identified by [id], never by name,
/// so two friends with the same name keep separate balances.
class Friend {
  final String id;
  final String name;
  final String? phone;
  final bool archived;

  const Friend({
    required this.id,
    required this.name,
    this.phone,
    this.archived = false,
  });

  String get firstName => name.split(' ').first;
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'archived': archived,
      };

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        archived: json['archived'] as bool? ?? false,
      );

  Friend copyWith({bool? archived}) =>
      Friend(id: id, name: name, phone: phone, archived: archived ?? this.archived);
}
