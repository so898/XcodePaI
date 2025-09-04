import SwiftUI

public var QuinarySystemFillColor: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .quinarySystemFill)
    } else {
        return Color("QuinarySystemFillColor")
    }
}

public var QuaternarySystemFillColor: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .quaternarySystemFill)
    } else {
        return Color("QuaternarySystemFillColor")
    }
}

public var TertiarySystemFillColor: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .tertiarySystemFill)
    } else {
        return Color("TertiarySystemFillColor")
    }
}

public var SecondarySystemFillColor: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .secondarySystemFill)
    } else {
        return Color("SecondarySystemFillColor")
    }
}
