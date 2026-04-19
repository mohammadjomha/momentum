import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceEntry {
  final String entryId;
  final String type;
  final DateTime lastDoneDate;
  final DateTime? nextDueDate;
  final String? notes;
  final DateTime createdAt;

  const MaintenanceEntry({
    required this.entryId,
    required this.type,
    required this.lastDoneDate,
    this.nextDueDate,
    this.notes,
    required this.createdAt,
  });

  factory MaintenanceEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MaintenanceEntry(
      entryId: doc.id,
      type: d['type'] as String,
      lastDoneDate: (d['lastDoneDate'] as Timestamp).toDate(),
      nextDueDate: d['nextDueDate'] != null
          ? (d['nextDueDate'] as Timestamp).toDate()
          : null,
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'lastDoneDate': Timestamp.fromDate(lastDoneDate),
      if (nextDueDate != null) 'nextDueDate': Timestamp.fromDate(nextDueDate!),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  MaintenanceEntry copyWith({
    String? entryId,
    String? type,
    DateTime? lastDoneDate,
    DateTime? nextDueDate,
    String? notes,
    DateTime? createdAt,
    bool clearNextDueDate = false,
    bool clearNotes = false,
  }) {
    return MaintenanceEntry(
      entryId: entryId ?? this.entryId,
      type: type ?? this.type,
      lastDoneDate: lastDoneDate ?? this.lastDoneDate,
      nextDueDate: clearNextDueDate ? null : (nextDueDate ?? this.nextDueDate),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}