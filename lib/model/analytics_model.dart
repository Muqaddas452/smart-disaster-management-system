class AnalyticsModel {
  final int totalReports;
  final int activeDisasters;
  final int rescuedPeople;
  final double aiAccuracy;
  final Map<String, int> disasterDistribution;
  final List<double> monthlyReports;

  AnalyticsModel({
    required this.totalReports,
    required this.activeDisasters,
    required this.rescuedPeople,
    required this.aiAccuracy,
    required this.disasterDistribution,
    required this.monthlyReports,
  });
}