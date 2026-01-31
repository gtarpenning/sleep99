enum HealthAuthorizationState: Hashable {
    case unavailable
    case needsPermission
    case denied
    case authorized
}
