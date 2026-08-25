//
//  Blob.swift
//  Element
//
//  Created by Pradyum Mistry on 25/08/26.
//

import SwiftUI

/// A soft, organic decorative shape used behind the Craft canvas. Built from
/// a `Path` of cubic Bézier curves rather than a system shape, to showcase
/// custom `Shape`/`Path` construction.
struct Blob: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.45),
            control1: CGPoint(x: w * 0.85, y: 0),
            control2: CGPoint(x: w, y: h * 0.2)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h),
            control1: CGPoint(x: w, y: h * 0.75),
            control2: CGPoint(x: w * 0.85, y: h)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.6),
            control1: CGPoint(x: w * 0.2, y: h),
            control2: CGPoint(x: 0, y: h * 0.85)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: 0, y: h * 0.25),
            control2: CGPoint(x: w * 0.15, y: 0)
        )
        path.closeSubpath()
        return path
    }
}

struct BlobBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Blob()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.22), Color.purple.opacity(0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .offset(x: -geo.size.width * 0.3, y: -geo.size.height * 0.15)
                    .blur(radius: 30)

                Blob()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.16), Color.pink.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .offset(x: geo.size.width * 0.55, y: geo.size.height * 0.55)
                    .blur(radius: 30)
            }
        }
        .ignoresSafeArea()
    }
}
