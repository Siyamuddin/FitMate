class HealthSnapshot {
  const HealthSnapshot({
    this.steps,
    this.sleepHours,
    this.activeEnergy,
    this.connected = false,
  });

  final int? steps;
  final double? sleepHours;
  final double? activeEnergy;
  final bool connected;
}
