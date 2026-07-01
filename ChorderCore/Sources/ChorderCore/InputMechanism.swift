import Foundation

public enum InputMechanism: String, Codable, CaseIterable, Identifiable {
  case inputMethod
  case legacyGlobalMonitoring

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .inputMethod:
      return "Input method (recommended)"
    case .legacyGlobalMonitoring:
      return "Global monitoring (advanced)"
    }
  }

  public var detailText: String {
    switch self {
    case .inputMethod:
      return "Select Chorder as your input source. No Accessibility or Input Monitoring permissions required."
    case .legacyGlobalMonitoring:
      return "Works with any keyboard layout. Requires Input Monitoring and Accessibility permissions."
    }
  }

  public static var defaultForCurrentBuild: InputMechanism {
    #if DEBUG
    return .legacyGlobalMonitoring
    #else
    return .inputMethod
    #endif
  }

  public static var isLegacyAvailable: Bool {
    #if DEBUG
    return true
    #else
  return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil
    #endif
  }
}
