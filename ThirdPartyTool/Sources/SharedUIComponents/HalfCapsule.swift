import SwiftUI

public struct HalfCapsule: Shape {
    public func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .init(x:0, y: 0))
            path.addLine(to: .init(x:rect.width, y:0))
            path.addArc(
                center: .init(x: rect.width - rect.height/2, y: rect.height/2),
                radius: rect.height/2,
                startAngle: .degrees(270),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x:0, y:rect.height))
            path.addLine(to: CGPoint(x:0, y:rect.height))
        }
    }
}
