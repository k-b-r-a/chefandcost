/// Product-type fill profiles defining recommended batter/filling ratios.
enum FillProfileId {
  chiffonSponge,
  butterCake,
  brownieCheesecake,
  mousseEntremet,
  custom,
}

class FillProfile {
  final FillProfileId id;
  final double defaultFillRatio;
  final double maxRecommendedFillRatio;

  const FillProfile({
    required this.id,
    required this.defaultFillRatio,
    required this.maxRecommendedFillRatio,
  });

  static const FillProfile chiffonSponge = FillProfile(
    id: FillProfileId.chiffonSponge,
    defaultFillRatio: 0.62,
    maxRecommendedFillRatio: 0.70,
  );

  static const FillProfile butterCake = FillProfile(
    id: FillProfileId.butterCake,
    defaultFillRatio: 0.72,
    maxRecommendedFillRatio: 0.80,
  );

  static const FillProfile brownieCheesecake = FillProfile(
    id: FillProfileId.brownieCheesecake,
    defaultFillRatio: 0.88,
    maxRecommendedFillRatio: 0.95,
  );

  static const FillProfile mousseEntremet = FillProfile(
    id: FillProfileId.mousseEntremet,
    defaultFillRatio: 0.98,
    maxRecommendedFillRatio: 1.00,
  );

  static const FillProfile custom = FillProfile(
    id: FillProfileId.custom,
    defaultFillRatio: 0.72,
    maxRecommendedFillRatio: 0.95,
  );

  static const List<FillProfile> presets = [
    chiffonSponge,
    butterCake,
    brownieCheesecake,
    mousseEntremet,
  ];

  static FillProfile byId(FillProfileId id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return custom;
  }
}
