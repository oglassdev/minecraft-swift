import Foundation

public struct GameEntity: Identifiable, Codable, Sendable {
    public var id: Int64
    public var kind: String
    public var position: SIMD3<Double>
    public var previousPosition: SIMD3<Double>
    public var velocity: SIMD3<Double>
    public var yaw: Float = 0
    public var pitch: Float = 0
    public var width: Double
    public var height: Double
    public var health: Int
    public var itemStack: ItemStack?
    public var ageTicks = 0
    public var onGround = false
    public var isCollidingHorizontally = false
    public var idleTicks = 0
    public var lookTicks = 0
    public var yawVelocity: Float = 0
    public var aiForward: Float = 0
    public var aiStrafe: Float = 0
    public var movementCooldown = 0
    public var targetRefreshTicks = 0
    var walkedDistance: Float = 0
    var nextStepDistance = 1
    var stepEvents: [BlockPosition] = []
    public var metadata: UInt8 = 0
    public var fuseTicks = 0
    public var attackCooldown = 0
    public var pickupDelay = 0
    public var air = 300
    public var fireTicks = 0
    public var fallDistance: Float = 0
    public var hurtTicks = 0
    public var lastDamage = 0
    public var deathTicks = 0
    public var lootDropped = false
    public var angerTicks = 0
    public var targetPosition: SIMD3<Double>?
    public var targetEntityID: Int64?
    public var specialTicks = 0
    public var owner: String?
    public var riderID: Int64?
    public var fallingBlock: BlockState?
    public var inGround = false
    public var stuckBlock: BlockPosition?
    public var stuckState: BlockState?
    public var ticksInGround = 0
    public var projectileOwner: Int64?
    public var acceleration = SIMD3<Double>.zero
    public var path: [BlockPosition] = []
    public var pathIndex = 0
    public var contents: [ItemStack?] = []
    public var fuelTicks = 0
    public var pushDirection = SIMD2<Double>.zero
    public var remotePosition: SIMD3<Double>?
    public var remoteYaw: Float?
    public var remotePitch: Float?
    public var remoteTicks = 0
    public var remoteFlags: UInt8 = 0
    public var effectSeed: Int64 = 0
    public var lightningState = 2
    public var lightningFlashes = 0
    public var hookedEntityID: Int64?
    public var biteTicks = 0
    public var paintingMotive: String?
    public var paintingAnchor: BlockPosition?
    public var paintingFacing: UInt8 = 0
    public var squidPhase: Float = 0
    public var squidPhaseVelocity: Float = 0.1
    public var squidPropulsion: Float = 0
    public var squidRotationSpeed: Float = 0
    public var squidTentacleAngle: Float = 0
    public var squidBodyRotation: Float = 0
    public var squidBodyPitch: Float = 0
    public var squidYaw: Float = 0
    public var squidDirection = SIMD3<Float>.zero
    public var wolfWet = false
    public var wolfShaking = false
    public var wolfShakeProgress: Float = 0
    public var previousWolfShake: Float = 0
    public var wolfInterest: Float = 0
    var pendingPigFall: Float?

    public init(id: Int64, kind: String, position: SIMD3<Double>, velocity: SIMD3<Double> = .zero) {
        self.id = id
        self.kind = Self.canonicalKind(kind)
        self.position = position
        self.previousPosition = position
        self.velocity = velocity
        itemStack = nil
        let dimensions: (Float, Float, Int)
        switch self.kind {
        case "pig": dimensions = (0.9, 0.9, 10)
        case "sheep", "cow": dimensions = (0.9, 1.3, 10)
        case "chicken": dimensions = (0.3, 0.4, 4)
        case "squid": dimensions = (0.95, 0.95, 10)
        case "spider": dimensions = (1.4, 0.9, 20)
        case "wolf": dimensions = (0.8, 0.8, 8)
        case "slime": dimensions = (0.6, 0.6, 1)
        case "ghast": dimensions = (4, 4, 10)
        case "item": dimensions = (0.25, 0.25, 5)
        case "primedTnt", "fallingSand": dimensions = (0.98, 0.98, 1)
        case "arrow": dimensions = (0.5, 0.5, 1)
        case "snowball", "egg", "fishingHook": dimensions = (0.25, 0.25, 1)
        case "painting": dimensions = (1, 1, 1)
        case "fireball": dimensions = (1, 1, 1)
        case "lightningBolt": dimensions = (0, 0, 1)
        case "boat": dimensions = (1.5, 0.6, 5)
        case "minecart": dimensions = (0.98, 0.7, 5)
        default: dimensions = (0.6, 1.8, 20)
        }
        width = Double(dimensions.0)
        height = Double(dimensions.1)
        health = dimensions.2
        if self.kind == "primedTnt" { fuseTicks = 80 }
        if self.kind == "fallingSand" { fallingBlock = BlockState(.sand) }
    }

    public var bounds: AxisAlignedBox {
        if kind == "painting", let anchor = paintingAnchor,
            let motive = BetaPainting.motive(named: paintingMotive ?? "Kebab")
        {
            return BetaPainting.bounds(anchor: anchor, direction: paintingFacing, motive: motive)
        }
        return AxisAlignedBox(
            min: position - SIMD3(width / 2, 0, width / 2),
            max: position + SIMD3(width / 2, height, width / 2))
    }

    public var isLiving: Bool {
        switch kind {
        case "player", "pig", "sheep", "cow", "chicken", "squid", "wolf", "slime", "ghast",
            "zombie", "skeleton", "creeper", "spider", "pigZombie":
            true
        default: false
        }
    }

    var eyePosition: SIMD3<Double> {
        position + SIMD3(0, Double(Float(height) * (kind == "wolf" ? Float(0.8) : Float(0.85))), 0)
    }

    public var isHostile: Bool {
        switch kind {
        case "zombie", "skeleton", "creeper", "spider", "slime", "ghast": true
        case "pigZombie": angerTicks > 0
        case "wolf": angerTicks > 0 || metadata & 2 != 0
        default: false
        }
    }

    static func canonicalKind(_ kind: String) -> String {
        switch kind.replacingOccurrences(of: "_", with: "").lowercased() {
        case "pigzombie", "zombiepigman": "pigZombie"
        case "primedtnt", "tntprimed", "tnt": "primedTnt"
        case "fallingsand", "fallingblock": "fallingSand"
        case "lightningbolt", "lightning": "lightningBolt"
        case "fishinghook", "fishhook", "fishingbobber": "fishingHook"
        default: kind.lowercased()
        }
    }
}
