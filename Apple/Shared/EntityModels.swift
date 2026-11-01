import Foundation
import MinecraftCore
import simd

struct EntityModelPart {
    var minimum: SIMD3<Float>
    var size: SIMD3<Float>
    var pivot: SIMD3<Float>
    var texture: SIMD2<Float>
    var rotation: SIMD3<Float> = .zero
    var inflation: Float = 0
    var mirrored = false

    init(
        _ minimum: SIMD3<Float>, _ size: SIMD3<Float>, at pivot: SIMD3<Float>,
        uv: SIMD2<Float>, rotation: SIMD3<Float> = .zero, inflation: Float = 0, mirrored: Bool = false
    ) {
        self.minimum = minimum
        self.size = size
        self.pivot = pivot
        self.texture = uv
        self.rotation = rotation
        self.inflation = inflation
        self.mirrored = mirrored
    }

    func vertices(
        position: SIMD3<Float>, yaw: Float, scale: Float, originY: Float,
        tint: SIMD3<Float>, light: UInt8, opacity: Float, transform: simd_float4x4 = matrix_identity_float4x4,
        lightTransform: simd_float3x3 = matrix_identity_float3x3
    ) -> [BlockVertex] {
        var low = minimum - SIMD3(repeating: inflation)
        var high = minimum + size + SIMD3(repeating: inflation)
        if mirrored { swap(&low.x, &high.x) }
        let points = [
            SIMD3(low.x, low.y, low.z), SIMD3(high.x, low.y, low.z),
            SIMD3(high.x, high.y, low.z), SIMD3(low.x, high.y, low.z),
            SIMD3(low.x, low.y, high.z), SIMD3(high.x, low.y, high.z),
            SIMD3(high.x, high.y, high.z), SIMD3(low.x, high.y, high.z),
        ]
        let x = size.x
        let y = size.y
        let z = size.z
        let rects = [
            SIMD4(z + x, z, z + x + z, z + y), SIMD4(0, z, z, z + y), SIMD4(z, 0, z + x, z),
            SIMD4(z + x, 0, z + x + x, z), SIMD4(z, z, z + x, z + y),
            SIMD4(z + x + z, z, z + x + z + x, z + y),
        ]
        var result: [BlockVertex] = []
        result.reserveCapacity(36)
        let columns = transform.columns
        let normalMatrix =
            transform == matrix_identity_float4x4
            ? matrix_identity_float3x3
            : simd_transpose(
                simd_inverse(
                    simd_float3x3(
                        columns: (
                            SIMD3(columns.0.x, columns.0.y, columns.0.z),
                            SIMD3(columns.1.x, columns.1.y, columns.1.z),
                            SIMD3(columns.2.x, columns.2.y, columns.2.z)
                        ))))
        for (faceIndex, indices) in Self.faceCorners.enumerated() {
            let rect = rects[faceIndex]
            var normal = simd_normalize(
                simd_cross(points[indices[1]] - points[indices[0]], points[indices[2]] - points[indices[0]]))
            if mirrored { normal = -normal }
            normal = Self.rotate(normal, by: rotation)
            normal = simd_normalize(normalMatrix * SIMD3(-normal.x, -normal.y, normal.z))
            normal = Self.rotate(normal, by: SIMD3(0, -yaw, 0))
            let shade = BetaLighting.shade(normal: lightTransform * normal)
            let u0 = (texture.x + rect.x) / 64 + 0.0015625
            let u1 = (texture.x + rect.z) / 64 - 0.0015625
            let v0 = (texture.y + rect.y) / 32 + 0.003125
            let v1 = (texture.y + rect.w) / 32 - 0.003125
            let u = SIMD4(u1, u0, u0, u1)
            let v = SIMD4(v0, v0, v1, v1)
            for index in mirrored ? Self.mirroredOrder : Self.windingOrder {
                let local = Self.rotate(points[indices[index]], by: rotation) + pivot
                let converted = SIMD3(-local.x, originY - local.y, local.z) / 16 * scale
                let transformed = transform * SIMD4(converted, 1)
                let world =
                    position
                    + Self.rotate(SIMD3(transformed.x, transformed.y, transformed.z), by: SIMD3(0, -yaw, 0))
                result.append(
                    BlockVertex(
                        position: world, color: tint * shade, uv: SIMD2(u[index], v[index]),
                        opacity: opacity, light: light))
            }
        }
        return result
    }

