class AppConstants {
  AppConstants._();

  // ── Storage keys ─────────────────────────────────────────────────────────────
  static const String keyAuthToken      = 'wyle_token';
  static const String keyUser           = 'wyle_user';
  static const String keyGoogleAccounts = 'wyle_google_accounts';
  static const String keyOutlookAccounts= 'wyle_outlook_accounts';
  static const String keyLastBriefKey   = 'wyle_last_brief_key';
  static const String keyObligations         = 'wyle_obligations';
  static const String keyActiveConversation  = 'wyle_active_conversation_id';
  static const String keyActionItems         = 'wyle_action_items';

  // ── API ──────────────────────────────────────────────────────────────────────
  static const String defaultApiUrl = 'http://localhost:3000/api';

  /// Wyle backend (production). Override with BUDDY_API_URL in .env.
  static const String buddyApiUrl   = 'https://api.wyle.ai';

  // ── Autonomy tiers ───────────────────────────────────────────────────────────
  static const List<Map<String, String>> autonomyTiers = [
    {'label': 'Observer',     'description': 'Monitor only — no actions'},
    {'label': 'Suggester',    'description': 'Suggest but wait for approval'},
    {'label': 'Assistant',    'description': 'Handle routine tasks automatically'},
    {'label': 'Orchestrator', 'description': 'Manage full workflows end-to-end'},
    {'label': 'Operator',     'description': 'Full autonomy — minimal oversight'},
  ];

  // ── Obligation types ─────────────────────────────────────────────────────────
  static const Map<String, String> obligationTypeLabels = {
    'visa':             'Visa',
    'emirates_id':      'Emirates ID',
    'car_registration': 'Car Registration',
    'insurance':        'Insurance',
    'school_fee':       'School Fee',
    'mortgage_emi':     'Mortgage / EMI',
    'subscription':     'Subscription',
    'medical':          'Medical',
    'document':         'Document',
    'bill':             'Bill',
    'custom':           'Custom',
  };

  static const Map<String, String> obligationTypeIcons = {
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

  // ── Risk levels ──────────────────────────────────────────────────────────────
  static const Map<String, String> riskLabels = {
    'high':   'High Risk',
    'medium': 'Medium Risk',
    'low':    'Low Risk',
  };

  // ── Dietary options ──────────────────────────────────────────────────────────
  static const List<String> dietaryOptions = [
    'Vegan', 'Vegetarian', 'Halal', 'Gluten-free', 'Dairy-free',
    'Keto', 'Low-carb', 'No restrictions',
  ];

  // ── Cuisine options ──────────────────────────────────────────────────────────
  static const List<String> cuisineOptions = [
    'Emirati', 'Indian', 'Lebanese', 'Japanese', 'Italian',
    'Mexican', 'Chinese', 'Thai', 'American', 'Mediterranean',
  ];

  // ── Work schedule ────────────────────────────────────────────────────────────
  static const List<Map<String, String>> workScheduleOptions = [
    {'value': 'standard', 'label': 'Standard (9-5)'},
    {'value': 'flexible', 'label': 'Flexible hours'},
    {'value': 'shift',    'label': 'Shift work'},
  ];

  // ── Buddy quick prompts ──────────────────────────────────────────────────────
  static const List<String> buddyQuickPrompts = [
    'What are my most urgent tasks?',
    'Renew my Emirates ID',
    'Check my calendar for conflicts',
    'Add a new obligation',
    'What bills are due this week?',
    'Show my insights',
  ];

  // ── Stats mock ───────────────────────────────────────────────────────────────
  static const double mockHoursSaved = 4.5;
  static const int    mockRunning    = 7;
  static const int    mockReliable   = 99;
}
