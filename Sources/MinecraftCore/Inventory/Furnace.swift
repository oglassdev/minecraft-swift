public enum FurnaceRecipes {
    public static func result(for input: ItemStack) -> ItemStack? { recipes[input.id] }

    public static func burnTime(for fuel: ItemStack?) -> Int {
        guard let fuel, fuel.count > 0 else { return 0 }
        if woodenBlocks.contains(fuel.id) { return 300 }
        switch fuel.id {
        case 6, 280: return 100
        case 263: return 1600
        case 327: return 20000
        default: return 0
        }
    }

    private static let woodenBlocks: Set<UInt16> = [
        5, 17, 25, 47, 53, 54, 58, 63, 64, 68, 72, 84, 85, 95, 96,
    ]
    private static let recipes: [UInt16: ItemStack] = [
        14: ItemStack(id: 266),
        15: ItemStack(id: 265),
        56: ItemStack(id: 264),
        12: ItemStack(id: 20),
        319: ItemStack(id: 320),
        349: ItemStack(id: 350),
        4: ItemStack(id: 1),
        337: ItemStack(id: 336),
        81: ItemStack(id: 351, damage: 2),
        17: ItemStack(id: 263, damage: 1),
    ]
}

public struct FurnaceState: Codable, Equatable, Sendable {
    public var input: ItemStack?
    public var fuel: ItemStack?
    public var output: ItemStack?
    public private(set) var burnTicksRemaining = 0
    public private(set) var currentFuelBurnTicks = 0
    public private(set) var cookTicks = 0

    public init(input: ItemStack? = nil, fuel: ItemStack? = nil, output: ItemStack? = nil) {
        self.input = input
        self.fuel = fuel
        self.output = output
    }

    public init(
        input: ItemStack?, fuel: ItemStack?, output: ItemStack?, burnTicksRemaining: Int, cookTicks: Int
    ) {
        self.input = input
        self.fuel = fuel
        self.output = output
        self.burnTicksRemaining = max(0, burnTicksRemaining)
        self.cookTicks = min(199, max(0, cookTicks))
        currentFuelBurnTicks = FurnaceRecipes.burnTime(for: fuel)
    }

    public var isBurning: Bool { burnTicksRemaining > 0 }

    public var canSmelt: Bool {
        guard let input, input.count > 0, let result = FurnaceRecipes.result(for: input) else { return false }
        guard let output else { return true }
        return output.id == result.id && output.damage == result.damage
            && output.count + result.count <= min(64, output.maximumStackSize)
    }

    /// Advances one 20 Hz game tick, including burning fuel while output is blocked.
    @discardableResult
    public mutating func tick() -> Bool {
        let wasBurning = isBurning
        var changed = false
        if burnTicksRemaining > 0 { burnTicksRemaining -= 1 }
        if burnTicksRemaining == 0 && canSmelt {
            currentFuelBurnTicks = FurnaceRecipes.burnTime(for: fuel)
            burnTicksRemaining = currentFuelBurnTicks
            if burnTicksRemaining > 0, var fuel {
                fuel.count -= 1
                self.fuel = fuel.count > 0 ? fuel : nil
                changed = true
            }
        }
        if isBurning && canSmelt {
            cookTicks += 1
            if cookTicks == 200 {
                cookTicks = 0
                smelt()
                changed = true
            }
        } else {
            cookTicks = 0
        }
        return changed || wasBurning != isBurning
    }

    private mutating func smelt() {
        guard var input, let result = FurnaceRecipes.result(for: input) else { return }
        if var output {
            output.count += result.count
            self.output = output
        } else {
            output = result
        }
        input.count -= 1
        self.input = input.count > 0 ? input : nil
    }
}