    private static let faceCorners: [SIMD4<Int>] = [
        SIMD4(5, 1, 2, 6), SIMD4(0, 4, 7, 3), SIMD4(5, 4, 0, 1), SIMD4(2, 3, 7, 6), SIMD4(1, 0, 3, 2),
        SIMD4(4, 5, 6, 7),
    ]
    private static let windingOrder = [0, 1, 2, 0, 2, 3]
    private static let mirroredOrder = [3, 2, 1, 3, 1, 0]

    static func rotate(_ point: SIMD3<Float>, by rotation: SIMD3<Float>) -> SIMD3<Float> {
        let x = SIMD3(
            point.x, point.y * cos(rotation.x) - point.z * sin(rotation.x),
            point.y * sin(rotation.x) + point.z * cos(rotation.x))
        let y = SIMD3(
            x.x * cos(rotation.y) + x.z * sin(rotation.y), x.y,
            -x.x * sin(rotation.y) + x.z * cos(rotation.y))
        return SIMD3(
            y.x * cos(rotation.z) - y.y * sin(rotation.z),
            y.x * sin(rotation.z) + y.y * cos(rotation.z), y.z)
    }
}

struct EntityModelLayer {
    var texture: String
    var parts: [EntityModelPart]
    var tint = SIMD3<Float>(repeating: 1)
    var scale: Float = 1
    var originY: Float = 24.125
    var opacity: Float = 1
    var blended = false
    var fullbright = false
    var additive = false
    var uvOffset = SIMD2<Float>.zero
    var transform = matrix_identity_float4x4
}

