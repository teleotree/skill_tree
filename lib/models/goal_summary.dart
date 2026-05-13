class GoalSummary {
  final String narrative;
  final String coreCompetencies;
  final String considerations;
  final String marketOutlook;
  final String compensation;
  final String challenges;
  final String benefits;
  final String careerPath;
  final String dayInLife;
  final String industries;
  final String workStyle;
  final String barrierToEntry;

  GoalSummary({
    required this.narrative,
    required this.coreCompetencies,
    required this.considerations,
    required this.marketOutlook,
    required this.compensation,
    required this.challenges,
    required this.benefits,
    required this.careerPath,
    required this.dayInLife,
    required this.industries,
    required this.workStyle,
    required this.barrierToEntry,
  });

  factory GoalSummary.fromJson(Map<String, dynamic> json) {
    return GoalSummary(
      narrative: json['narrative'] ?? '',
      coreCompetencies: json['core_competencies'] ?? '',
      considerations: json['considerations'] ?? '',
      marketOutlook: json['market_outlook'] ?? '',
      compensation: json['compensation'] ?? '',
      challenges: json['challenges'] ?? '',
      benefits: json['benefits'] ?? '',
      careerPath: json['career_path'] ?? '',
      dayInLife: json['day_in_life'] ?? '',
      industries: json['industries'] ?? '',
      workStyle: json['work_style'] ?? '',
      barrierToEntry: json['barrier_to_entry'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'narrative': narrative,
    'core_competencies': coreCompetencies,
    'considerations': considerations,
    'market_outlook': marketOutlook,
    'compensation': compensation,
    'challenges': challenges,
    'benefits': benefits,
    'career_path': careerPath,
    'day_in_life': dayInLife,
    'industries': industries,
    'work_style': workStyle,
    'barrier_to_entry': barrierToEntry,
  };
}
