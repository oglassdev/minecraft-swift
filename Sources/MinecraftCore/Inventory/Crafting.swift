public struct RecipeIngredient: Equatable, Sendable {
    public let id: UInt16
    public let damage: UInt16?

    public init(id: UInt16, damage: UInt16? = nil) {
        self.id = id
        self.damage = damage
    }

    func matches(_ stack: ItemStack?) -> Bool {
        guard let stack, stack.count > 0, stack.id == id else { return false }
        return damage == nil || stack.damage == damage
    }
}

public struct CraftingMatch: Sendable {
    public let result: ItemStack
    public let consumedSlots: [Int]
}

public struct CraftingGrid: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int
    public var slots: [ItemStack?]

    public init(width: Int = 2, height: Int = 2) {
        precondition((1...3).contains(width) && (1...3).contains(height))
        self.width = width
        self.height = height
        slots = Array(repeating: nil, count: width * height)
    }

    public var result: ItemStack? { CraftingRecipes.match(self)?.result }

    public mutating func craft() -> ItemStack? {
        guard let match = CraftingRecipes.match(self) else { return nil }
        for index in match.consumedSlots {
            guard var stack = slots[index] else { continue }
            stack.count -= 1
            if stack.count > 0 {
                slots[index] = stack
            } else if let container = stack.definition?.containerItemID {
                slots[index] = ItemStack(id: container)
            } else {
                slots[index] = nil
            }
        }
        return match.result
    }
}

public struct CraftingRecipe: Sendable {
    public enum Shape: Sendable {
        case shaped(width: Int, height: Int, ingredients: [RecipeIngredient?])
        case shapeless([RecipeIngredient])
    }

    public let result: ItemStack
    public let shape: Shape

    func match(_ grid: CraftingGrid) -> CraftingMatch? {
        switch shape {
        case .shaped(let width, let height, let ingredients):
            guard width <= grid.width, height <= grid.height else { return nil }
            for x in 0...(grid.width - width) {
                for y in 0...(grid.height - height) {
                    for mirrored in [true, false] {
                        var consumed: [Int] = []
                        var valid = true
                        for row in 0..<grid.height {
                            for column in 0..<grid.width {
                                let slot = column + row * grid.width
                                let localX = column - x
                                let localY = row - y
                                var ingredient: RecipeIngredient?
                                if (0..<width).contains(localX) && (0..<height).contains(localY) {
                                    let ingredientX = mirrored ? width - localX - 1 : localX
                                    ingredient = ingredients[ingredientX + localY * width]
                                }
                                if let ingredient {
                                    if ingredient.matches(grid.slots[slot]) {
                                        consumed.append(slot)
                                    } else {
                                        valid = false
                                    }
                                } else if grid.slots[slot]?.isEmpty == false {
                                    valid = false
                                }
                            }
                        }
                        if valid { return CraftingMatch(result: result, consumedSlots: consumed) }
                    }
                }
            }
            return nil
        case .shapeless(let ingredients):
            var unmatched = ingredients
            var consumed: [Int] = []
            for (slot, stack) in grid.slots.enumerated() where stack?.isEmpty == false {
                guard let index = unmatched.firstIndex(where: { $0.matches(stack) }) else { return nil }
                unmatched.remove(at: index)
                consumed.append(slot)
            }
            return unmatched.isEmpty ? CraftingMatch(result: result, consumedSlots: consumed) : nil
        }
    }
}

public enum CraftingRecipes {
    public static func match(_ grid: CraftingGrid) -> CraftingMatch? {
        guard grid.slots.count == grid.width * grid.height else { return nil }
        for recipe in all {
            if let match = recipe.match(grid) { return match }
        }
        return nil
    }
}
