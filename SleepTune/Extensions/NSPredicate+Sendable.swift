import Foundation

// NSPredicate is immutable after creation in this app; treat as sendable for async child tasks.
extension NSPredicate: @unchecked Sendable {}
