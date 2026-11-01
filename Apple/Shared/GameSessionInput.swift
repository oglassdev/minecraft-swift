import MinecraftCore

extension GameSession {
    func togglePerspective() { thirdPerson.toggle() }

    func toggleSmoothCamera() {
        smoothCamera.toggle()
        mouseFilterX = BetaMouseFilter()
        mouseFilterY = BetaMouseFilter()
    }

    func lookMouse(horizontal: Float, vertical: Float) {
        mouseDelta += SIMD2(horizontal, vertical)
    }

    func processMouseLook() {
        let sensitivity = options.mouseSensitivity * 0.6 + 0.2
        let gain = sensitivity * sensitivity * sensitivity * 8
        var delta = mouseDelta * gain
        mouseDelta = .zero
        if smoothCamera {
            delta.x = mouseFilterX.filter(delta.x, factor: 0.05 * gain)
            delta.y = mouseFilterY.filter(delta.y, factor: 0.05 * gain)
        }
        let radians = Float(0.15 * Double.pi / 180)
        camera.look(
            horizontal: delta.x * radians,
            vertical: -delta.y * radians * (options.invertY ? -1 : 1))
    }

    func secondaryAction(isPressed: Bool) {
        if isPressed && !secondaryPressed {
            secondaryAction()
            lastSecondaryTick = tickCount
        }
        secondaryPressed = isPressed
    }
}
