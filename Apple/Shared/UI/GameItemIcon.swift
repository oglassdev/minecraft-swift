import MinecraftCore
import SwiftUI

struct GameItemIcon: View {
    let stack: ItemStack?
    var fallback = ""
    let size: CGFloat
    var pickupAnimation: Float = 0
    @ObservedObject private var rendered = InventoryRenderImages.shared
    @Environment(\.betaGUIRasterScale) private var rasterScale

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let stack, let definition = stack.definition {
                Group {
                    if let image = rendered.image(for: stack, rasterScale: rasterScale) {
                        Image(decorative: image, scale: 1).resizable().interpolation(.none).frame(
                            width: 16, height: 16)
                    } else {
                        BetaSprite(
                            name: "\(definition.iconTexture).png",
                            rect: CGRect(
                                x: definition.iconIndex(damage: stack.damage) % 16 * 16,
                                y: definition.iconIndex(damage: stack.damage) / 16 * 16, width: 16, height: 16
                            ))
                    }
                }.scaleEffect(
                    x: 1 / CGFloat(1 + pickupAnimation / 5), y: CGFloat(2 + pickupAnimation / 5) / 2,
                    anchor: UnitPoint(x: 0.5, y: 0.75))
                if stack.count > 1 {
                    let text = String(stack.count)
                    BetaText(text).offset(x: CGFloat(17 - BetaBitmapFont.shared.width(text)), y: 9)
                }
                if definition.maximumDurability > 0 && stack.damage > 0 {
                    let remaining = max(0, 1 - Double(stack.damage) / Double(definition.maximumDurability))
                    let length = Int(floor(13 * remaining + 0.5))
                    let green = Int(floor(255 * remaining + 0.5))
                    Rectangle().fill(.black).frame(width: 13, height: 2).offset(x: 2, y: 13)
                    Rectangle().fill(Color(red: Double((255 - green) / 4) / 255, green: 63.0 / 255, blue: 0))
                        .frame(width: 12, height: 1).offset(x: 2, y: 13)
                    Rectangle().fill(
                        Color(red: Double(255 - green) / 255, green: Double(green) / 255, blue: 0)
                    )
                    .frame(width: CGFloat(length), height: 1).offset(x: 2, y: 13)
                }
            }
        }.frame(width: 16, height: 16, alignment: .topLeading)
            .scaleEffect(size / 16, anchor: .topLeading)
            .frame(width: size, height: size, alignment: .topLeading).accessibilityHidden(true)
    }
}
