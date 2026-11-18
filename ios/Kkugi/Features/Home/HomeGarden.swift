import SwiftUI

struct HomeGarden: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let walker = min(width * 204 / 360, height * 0.3, G.dp(240))
            let walkerHeight = walker * 270 / 247
            let scale = walker / 204 * 0.58
            let front = scale * 1.15
            let feet = height * 0.8
            let backY = feet - 846 * scale
            let frontY = feet + 14 * scale - 82 * front
            ZStack(alignment: .topLeading) {
                Color(hex: 0xF5E8D7)
                ArtImage(asset: .gardenBack)
                    .frame(width: 2060 * scale, height: 872 * scale)
                    .offset(y: backY)
                Ellipse().fill(.black.opacity(0.12))
                    .frame(width: walker * 0.55, height: walker * 0.07)
                    .position(x: width / 2, y: feet)
                ArtImage(asset: .homeWalk)
                    .frame(width: walker, height: walkerHeight)
                    .position(x: width / 2, y: feet - 0.49 * walkerHeight)
                Rectangle().fill(Color(hex: 0xD0D07E))
                    .frame(width: width, height: max(0, height - frontY - 246 * front + 1))
                    .offset(y: frontY + 246 * front - 1)
                ArtImage(asset: .gardenFront)
                    .frame(width: 2300 * front, height: 246 * front)
                    .offset(y: frontY)
            }.frame(width: width, height: height, alignment: .topLeading).clipped()
        }.accessibilityHidden(true)
    }
}
