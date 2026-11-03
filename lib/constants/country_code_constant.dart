class CountryCode {
  final String name;
  final String dialCode;
  final String flag;

  const CountryCode({
    required this.name,
    required this.dialCode,
    required this.flag,
  });
}

/// Curated list, not exhaustive - South Africa first as the default since
/// that's The Runner's actual market. Add more as the app expands regions.
const List<CountryCode> countryCodes = [
  CountryCode(name: 'South Africa', dialCode: '+27', flag: '🇿🇦'),
  CountryCode(name: 'Botswana', dialCode: '+267', flag: '🇧🇼'),
  CountryCode(name: 'Namibia', dialCode: '+264', flag: '🇳🇦'),
  CountryCode(name: 'Zimbabwe', dialCode: '+263', flag: '🇿🇼'),
  CountryCode(name: 'Mozambique', dialCode: '+258', flag: '🇲🇿'),
  CountryCode(name: 'Lesotho', dialCode: '+266', flag: '🇱🇸'),
  CountryCode(name: 'Eswatini', dialCode: '+268', flag: '🇸🇿'),
  CountryCode(name: 'United Kingdom', dialCode: '+44', flag: '🇬🇧'),
  CountryCode(name: 'United States', dialCode: '+1', flag: '🇺🇸'),
];
