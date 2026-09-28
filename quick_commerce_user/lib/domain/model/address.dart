/// Saved delivery address. `label` is constrained by the backend enum.
enum AddressLabel {
  home('Home'),
  office('Office'),
  other('Other');

  const AddressLabel(this.wireValue);

  final String wireValue;

  static AddressLabel fromWire(String? value) => AddressLabel.values.firstWhere(
        (l) => l.wireValue.toLowerCase() == (value ?? '').toLowerCase(),
        orElse: () => AddressLabel.other,
      );
}

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.additionalDetails = '',
    this.zipCode = '',
    this.phone = '',
    this.flatNumber = '',
    this.blockNumber = '',
    this.colonyName = '',
    this.isDefault = false,
  });

  final String id;
  final AddressLabel label;
  final String street;
  final String city;
  final String state;
  final String additionalDetails;
  final String zipCode;
  final String phone;

  /// Fine-grained location within a building/society. Optional everywhere —
  /// older addresses saved before these existed simply carry empty strings.
  final String flatNumber;
  final String blockNumber;
  final String colonyName;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// `Flat 402`, `Block B` — prefixed so the number is not ambiguous on its
  /// own. Matches how the backend formats the same fields for the rider.
  String get _flatPart =>
      flatNumber.trim().isEmpty ? '' : 'Flat ${flatNumber.trim()}';

  String get _blockPart =>
      blockNumber.trim().isEmpty ? '' : 'Block ${blockNumber.trim()}';

  /// One-line form for the home header, kept short on purpose. The flat/block
  /// pair identifies the door, so it leads when the customer has filled it in.
  String get shortLine {
    final lead = [_flatPart, _blockPart].where((p) => p.isNotEmpty).join(', ');
    final tail = additionalDetails.trim().isNotEmpty
        ? additionalDetails.trim()
        : street.trim();
    if (lead.isEmpty) return tail;
    return tail.isEmpty ? lead : '$lead, $tail';
  }

  String get fullLine => [
        _flatPart,
        _blockPart,
        colonyName.trim(),
        additionalDetails.trim(),
        street.trim(),
        city.trim(),
        state.trim(),
        zipCode.trim(),
      ].where((p) => p.isNotEmpty).join(', ');

  Address copyWith({
    AddressLabel? label,
    String? street,
    String? city,
    String? state,
    String? additionalDetails,
    String? zipCode,
    String? phone,
    String? flatNumber,
    String? blockNumber,
    String? colonyName,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) =>
      Address(
        id: id,
        label: label ?? this.label,
        street: street ?? this.street,
        city: city ?? this.city,
        state: state ?? this.state,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        additionalDetails: additionalDetails ?? this.additionalDetails,
        zipCode: zipCode ?? this.zipCode,
        phone: phone ?? this.phone,
        flatNumber: flatNumber ?? this.flatNumber,
        blockNumber: blockNumber ?? this.blockNumber,
        colonyName: colonyName ?? this.colonyName,
        isDefault: isDefault ?? this.isDefault,
      );

  @override
  bool operator ==(Object other) => other is Address && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