/// Cuboid dimensions and skin rectangles follow the original Beta model classes.
enum EntityModels {
    static func layers(
        entity: GameEntity, phase: Float, amplitude: Float, age: Float, partial: Float = 1, headYaw: Float = 0
    ) -> [EntityModelLayer] {
        let stride = phase * 0.6662
        let swing = cos(stride) * 1.4 * amplitude
        let opposite = cos(stride + .pi) * 1.4 * amplitude
        let head = SIMD3(-entity.pitch, headYaw, 0)
        switch entity.kind {
        case "player", "zombie", "skeleton", "pigZombie":
            let player = entity.kind == "player"
            let skeleton = entity.kind == "skeleton"
            let limbWidth: Float = skeleton ? 2 : 4
            let armMinimum: Float = skeleton ? -1 : -3
            var rightArm = SIMD3<Float>(
                (player ? opposite * 0.5 : -.pi / 2) + sin(age * 0.067) * 0.05,
                player ? 0 : -0.1, cos(age * 0.09) * 0.05 + 0.05)
            let leftArm = SIMD3<Float>(
                (player ? swing * 0.5 : -.pi / 2) - sin(age * 0.067) * 0.05,
                player ? 0 : 0.1, -cos(age * 0.09) * 0.05 - 0.05)
            if player, entity.contents.first.flatMap({ $0 }) != nil {
                rightArm.x = rightArm.x * 0.5 - .pi / 10
            }
            var parts = [
                part(-4, -8, -4, 8, 8, 8, 0, 0, 0, 0, 0, rotation: head),
                part(-4, -8, -4, 8, 8, 8, 0, 0, 0, 32, 0, rotation: head, inflation: 0.5),
                part(-4, 0, -2, 8, 12, 4, 0, 0, 0, 16, 16),
                part(
                    armMinimum, -2, -limbWidth / 2, limbWidth, 12, limbWidth, -5, 2, 0, 40, 16,
                    rotation: rightArm),
                part(
                    -1, -2, -limbWidth / 2, limbWidth, 12, limbWidth, 5, 2, 0, 40, 16, rotation: leftArm,
                    mirrored: true),
                part(
                    -limbWidth / 2, 0, -limbWidth / 2, limbWidth, 12, limbWidth, -2, 12, 0, 0, 16,
                    rotation: SIMD3(swing, 0, 0)),
                part(
                    -limbWidth / 2, 0, -limbWidth / 2, limbWidth, 12, limbWidth, 2, 12, 0, 0, 16,
                    rotation: SIMD3(opposite, 0, 0), mirrored: true),
            ]
            if player && entity.remoteFlags & 2 != 0 {
                parts[2].rotation.x = 0.5
                parts[3].rotation.x += 0.4
                parts[4].rotation.x += 0.4
                for index in [5, 6] {
                    parts[index].pivot.y = 9
                    parts[index].pivot.z = 4
                }
                parts[0].pivot.y = 1
                parts[1].pivot.y = 1
            }
            var layers = [
                EntityModelLayer(
                    texture:
                        "mob/\(player ? "char" : (entity.kind == "pigZombie" ? "pigzombie" : entity.kind))",
                    parts: parts, scale: player ? 0.9375 : 1)
            ]
            if player {
                for stack in entity.contents.dropFirst().compactMap({ $0 }) {
                    guard let slot = stack.definition?.armorSlot, (298...317).contains(stack.id) else {
                        continue
                    }
                    let material = ["cloth", "chain", "iron", "diamond", "gold"][Int(stack.id - 298) / 4]
                    let indices = [[0], [2, 3, 4], [2, 5, 6], [5, 6]][slot]
                    let armor = indices.map { index in
                        var part = parts[index]
                        part.inflation = slot == 2 ? 0.5 : 1
                        return part
                    }
                    layers.append(
                        EntityModelLayer(
                            texture: "armor/\(material)_\(slot == 2 ? 2 : 1)", parts: armor, scale: 0.9375))
                }
            }
            return layers
        case "pig":
            let parts = quadruped(legHeight: 6, swing: swing, opposite: opposite, head: head)
            var layers = [
                EntityModelLayer(
                    texture: "mob/pig",
                    parts: parts)
            ]
            if entity.metadata & 1 != 0 {
                layers.append(
                    EntityModelLayer(
                        texture: "mob/saddle",
                        parts: parts.map { part in
                            var part = part
                            part.inflation = 0.5
                            return part
                        }))
            }
            return layers
        case "cow":
            var parts = quadruped(legHeight: 12, swing: swing, opposite: opposite, head: head)
            parts[0] = part(-4, -4, -6, 8, 8, 6, 0, 4, -8, 0, 0, rotation: head)
            parts[1] = part(-6, -10, -7, 12, 18, 10, 0, 5, 2, 18, 4, rotation: SIMD3(.pi / 2, 0, 0))
            parts[2].pivot.x = -4
            parts[3].pivot.x = 4
            parts[4].pivot.x = -4
            parts[4].pivot.z = -6
            parts[5].pivot.x = 4
            parts[5].pivot.z = -6
            parts.append(part(-4, -5, -4, 1, 3, 1, 0, 3, -7, 22, 0, rotation: head))
            parts.append(part(3, -5, -4, 1, 3, 1, 0, 3, -7, 22, 0, rotation: head))
            parts.append(part(-2, -3, 0, 4, 6, 2, 0, 14, 6, 52, 0, rotation: SIMD3(.pi / 2, 0, 0)))
            return [EntityModelLayer(texture: "mob/cow", parts: parts)]
        case "sheep":
            var parts = quadruped(legHeight: 12, swing: swing, opposite: opposite, head: head)
            parts[0] = part(-3, -4, -6, 6, 6, 8, 0, 6, -8, 0, 0, rotation: head)
            parts[1] = part(-4, -10, -7, 8, 16, 6, 0, 5, 2, 28, 8, rotation: SIMD3(.pi / 2, 0, 0))
            let skin = EntityModelLayer(texture: "mob/sheep", parts: parts)
            guard entity.metadata & 16 == 0 else { return [skin] }
            var wool = parts
            wool[0] = part(-3, -4, -4, 6, 6, 6, 0, 6, -8, 0, 0, rotation: head, inflation: 0.6)
            wool[1].inflation = 1.75
            for index in 2..<6 {
                wool[index].size.y = 6
                wool[index].inflation = 0.5
            }
            return [
                skin,
                EntityModelLayer(
                    texture: "mob/sheep_fur", parts: wool,
                    tint: fleeceColors[Int(entity.metadata & 15)]),
            ]
        case "chicken":
            let wingRotation =
                entity.previousWingRotation + (entity.wingRotation - entity.previousWingRotation) * partial
            let wingSpread =
                entity.previousWingSpread + (entity.wingSpread - entity.previousWingSpread) * partial
            let flap = (BetaVisualMath.sine(wingRotation) + 1) * wingSpread
            return [
                EntityModelLayer(
                    texture: "mob/chicken",
                    parts: [
                        part(-2, -6, -2, 4, 6, 3, 0, 15, -4, 0, 0, rotation: head),
                        part(-2, -4, -4, 4, 2, 2, 0, 15, -4, 14, 0, rotation: head),
                        part(-1, -2, -3, 2, 2, 2, 0, 15, -4, 14, 4, rotation: head),
                        part(-3, -4, -3, 6, 8, 6, 0, 16, 0, 0, 9, rotation: SIMD3(.pi / 2, 0, 0)),
                        part(-1, 0, -3, 3, 5, 3, -2, 19, 1, 26, 0, rotation: SIMD3(swing, 0, 0)),
                        part(-1, 0, -3, 3, 5, 3, 1, 19, 1, 26, 0, rotation: SIMD3(opposite, 0, 0)),
                        part(0, 0, -3, 1, 4, 6, -4, 13, 0, 24, 13, rotation: SIMD3(0, 0, flap)),
                        part(-1, 0, -3, 1, 4, 6, 4, 13, 0, 24, 13, rotation: SIMD3(0, 0, -flap)),
                    ])
            ]
        case "creeper":
            let parts = [
                part(-4, -8, -4, 8, 8, 8, 0, 4, 0, 0, 0, rotation: head),
                part(-4, 0, -2, 8, 12, 4, 0, 4, 0, 16, 16),
                part(-2, 0, -2, 4, 6, 4, -2, 16, 4, 0, 16, rotation: SIMD3(swing, 0, 0)),
                part(-2, 0, -2, 4, 6, 4, 2, 16, 4, 0, 16, rotation: SIMD3(opposite, 0, 0)),
                part(-2, 0, -2, 4, 6, 4, -2, 16, -4, 0, 16, rotation: SIMD3(opposite, 0, 0)),
                part(-2, 0, -2, 4, 6, 4, 2, 16, -4, 0, 16, rotation: SIMD3(swing, 0, 0)),
            ]
            let swelling = Float(entity.fuseTicks) / 28
            let wobble = 1 + sin(swelling * 100) * swelling * 0.01
            let amount = pow(min(1, max(0, swelling)), 4)
            let transform = simd_float4x4(
                diagonal: SIMD4(
                    (1 + amount * 0.4) * wobble, (1 + amount * 0.1) / wobble, (1 + amount * 0.4) * wobble, 1))
            var layers = [EntityModelLayer(texture: "mob/creeper", parts: parts, transform: transform)]
            if entity.metadata & 1 != 0 {
                layers.append(
                    EntityModelLayer(
                        texture: "armor/power",
                        parts: parts.map { part in
                            var part = part
                            part.inflation = 2
                            return part
                        },
                        tint: SIMD3(repeating: 0.5), blended: true, fullbright: true, additive: true,
                        uvOffset: SIMD2(repeating: age * 0.01), transform: transform))
            }
            return layers
        case "spider":
            var parts = [
                part(-4, -4, -8, 8, 8, 8, 0, 15, -3, 32, 4, rotation: head),
                part(-3, -3, -3, 6, 6, 6, 0, 15, 0, 0, 0),
                part(-5, -4, -6, 10, 8, 12, 0, 15, 9, 0, 12),
            ]
            let baseYaws: [Float] = [.pi / 4, .pi / 8, -.pi / 8, -.pi / 4]
            let phaseOffsets: [Float] = [0, .pi, .pi / 2, .pi * 1.5]
            for pair in 0..<4 {
                let spread: Float = pair == 0 || pair == 3 ? .pi / 4 : .pi / 4 * 0.74
                let baseYaw = baseYaws[pair]
                let offset = phaseOffsets[pair]
                let sweep = -cos(stride * 2 + offset) * 0.4 * amplitude
                let lift = abs(sin(stride + offset) * 0.4) * amplitude
                parts.append(
                    part(
                        -15, -1, -1, 16, 2, 2, -4, 15, Float(2 - pair), 18, 0,
                        rotation: SIMD3(0, baseYaw + sweep, -spread + lift)))
                parts.append(
                    part(
                        -1, -1, -1, 16, 2, 2, 4, 15, Float(2 - pair), 18, 0,
                        rotation: SIMD3(0, -baseYaw - sweep, spread - lift)))
            }
            return [
                EntityModelLayer(texture: "mob/spider", parts: parts),
                EntityModelLayer(
                    texture: "mob/spider_eyes", parts: parts, opacity: 0.5, blended: true, fullbright: true),
            ]
        case "wolf":
            let texture =
                entity.angerTicks > 0
                ? "mob/wolf_angry" : (entity.owner == nil ? "mob/wolf" : "mob/wolf_tame")
            var parts = [
                part(-3, -3, -2, 6, 6, 4, -1, 13.5, -7, 0, 0, rotation: head),
                part(-4, -2, -3, 6, 9, 6, 0, 14, 2, 18, 14, rotation: SIMD3(.pi / 2, 0, 0)),
                part(-4, -3, -3, 8, 6, 7, -1, 14, -3, 21, 0, rotation: SIMD3(.pi / 2, 0, 0)),
                part(-1, 0, -1, 2, 8, 2, -2.5, 16, 7, 0, 18, rotation: SIMD3(swing, 0, 0)),
                part(-1, 0, -1, 2, 8, 2, 0.5, 16, 7, 0, 18, rotation: SIMD3(opposite, 0, 0)),
                part(-1, 0, -1, 2, 8, 2, -2.5, 16, -4, 0, 18, rotation: SIMD3(opposite, 0, 0)),
                part(-1, 0, -1, 2, 8, 2, 0.5, 16, -4, 0, 18, rotation: SIMD3(swing, 0, 0)),
                part(
                    -1, 0, -1, 2, 8, 2, -1, 12, 8, 9, 18,
                    rotation: SIMD3(
                        entity.metadata & 2 != 0
                            ? 1.5393804
                            : (entity.owner != nil
                                ? (0.55 - Float(20 - entity.health) * 0.02) * .pi : .pi / 5),
                        entity.metadata & 2 != 0 ? 0 : swing, 0)),
                part(-3, -5, 0, 2, 2, 1, -1, 13.5, -7, 16, 14, rotation: head),
                part(1, -5, 0, 2, 2, 1, -1, 13.5, -7, 16, 14, rotation: head),
                part(-2, 0, -5, 3, 3, 4, -0.5, 13.5, -7, 0, 10, rotation: head),
            ]
            if entity.owner != nil && entity.metadata & 1 != 0 {
                parts[1].pivot = SIMD3(0, 18, 0)
                parts[1].rotation.x = .pi / 4
                parts[2].pivot = SIMD3(-1, 16, -3)
                parts[2].rotation.x = .pi * 0.4
                parts[7].pivot = SIMD3(-1, 21, 6)
                parts[3].pivot = SIMD3(-2.5, 22, 2)
                parts[3].rotation.x = .pi * 1.5
                parts[4].pivot = SIMD3(0.5, 22, 2)
                parts[4].rotation.x = .pi * 1.5
                parts[5].pivot = SIMD3(-2.49, 17, -4)
                parts[5].rotation.x = 5.811947
                parts[6].pivot = SIMD3(0.51, 17, -4)
                parts[6].rotation.x = 5.811947
            }
            func shake(_ offset: Float) -> Float {
                let amount =
                    entity.previousWolfShake + (entity.wolfShakeProgress - entity.previousWolfShake) * partial
                let progress = min(1, max(0, (amount + offset) / 1.8))
                return BetaVisualMath.sine(progress * BetaVisualMath.pi)
                    * BetaVisualMath.sine(progress * BetaVisualMath.pi * 11) * 0.15 * BetaVisualMath.pi
            }
            let headRoll = entity.wolfInterest * 0.15 * .pi + shake(0)
            for index in [0, 8, 9, 10] { parts[index].rotation.z = headRoll }
            parts[2].rotation.z = shake(-0.08)
            parts[1].rotation.z = shake(-0.16)
            parts[7].rotation.z = shake(-0.2)
            let shakeAmount =
                entity.previousWolfShake + (entity.wolfShakeProgress - entity.previousWolfShake) * partial
            let wetShade: Float = entity.wolfWet ? 0.75 + shakeAmount / 2 * 0.25 : 1
            return [EntityModelLayer(texture: texture, parts: parts, tint: SIMD3(repeating: wetShade))]
        case "squid":
            var parts = [part(-6, -8, -6, 12, 16, 12, 0, 8, 0, 0, 0)]
            for index in 0..<8 {
                let angle = Float(index) * .pi * 2 / 8
                parts.append(
                    part(
                        -1, 0, -1, 2, 18, 2, cos(angle) * 5, 15, sin(angle) * 5, 48, 0,
                        rotation: SIMD3(entity.squidTentacleAngle, -angle + .pi / 2, 0)))
            }
            let transform =
                HeldItemGeometry.translation(SIMD3(0, 0.5, 0))
                * HeldItemGeometry.rotation(entity.squidBodyPitch, axis: SIMD3(1, 0, 0))
                * HeldItemGeometry.rotation(entity.squidBodyRotation * 180 / .pi, axis: SIMD3(0, 1, 0))
                * HeldItemGeometry.translation(SIMD3(0, -1.2, 0))
            return [EntityModelLayer(texture: "mob/squid", parts: parts, transform: transform)]
        case "ghast":
            var random = JavaRandom(seed: 1660)
            var parts = [part(-8, -8, -8, 16, 16, 16, 0, 8, 0, 0, 0)]
            for index in 0..<9 {
                let x = (Float(index % 3) - Float(index / 3 % 2) * 0.5 - 0.75) * 5
                let z = (Float(index / 3) - 1) * 5
                parts.append(
                    part(
                        -1, 0, -1, 2, Float(random.nextInt(bound: 7) + 8), 2, x, 15, z, 0, 0,
                        rotation: SIMD3(0.2 * sin(age * 0.3 + Float(index)) + 0.4, 0, 0)))
            }
            let charge = min(1, max(0, Float(entity.specialTicks) / 20))
            let squeeze = 1 / (pow(charge, 5) * 2 + 1)
            let transform = simd_float4x4(
                diagonal: SIMD4((8 + 1 / squeeze) / 9, (8 + squeeze) / 9, (8 + 1 / squeeze) / 9, 1))
            return [
                EntityModelLayer(
                    texture: entity.metadata & 1 != 0 ? "mob/ghast_fire" : "mob/ghast", parts: parts,
                    scale: 4.5, transform: transform)
            ]
        case "slime":
            let scale = Float(max(1, Int(entity.metadata)))
            let squish =
                (entity.previousSquishAmount + (entity.squishAmount - entity.previousSquishAmount) * partial)
                / (scale * 0.5 + 1)
            let squeeze = 1 / (squish + 1)
            let transform = simd_float4x4(diagonal: SIMD4(squeeze, 1 / squeeze, squeeze, 1))
            let inner = [
                part(-3, 17, -3, 6, 6, 6, 0, 0, 0, 0, 16),
                part(-3.25, 18, -3.5, 2, 2, 2, 0, 0, 0, 32, 0),
                part(1.25, 18, -3.5, 2, 2, 2, 0, 0, 0, 32, 4),
                part(0, 21, -3.5, 1, 1, 1, 0, 0, 0, 32, 8),
            ]
            return [
                EntityModelLayer(texture: "mob/slime", parts: inner, scale: scale, transform: transform),
                EntityModelLayer(
                    texture: "mob/slime", parts: [part(-4, 16, -4, 8, 8, 8, 0, 0, 0, 0, 0)],
                    scale: scale, opacity: 1, blended: true, transform: transform),
            ]
        case "boat", "minecart":
            var layer = vehicle(kind: entity.kind)
            let hit = Float(entity.vehicleHitTicks) - partial
            let damage = max(0, Float(entity.vehicleDamage) - partial)
            let rocking =
                hit > 0
                ? BetaVisualMath.sine(hit) * hit * damage / 10 * Float(entity.vehicleForwardDirection) : 0
            layer.transform =
                HeldItemGeometry.translation(SIMD3(0, Float(entity.height) / 2, 0))
                * HeldItemGeometry.rotation(
                    entity.kind == "minecart" ? entity.pitch * 180 / BetaVisualMath.pi : 0,
                    axis: SIMD3(0, 0, 1))
                * HeldItemGeometry.rotation(rocking, axis: SIMD3(1, 0, 0))
            return [layer]
        default: return []
        }
    }

