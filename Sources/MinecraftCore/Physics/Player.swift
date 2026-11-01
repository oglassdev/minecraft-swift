import Foundation

public struct PlayerInput: Sendable {
    public var forward: Float
    public var strafe: Float
    public var jump: Bool
    public var sneak: Bool

    public init(forward: Float = 0, strafe: Float = 0, jump: Bool = false, sneak: Bool = false) {
        self.forward = forward
        self.strafe = strafe
        self.jump = jump
        self.sneak = sneak
    }
}

public struct Player: Sendable {
    public static let ticksPerSecond = 20
    public static let width = Double(Float(0.6))
    public static let height = Double(Float(1.8))
    public private(set) var position: SIMD3<Double>
    public private(set) var velocity = SIMD3<Double>.zero
    public private(set) var onGround = false
    public private(set) var health: Int
    public private(set) var air = 300
    public private(set) var isInWater = false
    public private(set) var isInLava = false
    public private(set) var isSneaking = false
    public private(set) var isCollidingHorizontally = false
    public var localDamageEnabled = true
    public var difficulty = 2
    public var isMounted = false
    private var fallDistance: Float = 0
    private var cameraSmoothing: Float = 0
    private var hurtResistance = 0
    private var lastDamage = 0
    private var fireTicks = 0
    private var combatInventory = PlayerInventory()
    private var armorDamageRemainder = 0
    private var walkedDistance: Float = 0
    private var nextStepDistance = 1
    private var stepEvents: [BlockEvent] = []

    public init(position: SIMD3<Double>, health: Int = 20) {
        self.position = position
        self.health = min(max(health, 0), 20)
    }

    public var bounds: AxisAlignedBox {
        let radius = Self.width / 2
        return AxisAlignedBox(
            min: position - SIMD3(radius, 0, radius),
            max: position + SIMD3(radius, Self.height, radius)
        )
    }

    public var eyePosition: SIMD3<Float> {
        SIMD3(Float(eyePositionDouble.x), Float(eyePositionDouble.y), Float(eyePositionDouble.z))
    }

    public var eyePositionDouble: SIMD3<Double> {
        position + SIMD3(0, Double(Float(1.62)) - Double(cameraSmoothing), 0)
    }

    public mutating func teleport(to position: SIMD3<Double>) {
        self.position = position
        velocity = .zero
        onGround = false
        fallDistance = 0
        cameraSmoothing = 0
    }

    public mutating func addVelocity(_ impulse: SIMD3<Double>) { velocity += impulse }

    mutating func knockBack(from origin: SIMD3<Double>) {
        let delta = position - origin
        let length = Double(Float(sqrt(delta.x * delta.x + delta.z * delta.z)))
        velocity /= 2
        if length > 0 {
            velocity.x += delta.x / length * Double(Float(0.4))
            velocity.z += delta.z / length * Double(Float(0.4))
        }
        velocity.y = min(velocity.y + Double(Float(0.4)), Double(Float(0.4)))
    }

    public mutating func displace(by movement: SIMD3<Double>, world: BlockWorld) {
        move(movement, sneaking: false, world: world)
    }

    public mutating func drainStepEvents() -> [BlockEvent] {
        let events = stepEvents
        stepEvents.removeAll(keepingCapacity: true)
        return events
    }

    public mutating func heal(_ amount: Int) {
        if health > 0 {
            health = min(health + max(amount, 0), 20)
            hurtResistance = 10
        }
    }

    public mutating func setHealthFromServer(_ amount: Int) { health = min(max(amount, 0), 20) }

    public mutating func strikeByLightning(inventory: inout PlayerInventory) {
        damage(5, inventory: &inventory)
        if localDamageEnabled { fireTicks = fireTicks <= 0 ? 300 : fireTicks + 1 }
    }

    @discardableResult
    public mutating func damage(_ amount: Int, source: PlayerDamageSource = .environment) -> Bool {
        guard localDamageEnabled, amount > 0, health > 0 else { return false }
        var amount = amount
        if source != .environment {
            switch difficulty {
            case 0: amount = 0
            case 1: amount = amount / 3 + 1
            case 3: amount = amount * 3 / 2
            default: break
            }
        }
        guard amount > 0 else { return false }
        let applied: Int
        if hurtResistance > 10 {
            guard amount > lastDamage else { return false }
            applied = amount - lastDamage
        } else {
            applied = amount
            hurtResistance = 20
        }
        lastDamage = amount
        let weighted = applied * (25 - combatInventory.armorProtection) + armorDamageRemainder
        combatInventory.damageArmor(by: applied)
        health = max(0, health - weighted / 25)
        armorDamageRemainder = weighted % 25
        return true
    }

