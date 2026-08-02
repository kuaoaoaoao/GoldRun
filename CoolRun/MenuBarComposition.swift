import Foundation

enum MenuBarCompositionFormatter {
    static func render(
        style: MenuBarCompositionStyle,
        primary: MenuBarDisplayMode,
        secondary: MenuBarDisplayMode,
        rotationUsesSecondary: Bool,
        value: (MenuBarDisplayMode, Bool) -> String
    ) -> String {
        switch style {
        case .single:
            return value(primary, false)
        case .pair:
            guard primary != secondary else { return value(primary, false) }
            return value(primary, true) + " · " + value(secondary, true)
        case .rotation:
            return value(rotationUsesSecondary && primary != secondary ? secondary : primary, false)
        }
    }
}
