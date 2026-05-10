class AboutInfo {
  final String logo;
  final String appName;
  final String tagline;
  final String version;
  final String appDescription;
  final List<String> keyFeatures;
  final DeveloperInfo developerInfo;
  final SupportContact supportContact;
  final LegalInfo legalInfo;
  final String securityStatement;
  final SocialLinks socialLinks;
  final String copyright;
  final List<Changelog> changelog;

  AboutInfo({
    required this.logo,
    required this.appName,
    required this.tagline,
    required this.version,
    required this.appDescription,
    required this.keyFeatures,
    required this.developerInfo,
    required this.supportContact,
    required this.legalInfo,
    required this.securityStatement,
    required this.socialLinks,
    required this.copyright,
    required this.changelog,
  });

  factory AboutInfo.fromJson(Map<String, dynamic> json) {
    return AboutInfo(
      logo: json['logo'] ?? '',
      appName: json['app_name'] ?? '',
      tagline: json['tagline'] ?? '',
      version: json['version'] ?? '1.0.0',
      appDescription: json['app_description'] ?? '',
      keyFeatures: List<String>.from(json['key_features'] ?? []),
      developerInfo: DeveloperInfo.fromJson(json['developer_info'] ?? {}),
      supportContact: SupportContact.fromJson(json['support_contact'] ?? {}),
      legalInfo: LegalInfo.fromJson(json['legal_info'] ?? {}),
      securityStatement: json['security_statement'] ?? '',
      socialLinks: SocialLinks.fromJson(json['social_links'] ?? {}),
      copyright: json['copyright'] ?? '',
      changelog: (json['changelog'] as List? ?? [])
          .map((item) => Changelog.fromJson(item))
          .toList(),
    );
  }
}

class DeveloperInfo {
  final String developedBy;
  final String platform;
  final String founded;
  final String location;

  DeveloperInfo({
    required this.developedBy,
    required this.platform,
    required this.founded,
    required this.location,
  });

  factory DeveloperInfo.fromJson(Map<String, dynamic> json) {
    return DeveloperInfo(
      developedBy: json['developed_by'] ?? '',
      platform: json['platform'] ?? '',
      founded: json['founded'] ?? '',
      location: json['location'] ?? '',
    );
  }
}

class SupportContact {
  final String email;
  final String website;
  final String phone;
  final String github;
  final String twitter;

  SupportContact({
    required this.email,
    required this.website,
    required this.phone,
    required this.github,
    required this.twitter,
  });

  factory SupportContact.fromJson(Map<String, dynamic> json) {
    return SupportContact(
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      phone: json['phone'] ?? '',
      github: json['github'] ?? '',
      twitter: json['twitter'] ?? '',
    );
  }
}

class LegalInfo {
  final String privacyPolicy;
  final String termsOfService;
  final String refundPolicy;

  LegalInfo({
    required this.privacyPolicy,
    required this.termsOfService,
    required this.refundPolicy,
  });

  factory LegalInfo.fromJson(Map<String, dynamic> json) {
    return LegalInfo(
      privacyPolicy: json['privacy_policy'] ?? '',
      termsOfService: json['terms_of_service'] ?? '',
      refundPolicy: json['refund_policy'] ?? '',
    );
  }
}

class SocialLinks {
  final String github;
  final String twitter;
  final String linkedin;

  SocialLinks({
    required this.github,
    required this.twitter,
    required this.linkedin,
  });

  factory SocialLinks.fromJson(Map<String, dynamic> json) {
    return SocialLinks(
      github: json['github'] ?? '',
      twitter: json['twitter'] ?? '',
      linkedin: json['linkedin'] ?? '',
    );
  }
}

class Changelog {
  final String version;
  final String date;
  final List<String> changes;

  Changelog({required this.version, required this.date, required this.changes});

  factory Changelog.fromJson(Map<String, dynamic> json) {
    return Changelog(
      version: json['version'] ?? '',
      date: json['date'] ?? '',
      changes: List<String>.from(json['changes'] ?? []),
    );
  }
}
