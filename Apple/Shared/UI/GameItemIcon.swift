import MinecraftCore
import SwiftUI

struct GameItemIcon: View {
    let stack: ItemStack?
    var fallback = ""
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let stack, let definition = stack.definition,
                let image = VanillaUISprites.sprite(
                    "\(definition.iconTexture).png",
                    rect: CGRect(
                        x: (definition.iconIndex(damage: stack.damage) % 16) * 16,
                        y: (definition.iconIndex(damage: stack.damage) / 16) * 16, width: 16, height: 16))
            {
                Image(decorative: image, scale: 1).resizable().interpolation(.none)
                    .padding(size * 0.1)
                if stack.count > 1 {
                    Text("\(stack.count)").font(
                        .system(size: size * 0.32, weight: .bold, design: .monospaced)
                    )
                    .foregroundStyle(.white).shadow(color: .black, radius: 0, x: 1, y: 1)
                    .padding(.trailing, 2)
                }
                if definition.maximumDurability > 0 && stack.damage > 0 {
                    let remaining = max(0, 1 - Double(stack.damage) / Double(definition.maximumDurability))
                    Rectangle().fill(.black).frame(width: size * 0.75, height: 3)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color(red: 1 - remaining, green: remaining, blue: 0))
                                .frame(width: size * 0.75 * remaining, height: 2)
                        }
                        .padding(.bottom, 2).padding(.trailing, size * 0.125)
                }
            } else {
                Text(fallback).font(.system(size: 9, design: .monospaced))
                    .lineLimit(3).minimumScaleFactor(0.6).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