    private static func quadruped(legHeight: Float, swing: Float, opposite: Float, head: SIMD3<Float>)
        -> [EntityModelPart]
    {
        [
            part(-4, -4, -8, 8, 8, 8, 0, 18 - legHeight, -6, 0, 0, rotation: head),
            part(-5, -10, -7, 10, 16, 8, 0, 17 - legHeight, 2, 28, 8, rotation: SIMD3(.pi / 2, 0, 0)),
            part(-2, 0, -2, 4, legHeight, 4, -3, 24 - legHeight, 7, 0, 16, rotation: SIMD3(swing, 0, 0)),
            part(-2, 0, -2, 4, legHeight, 4, 3, 24 - legHeight, 7, 0, 16, rotation: SIMD3(opposite, 0, 0)),
            part(-2, 0, -2, 4, legHeight, 4, -3, 24 - legHeight, -5, 0, 16, rotation: SIMD3(opposite, 0, 0)),
            part(-2, 0, -2, 4, legHeight, 4, 3, 24 - legHeight, -5, 0, 16, rotation: SIMD3(swing, 0, 0)),
        ]
    }

    private static func vehicle(kind: String) -> EntityModelLayer {
        let boat = kind == "boat"
        let width: Float = boat ? 24 : 20
        let length: Float = boat ? 20 : 16
        let height: Float = boat ? 6 : 8
        let floor = part(
            -width / 2, -length / 2 + (boat ? 2 : 0), boat ? -3 : -1,
            width, length - (boat ? 4 : 0), boat ? 4 : 2, 0, 4, 0, 0, boat ? 8 : 10,
            rotation: SIMD3(.pi / 2, 0, 0))
        var parts = [floor]
        if !boat {
            parts.append(
                part(-9, -7, -1, 18, 14, 1, 0, 4.1, 0, 44, 10, rotation: SIMD3(-BetaVisualMath.pi / 2, 0, 0)))
        }
        for index in 0..<4 {
            let x: Float = index == 0 ? -width / 2 + 1 : (index == 1 ? width / 2 - 1 : 0)
            let z: Float = index == 2 ? -length / 2 + 1 : (index == 3 ? length / 2 - 1 : 0)
            let rotation: Float = [.pi * 1.5, .pi / 2, .pi, 0][index]
            parts.append(
                part(
                    -width / 2 + 2, -height - 1, -1, width - 4, height, 2, x, 4, z, 0, 0,
                    rotation: SIMD3(0, rotation, 0)))
        }
        return EntityModelLayer(
            texture: boat ? "item/boat" : "item/cart", parts: parts,
            originY: 0)
    }