    @discardableResult
    public mutating func damage(
        _ amount: Int, source: PlayerDamageSource = .environment, inventory: inout PlayerInventory
    ) -> Bool {
        beginArmorUpdate(from: inventory)
        let accepted = damage(amount, source: source)
        endArmorUpdate(in: &inventory)
        return accepted
    }

    public mutating func tick(
        input: PlayerInput, yaw: Float, world: BlockWorld, inventory: inout PlayerInventory
    ) {
        beginArmorUpdate(from: inventory)
        tick(input: input, yaw: yaw, world: world)
        endArmorUpdate(in: &inventory)
    }

    mutating func beginArmorUpdate(from inventory: PlayerInventory) {
        combatInventory.armor = inventory.armor
    }
    func endArmorUpdate(in inventory: inout PlayerInventory) { inventory.armor = combatInventory.armor }

    /// Advances exactly one Beta simulation tick. Yaw uses the camera's radians convention.
    public mutating func tick(input: PlayerInput, yaw: Float, world: BlockWorld) {
        if hurtResistance > 0 { hurtResistance -= 1 }
        isSneaking = input.sneak
        if input.sneak && cameraSmoothing < 0.2 { cameraSmoothing = 0.2 }
        let water = FluidPhysics.waterContact(
            in: world, bounds: bounds.expanded(by: SIMD3(-0.001, -0.401, -0.001)))
        isInWater = water.touching
        velocity += water.acceleration
        isInLava = intersectsFluid(world, bounds: bounds.expanded(by: SIMD3(-0.1, -0.4, -0.1)), water: false)
        if isInWater {
            fallDistance = 0
            fireTicks = 0
        }
        if isSuffocating(world) { damage(1) }
        let active = health > 0
        if input.jump && active {
            if isInWater || isInLava {
                velocity.y += Double(Float(0.04))
            } else if onGround {
                velocity.y = Double(Float(0.42))
            }
        }

        let sneakScale: Float = input.sneak ? 0.3 : 1
        let forward = active ? input.forward * sneakScale * 0.98 : 0
        let strafe = active ? input.strafe * sneakScale * 0.98 : 0
        let previousY = position.y
        if isInWater || isInLava {
            accelerate(forward: forward, strafe: strafe, speed: 0.02, yaw: yaw)
            move(velocity, sneaking: input.sneak, world: world)
            velocity *= isInWater ? Double(Float(0.8)) : 0.5
            velocity.y -= 0.02
            let escape = SIMD3(
                velocity.x, velocity.y + Double(Float(0.6)) - position.y + previousY, velocity.z)
            let escapeBounds = bounds.offset(by: escape)
            if isCollidingHorizontally,
                BlockCollision.boxes(in: world, intersecting: escapeBounds).isEmpty,
                !intersectsFluid(world, bounds: escapeBounds, water: true),
                !intersectsFluid(world, bounds: escapeBounds, water: false)
            {
                velocity.y = Double(Float(0.3))
            }
        } else {
            let friction = groundFriction(world)
            let acceleration: Float = onGround ? 0.1 * (0.16277136 / (friction * friction * friction)) : 0.02
            accelerate(forward: forward, strafe: strafe, speed: acceleration, yaw: yaw)
            let ladder = isOnLadder(world)
            if ladder {
                let horizontalLimit = Double(Float(0.15))
                velocity.x = min(max(velocity.x, -horizontalLimit), horizontalLimit)
                velocity.z = min(max(velocity.z, -horizontalLimit), horizontalLimit)
                velocity.y = max(velocity.y, -0.15)
                if input.sneak && velocity.y < 0 { velocity.y = 0 }
                fallDistance = 0
            }
            move(velocity, sneaking: input.sneak, world: world)
            if isCollidingHorizontally && isOnLadder(world) { velocity.y = 0.2 }
            velocity.y = (velocity.y - 0.08) * Double(Float(0.98))
            velocity.x *= Double(friction)
            velocity.z *= Double(friction)
        }
        applyBlockEffects(world)
        updateBreathing(world)
        if localDamageEnabled && position.y < -64 { health = 0 }
    }

