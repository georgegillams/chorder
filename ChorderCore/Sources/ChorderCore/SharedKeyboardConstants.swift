import Foundation

public enum SharedKeyboardConstants {
  public static let spaceEventKey: UInt16 = 49
  public static let tabEventKey: UInt16 = 48
  public static let backspaceEventKey: UInt16 = 51
  public static let escapeEventKey: UInt16 = 53
  public static let leftEventKey: UInt16 = 123
  public static let rightEventKey: UInt16 = 124
  public static let returnEventKey: UInt16 = 36
  public static let shiftEventKey: UInt16 = 56

  public static let skipPrecedingSpaceCharacters = [
    "!", "@", "%", "*", ")", "}", "]", "_", "-", "=", "+", "`", "~", "|", "\\", "/", ":", ";", ">", "?", ",", ".", "&", "#",
  ]
}
