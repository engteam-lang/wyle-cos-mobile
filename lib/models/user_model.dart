class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? gender;       // 'male' | 'female' | null — from API /v1/users/me
  final String? designation;  // job title from API /v1/users/me
  final bool onboardingComplete;
  final int onboardingStep;
  final UserPreferences preferences;
  final int autonomyTier; // 0-4
  final UserInsights insights;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.gender,
    this.designation,
    this.onboardingComplete = false,
    this.onboardingStep = 0,
    required this.preferences,
    this.autonomyTier = 1,
    required this.insights,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? gender,
    String? designation,
    bool? onboardingComplete,
    int? onboardingStep,
    UserPreferences? preferences,
    int? autonomyTier,
    UserInsights? insights,
  }) {
    return UserModel(
      id:                 id                 ?? this.id,
      name:               name               ?? this.name,
      email:              email              ?? this.email,
      phone:              phone              ?? this.phone,
      gender:             gender             ?? this.gender,
      designation:        designation        ?? this.designation,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      onboardingStep:     onboardingStep     ?? this.onboardingStep,
      preferences:        preferences        ?? this.preferences,
      autonomyTier:       autonomyTier       ?? this.autonomyTier,
      insights:           insights           ?? this.insights,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:                 json['_id'] ?? json['id'] ?? json['public_id'] ?? '',
      name:               json['name'] ?? json['full_name'] ?? '',
      email:              json['email'] ?? '',
      phone:              json['phone'] as String?,
      gender:             json['gender'] as String?,
      designation:        json['designation'] as String?,
      onboardingComplete: json['onboardingComplete'] ?? false,
      onboardingStep:     json['onboardingStep'] ?? 0,
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : UserPreferences(),
      autonomyTier: json['autonomyTier'] ?? 1,
      insights: json['insights'] != null
          ? UserInsights.fromJson(json['insights'])
          : UserInsights(),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id':               id,
    'name':              name,
    'email':             email,
    'phone':             phone,
    'gender':            gender,
    'designation':       designation,
    'onboardingComplete':onboardingComplete,
    'onboardingStep':    onboardingStep,
    'preferences':       preferences.toJson(),
    'autonomyTier':      autonomyTier,
    'insights':          insights.toJson(),
  };
}

class UserPreferences {
  final List<String> dietary;
  final List<String> cuisines;
  final double mealBudget;
  final int householdSize;
  final bool hasChildren;
  final String workSchedule; // 'standard' | 'flexible' | 'shift'
  final List<String> protectedTimeBlocks;

  const UserPreferences({
    this.dietary          = const [],
    this.cuisines         = const [],
    this.mealBudget       = 100,
    this.householdSize    = 1,
    this.hasChildren      = false,
    this.workSchedule     = 'standard',
    this.protectedTimeBlocks = const [],
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      dietary:      List<String>.from(json['dietary'] ?? []),
      cuisines:     List<String>.from(json['cuisines'] ?? []),
      mealBudget:   (json['mealBudget'] as num?)?.toDouble() ?? 100,
      householdSize: json['householdSize'] ?? 1,
      hasChildren:   json['hasChildren'] ?? false,
      workSchedule:  json['workSchedule'] ?? 'standard',
      protectedTimeBlocks: List<String>.from(json['protectedTimeBlocks'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'dietary':           dietary,
    'cuisines':          cuisines,
    'mealBudget':        mealBudget,
    'householdSize':     householdSize,
    'hasChildren':       hasChildren,
    'workSchedule':      workSchedule,
    'protectedTimeBlocks': protectedTimeBlocks,
  };
}

class UserInsights {
  final int totalTimeSavedMinutes;
  final int totalDecisionsHandled;
  final double totalMoneySavedAED;

  const UserInsights({
    this.totalTimeSavedMinutes  = 0,
    this.totalDecisionsHandled  = 0,
    this.totalMoneySavedAED     = 0,
  });

  factory UserInsights.fromJson(Map<String, dynamic> json) {
    return UserInsights(
      totalTimeSavedMinutes:  json['totalTimeSavedMinutes'] ?? 0,
      totalDecisionsHandled:  json['totalDecisionsHandled'] ?? 0,
      totalMoneySavedAED:     (json['totalMoneySavedAED'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalTimeSavedMinutes':  totalTimeSavedMinutes,
    'totalDecisionsHandled':  totalDecisionsHandled,
    'totalMoneySavedAED':     totalMoneySavedAED,
  };
}
