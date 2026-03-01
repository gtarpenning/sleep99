enum SleepStage: String, CaseIterable, Hashable {
    case inBed
    case awake
    case asleep
    case asleepCore
    case asleepDeep
    case asleepREM

    var displayName: String {
        switch self {
        case .inBed:       return "In Bed"
        case .awake:       return "Awake"
        case .asleep:      return "Asleep"
        case .asleepCore:  return "Core"
        case .asleepDeep:  return "Deep"
        case .asleepREM:   return "REM"
        }
    }

    /// Higher = higher on chart. Awake at top, deep sleep at bottom.
    var sortOrder: Int {
        switch self {
        case .inBed:       return 0
        case .asleepDeep:  return 1
        case .asleepCore:  return 2
        case .asleep:      return 2  // generic; renders in the Core band
        case .asleepREM:   return 3
        case .awake:       return 4
        }
    }
}