    private mutating func accelerate(forward: Float, strafe: Float, speed: Float, yaw: Float) {
        var magnitude = sqrt(strafe * strafe + forward * forward)
        guard magnitude >= 0.01 else { return }
        magnitude = speed / max(magnitude, 1)
        let forward = forward * magnitude
        let strafe = -strafe * magnitude
        let radians = (yaw * 180 / BetaMath.pi + 180) * BetaMath.pi / 180
        let sine = Self.sines[Int(radians * 10430.378) & 65535]
        let cosine = Self.sines[Int(radians * 10430.378 + 16384) & 65535]
        velocity.x += Double(strafe * cosine - forward * sine)
        velocity.z += Double(forward * cosine + strafe * sine)
    }

    private func groundFriction(_ world: BlockWorld) -> Float {
        guard onGround else { return 0.91 }
        let below = BlockPosition(
            Int(floor(position.x)), Int(floor(bounds.min.y)) - 1, Int(floor(position.z)))
        guard let block = world[below] else { return 0.54600006 }
        return (block.rawValue == 79 ? Float(0.98) : Float(0.6)) * 0.91
    }

    private func isOnLadder(_ world: BlockWorld) -> Bool {
        world[BlockPosition(Int(floor(position.x)), Int(floor(bounds.min.y)), Int(floor(position.z)))]?
            .rawValue == 65
    }

    private mutating func move(_ proposed: SIMD3<Double>, sneaking: Bool, world: BlockWorld) {
        cameraSmoothing *= 0.4
        var movement = proposed
        let originalBox = bounds
        let silentStep = onGround && sneaking
        if onGround && sneaking {
            for axis in [0, 2] {
                var offset = SIMD3<Double>(0, -1, 0)
                offset[axis] = movement[axis]
                while movement[axis] != 0,
                    BlockCollision.boxes(in: world, intersecting: originalBox.offset(by: offset)).isEmpty
                {
                    movement[axis] =
                        abs(movement[axis]) < 0.05 ? 0 : movement[axis] + (movement[axis] > 0 ? -0.05 : 0.05)
                    offset[axis] = movement[axis]
                }
            }
        }
        if touchesBlock(world, id: 30) {
            movement *= SIMD3(0.25, Double(Float(0.05)), 0.25)
            velocity = .zero
        }
        let requested = movement
        var resolved = Self.resolve(movement, bounds: originalBox, world: world)
        let grounded = onGround || (movement.y != resolved.movement.y && movement.y < 0)
        if grounded, (onGround && sneaking) || cameraSmoothing < 0.05,
            movement.x != resolved.movement.x || movement.z != resolved.movement.z
        {
            let raised = Self.resolve(SIMD3(movement.x, 0.5, movement.z), bounds: originalBox, world: world)
            let obstacles = BlockCollision.boxes(
                in: world, intersecting: originalBox.swept(by: SIMD3(movement.x, 0.5, movement.z)))
            var down = -0.5
            for obstacle in obstacles { down = obstacle.clip(down, axis: 1, moving: raised.bounds) }
            let steppedMovement = raised.movement + SIMD3(0, down, 0)
            if steppedMovement.x * steppedMovement.x + steppedMovement.z * steppedMovement.z
                > resolved.movement.x * resolved.movement.x + resolved.movement.z * resolved.movement.z
            {
                resolved = (steppedMovement, raised.bounds.offset(by: SIMD3(0, down, 0)))
                let fraction = resolved.bounds.min.y - Double(Int(resolved.bounds.min.y))
                if fraction > 0 { cameraSmoothing += Float(fraction + 0.01) }
            }
        }
        movement = resolved.movement
        position = SIMD3(
            (resolved.bounds.min.x + resolved.bounds.max.x) / 2,
            resolved.bounds.min.y, (resolved.bounds.min.z + resolved.bounds.max.z) / 2)
        isCollidingHorizontally = requested.x != movement.x || requested.z != movement.z
        onGround = requested.y != movement.y && requested.y < 0
        if onGround {
            if fallDistance > 3 { damage(Int(ceil(fallDistance - 3))) }
            fallDistance = 0
        } else if movement.y < 0 {
            fallDistance = Float(Double(fallDistance) - movement.y)
        }
        for axis in 0..<3 where requested[axis] != movement[axis] { velocity[axis] = 0 }
        if !silentStep && !isMounted {
            let x = position.x - (originalBox.min.x + originalBox.max.x) / 2
            let z = position.z - (originalBox.min.z + originalBox.max.z) / 2
            walkedDistance = Float(Double(walkedDistance) + Double(Float(sqrt(x * x + z * z))) * 0.6)
            let cell = BlockPosition(
                Int(floor(position.x)), Int(floor(position.y - Double(Float(0.2)))), Int(floor(position.z)))
            if walkedDistance > Float(nextStepDistance), world[cell] != nil {
                nextStepDistance += 1
                stepEvents.append(.stepped(at: cell, position: eyePositionDouble))
            }
        }
    }

