String inferAvatarGender({
  required String? name,
  required String? email,
}) {
  final firstName = _extractFirstToken(name);
  final emailName = _extractFirstToken(email?.split('@').first);

  if (_isLikelyFemale(firstName) || _isLikelyFemale(emailName)) {
    return 'female';
  }
  if (_isLikelyMale(firstName) || _isLikelyMale(emailName)) {
    return 'male';
  }

  // Safe fallback to existing product default.
  return 'male';
}

String _extractFirstToken(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .trim();
  if (normalized.isEmpty) return '';
  return normalized.split(RegExp(r'\s+')).first;
}

bool _isLikelyFemale(String token) => _femaleNames.contains(token);
bool _isLikelyMale(String token) => _maleNames.contains(token);

const Set<String> _femaleNames = {
  'aisha', 'alia', 'amelia', 'ana', 'anna', 'anu', 'arya', 'ava', 'chloe',
  'dania', 'dana', 'deepa', 'dina', 'ella', 'emma', 'emily', 'fatima',
  'grace', 'hana', 'hannah', 'harper', 'isabella', 'julia', 'layla', 'lena',
  'maya', 'mia', 'mila', 'mona', 'nadia', 'nora', 'noura', 'olivia',
  'penelope', 'priya', 'reem', 'riley', 'sana', 'sara', 'sarah', 'sofia',
  'sophia', 'zoey',
};

const Set<String> _maleNames = {
  'adam', 'ahmed', 'ali', 'arjun', 'daniel', 'david', 'elias', 'ethan',
  'faris', 'hassan', 'ibrahim', 'james', 'john', 'khalid', 'liam', 'lucas',
  'mohamed', 'mohammad', 'muhammad', 'noah', 'omar', 'rayyan', 'ryan',
  'saeed', 'sam', 'samir', 'thomas', 'william', 'yousef', 'yusuf', 'zaid',
  'zayn',
};
