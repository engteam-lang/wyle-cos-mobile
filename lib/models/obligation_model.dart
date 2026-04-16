/// UI-ready obligation model (matches UIObligation from React Native)
class ObligationModel {
  final String id;
  final String emoji;
  final String title;
  final String type;
  final int daysUntil;
  final String risk; // 'high' | 'medium' | 'low'
  final double? amount;
  final String status; // 'active' | 'completed'
  final String executionPath;
  final String? notes;
  final String? source; // 'whatsapp' | 'email' | 'voice' | 'manual'
  final String? replyTo;
  final String? replySubject;
  final String? meetingLink;

  const ObligationModel({
    required this.id,
    required this.emoji,
    required this.title,
    required this.type,
    required this.daysUntil,
    required this.risk,
    this.amount,
    required this.status,
    required this.executionPath,
    this.notes,
    this.source,
    this.replyTo,
    this.replySubject,
    this.meetingLink,
  });

  ObligationModel copyWith({
    String? id,
    String? emoji,
    String? title,
    String? type,
    int? daysUntil,
    String? risk,
    double? amount,
    String? status,
    String? executionPath,
    String? notes,
    String? source,
  }) {
    return ObligationModel(
      id:            id            ?? this.id,
      emoji:         emoji         ?? this.emoji,
      title:         title         ?? this.title,
      type:          type          ?? this.type,
      daysUntil:     daysUntil     ?? this.daysUntil,
      risk:          risk          ?? this.risk,
      amount:        amount        ?? this.amount,
      status:        status        ?? this.status,
      executionPath: executionPath ?? this.executionPath,
      notes:         notes         ?? this.notes,
      source:        source        ?? this.source,
    );
  }

  factory ObligationModel.fromJson(Map<String, dynamic> json) {
    return ObligationModel(
      id:            json['_id']           ?? json['id'] ?? '',
      emoji:         json['emoji']         ?? '📦',
      title:         json['title']         ?? '',
      type:          json['type']          ?? 'custom',
      daysUntil:     json['daysUntil']     ?? 0,
      risk:          json['risk']          ?? 'low',
      amount:        (json['amount'] as num?)?.toDouble(),
      status:        json['status']        ?? 'active',
      executionPath: json['executionPath'] ?? '',
      notes:         json['notes'],
      source:        json['source'],
      replyTo:       json['replyTo'],
      replySubject:  json['replySubject'],
      meetingLink:   json['meetingLink'],
    );
  }

  Map<String, dynamic> toJson() => {
    '_id':           id,
    'emoji':         emoji,
    'title':         title,
    'type':          type,
    'daysUntil':     daysUntil,
    'risk':          risk,
    'amount':        amount,
    'status':        status,
    'executionPath': executionPath,
    'notes':         notes,
    'source':        source,
  };
}

/// Initial mock obligations (mirrors the React Native store mock data)
final List<ObligationModel> kInitialObligations = [
  const ObligationModel(
    id: '1', emoji: '🎓',
    title: 'School Fee — Q3',
    type: 'school_fee',
    daysUntil: 0,
    risk: 'high',
    amount: 14000,
    status: 'active',
    executionPath: 'Pay via school parent portal',
    notes: 'Due today — avoid late fee',
  ),
  const ObligationModel(
    id: '2', emoji: '🪪',
    title: 'Emirates ID Renewal',
    type: 'emirates_id',
    daysUntil: 5,
    risk: 'high',
    amount: 370,
    status: 'active',
    executionPath: 'ICA smart app — 20min process',
    notes: 'Renewal takes 3-5 working days',
  ),
  const ObligationModel(
    id: '3', emoji: '🚗',
    title: 'Range Rover Reg.',
    type: 'car_registration',
    daysUntil: 7,
    risk: 'high',
    amount: 450,
    status: 'active',
    executionPath: 'RTA online portal or drive-in',
    notes: 'Needs valid insurance first',
  ),
  const ObligationModel(
    id: '4', emoji: '🛂',
    title: 'UAE Residence Visa',
    type: 'visa',
    daysUntil: 14,
    risk: 'medium',
    amount: null,
    status: 'active',
    executionPath: 'GDRFA website — 45min process',
    notes: 'Requires passport + EID copy',
  ),
  const ObligationModel(
    id: '5', emoji: '💡',
    title: 'DEWA Bill',
    type: 'bill',
    daysUntil: 12,
    risk: 'medium',
    amount: 850,
    status: 'active',
    executionPath: 'DEWA app — auto pay',
    notes: null,
  ),
  const ObligationModel(
    id: '6', emoji: '🛡️',
    title: 'Car Insurance',
    type: 'insurance',
    daysUntil: 38,
    risk: 'low',
    amount: 2100,
    status: 'active',
    executionPath: 'AXA UAE app',
    notes: null,
  ),
];

/// Map type string → emoji
String emojiForType(String type) {
  const map = {
    'visa':             '🛂',
    'emirates_id':      '🪪',
    'car_registration': '🚗',
    'insurance':        '🛡️',
    'school_fee':       '🎓',
    'mortgage_emi':     '🏠',
    'subscription':     '📱',
    'medical':          '🏥',
    'document':         '📄',
    'bill':             '💡',
    'custom':           '📦',
  };
  return map[type] ?? '📦';
}