    private static func resolve(_ movement: SIMD3<Double>, bounds: AxisAlignedBox, world: BlockWorld)
        -> (movement: SIMD3<Double>, bounds: AxisAlignedBox)
    {
        let obstacles = BlockCollision.boxes(in: world, intersecting: bounds.swept(by: movement))
        var movement = movement
        var bounds = bounds
        for axis in [1, 0, 2] {
            for obstacle in obstacles {
                movement[axis] = obstacle.clip(movement[axis], axis: axis, moving: bounds)
            }
            var offset = SIMD3<Double>.zero
            offset[axis] = movement[axis]
            bounds = bounds.offset(by: offset)
        }
        return (movement, bounds)
    }

    private func intersectsFluid(_ world: BlockWorld, bounds: AxisAlignedBox, water: Bool) -> Bool {
        for x in Int(floor(bounds.min.x))...Int(floor(bounds.max.x)) {
            for y in Int(floor(bounds.min.y))...Int(floor(bounds.max.y)) {
                for z in Int(floor(bounds.min.z))...Int(floor(bounds.max.z)) {
                    guard let block = world[BlockPosition(x, y, z)] else { continue }
                    if water
                        ? (block.rawValue == 8 || block.rawValue == 9)
                        : (block.rawValue == 10 || block.rawValue == 11)
                    {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func touchesBlock(_ world: BlockWorld, id: UInt8) -> Bool {
        let box = bounds.expanded(by: SIMD3(repeating: -0.001))
        for x in Int(floor(box.min.x))...Int(floor(box.max.x)) {
            for y in Int(floor(box.min.y))...Int(floor(box.max.y)) {
                for z in Int(floor(box.min.z))...Int(floor(box.max.z)) {
                    if world[BlockPosition(x, y, z)]?.rawValue == id { return true }
                }
            }
        }
        return false
    }

    private mutating func applyBlockEffects(_ world: BlockWorld) {
        if touchesBlock(world, id: 88) {
            velocity.x *= 0.4
            velocity.z *= 0.4
        }
        if touchesBlock(world, id: 81) { damage(1) }
        if isInLava {
            damage(4)
            fireTicks = 600
            fallDistance *= 0.5
        } else if touchesBlock(world, id: 51) {
            damage(1)
            if fireTicks == 0 { fireTicks = 300 }
        }
        if fireTicks > 0 {
            if fireTicks % 20 == 0 { damage(1) }
            fireTicks -= 1
        }
    }

    private mutating func updateBreathing(_ world: BlockWorld) {
        let eye = eyePositionDouble
        let cell = BlockPosition(Int(floor(eye.x)), Int(floor(eye.y)), Int(floor(eye.z)))
        if let state = world.state(at: cell), state.kind.rawValue == 8 || state.kind.rawValue == 9 {
            let level = state.metadata >= 8 ? 0 : Int(state.metadata)
            let surface = Double(cell.y + 1) - Double(Float(level + 1) / 9 - 0.11111111)
            if eye.y < surface {
                air -= 1
                if air == -20 {
                    air = 0
                    damage(2)
                }
                fireTicks = 0
                return
            }
        }
        air = 300
    }

    private func isSuffocating(_ world: BlockWorld) -> Bool {
        let eye = eyePositionDouble
        for corner in 0..<8 {
            let x = Float((corner & 1)) - 0.5
            let y = Float((corner >> 1) & 1) - 0.5
            let z = Float((corner >> 2) & 1) - 0.5
            let sample =
                eye
                + SIMD3(
                    Double(x * Float(Self.width) * 0.9), Double(y * 0.1), Double(z * Float(Self.width) * 0.9))
            if world[BlockPosition(Int(floor(sample.x)), Int(floor(sample.y)), Int(floor(sample.z)))]?
                .isOpaque == true
            {
                return true
            }
        }
        return false
    }

    private static let sines: [Float] = (0..<65536).map { Float(sin(Double($0) * .pi * 2 / 65536)) }
}