    private static func part(
        _ x: Float, _ y: Float, _ z: Float, _ width: Float, _ height: Float, _ depth: Float,
        _ px: Float, _ py: Float, _ pz: Float, _ u: Float, _ v: Float,
        rotation: SIMD3<Float> = .zero, inflation: Float = 0, mirrored: Bool = false
    ) -> EntityModelPart {
        EntityModelPart(
            SIMD3(x, y, z), SIMD3(width, height, depth), at: SIMD3(px, py, pz), uv: SIMD2(u, v),
            rotation: rotation, inflation: inflation, mirrored: mirrored)
    }

    private static let fleeceColors: [SIMD3<Float>] = [
        SIMD3(1, 1, 1), SIMD3(0.95, 0.7, 0.2), SIMD3(0.9, 0.5, 0.85), SIMD3(0.6, 0.7, 0.95),
        SIMD3(0.9, 0.9, 0.2), SIMD3(0.5, 0.8, 0.1), SIMD3(0.95, 0.7, 0.8), SIMD3(0.3, 0.3, 0.3),
        SIMD3(0.6, 0.6, 0.6), SIMD3(0.3, 0.6, 0.7), SIMD3(0.7, 0.4, 0.9), SIMD3(0.2, 0.4, 0.8),
        SIMD3(0.5, 0.4, 0.3), SIMD3(0.4, 0.5, 0.2), SIMD3(0.8, 0.3, 0.3), SIMD3(0.1, 0.1, 0.1),
    ]
}
