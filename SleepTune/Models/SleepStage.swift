enum SleepStage: String, CaseIterable, Hashable {
    case inBed
    case awake
    case asleep
    case asleepCore
    case asleepDeep
    case asleepREM

    var displayName: String {
        switch self {
        case .inBed:
            return "In Bed"
        case .awake:
            return "Awake"
        case .asleep:
            return "Asleep"
        case .asleepCore:
            return "Core"
        case .asleepDeep:
            return "Deep"
        case .asleepREM:
            return "REM"
        }
    }

    var sortOrder: Int {
        switch self {
        case .inBed:
            return 0
        case .awake:
            return 1
        case .asleep:
            return 2
        case .asleepCore:
            return 3
        case .asleepDeep:
            return 4
        case .asleepREM:
            return 5
        }
    }
}
