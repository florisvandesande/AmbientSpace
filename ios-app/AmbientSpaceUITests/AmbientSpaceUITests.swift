import XCTest

final class AmbientSpaceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(language: String = "en", appearance: String? = nil, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", language]
        app.launchEnvironment["AMBIENTSPACE_TEST_APPEARANCE"] = appearance
        if largeText { app.launchEnvironment["AMBIENTSPACE_TEST_LARGE_TEXT"] = "1" }
        app.launch()
        return app
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testBothPopoversAppearBelowTheirButtons() {
        let app = launch()
        let volume = app.buttons["volumeButton"]
        XCTAssertTrue(volume.waitForExistence(timeout: 5))
        let volumeBottom = volume.frame.maxY
        volume.tap()
        let slider = app.sliders["appVolumeSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(slider.frame.minY, volumeBottom)
        slider.adjust(toNormalizedSliderPosition: 0.25)
        attachScreenshot("volume-below-button")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.07)).tap()

        let timer = app.buttons["timerButton"]
        let timerBottom = timer.frame.maxY
        timer.tap()
        let title = app.staticTexts["Sleep timer"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(title.frame.minY, timerBottom)
        XCTAssertTrue(app.buttons["Start custom timer"].exists)
        attachScreenshot("timer-below-button")
    }

    func testSystemLanguageTranslations() {
        for (language, label) in [
            ("nl", "Kies een omgeving"),
            ("en", "Choose an atmosphere"),
            ("fr", "Choisissez une ambiance"),
            ("de", "Wähle eine Atmosphäre"),
            ("es", "Elige un ambiente"),
            ("it", "Scegli un’atmosfera"),
            ("pt-BR", "Escolha um ambiente"),
        ] {
            let app = launch(language: language)
            XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5), "Missing translation for \(language)")
            attachScreenshot("language-\(language)")
            app.terminate()
        }
    }

    func testWholeTrackRowStartsPlaybackAndExpandsDescription() throws {
        let app = launch()
        let row = app.buttons["trackRow-bos"]
        guard row.waitForExistence(timeout: 3) else {
            throw XCTSkip("The optional forest recording is not bundled.")
        }
        // Tap the trailing part of the row, away from the text and symbol.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.72)).tap()
        XCTAssertTrue(row.label.hasPrefix("Pause "))
        let description = app.staticTexts["trackDescription-bos"]
        XCTAssertTrue(description.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(description.frame.minY, row.frame.minY)
        attachScreenshot("expanded-description")
        row.tap()
        XCTAssertTrue(row.label.hasPrefix("Play "))
        XCTAssertFalse(description.exists)
    }

    func testGradientColorsInLightAppearance() throws {
        try checkGradientColors(appearance: "light")
    }

    func testGradientColorsInDarkAppearance() throws {
        try checkGradientColors(appearance: "dark")
    }

    private func checkGradientColors(appearance: String) throws {
        let app = launch(appearance: appearance)
        defer { app.terminate() }
        guard app.buttons["trackRow-bos"].waitForExistence(timeout: 5) else {
            throw XCTSkip("The optional example recordings are not bundled.")
        }
        // Exercise real playing state silently, without changing system volume.
        app.buttons["volumeButton"].tap()
        let slider = app.sliders["appVolumeSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 3))
        slider.adjust(toNormalizedSliderPosition: 0)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.07)).tap()
        attachScreenshot("colors-\(appearance)-inactive")

        for id in ["bos", "nachtelijke_regen", "regenstorm", "riviertje"] {
            let row = app.buttons["trackRow-\(id)"]
            guard row.exists else { continue }
            row.tap()
            XCTAssertTrue(row.label.hasPrefix("Pause "))
            attachScreenshot("colors-\(appearance)-\(id)-active")
            let description = app.staticTexts["trackDescription-\(id)"]
            XCTAssertTrue(description.waitForExistence(timeout: 3))
            XCTAssertGreaterThanOrEqual(description.frame.minY, row.frame.minY)
            attachScreenshot("colors-\(appearance)-\(id)-expanded")
            row.tap()
            XCTAssertTrue(row.label.hasPrefix("Play "))
        }
    }

    func testGradientColorsWithMaximumTextSize() throws {
        for appearance in ["light", "dark"] {
            let app = launch(appearance: appearance, largeText: true)
            defer { app.terminate() }
            let row = app.buttons["trackRow-bos"]
            guard row.waitForExistence(timeout: 5) else {
                throw XCTSkip("The optional forest recording is not bundled.")
            }
            attachScreenshot("colors-\(appearance)-maximum-text")
            row.tap()
            let description = app.staticTexts["trackDescription-bos"]
            XCTAssertTrue(description.waitForExistence(timeout: 3))
            XCTAssertGreaterThanOrEqual(description.frame.minY, row.frame.minY)
            attachScreenshot("colors-\(appearance)-maximum-text-expanded")
            app.swipeUp()
            attachScreenshot("colors-\(appearance)-maximum-text-scrolled")
        }
    }
}
