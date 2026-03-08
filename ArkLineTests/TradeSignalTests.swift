import XCTest
@testable import ArkLine

final class TradeSignalTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeSignal(
        signalType: SignalType = .sell,
        status: SignalStatus = .triggered,
        entryLow: Double = 65_800,
        entryHigh: Double = 66_700,
        entryMid: Double = 66_250,
        target1: Double? = 64_688,
        target2: Double? = 63_000,
        stopLoss: Double = 67_561,
        rr: Double = 1.2,
        risk1r: Double? = 1_311,
        t1PnlPct: Double? = nil,
        runnerPnlPct: Double? = nil,
        outcome: SignalOutcome? = nil,
        outcomePct: Double? = nil,
        durationHours: Int? = nil,
        generatedAt: Date = Date(),
        triggeredAt: Date? = Date(),
        t1HitAt: Date? = nil,
        closedAt: Date? = nil,
        expiresAt: Date? = Date().addingTimeInterval(72 * 3600)
    ) -> TradeSignal {
        TradeSignal(
            id: UUID(),
            asset: "BTC",
            signalType: signalType,
            status: status,
            entryZoneLow: entryLow,
            entryZoneHigh: entryHigh,
            entryPriceMid: entryMid,
            confluenceZoneId: nil,
            target1: target1,
            target2: target2,
            stopLoss: stopLoss,
            riskRewardRatio: rr,
            invalidationNote: nil,
            btcRiskScore: 0.35,
            fearGreedIndex: 32,
            macroRegime: "Risk-Off",
            coinbaseRanking: 150,
            arklineScore: 42,
            bounceConfirmed: true,
            confirmationDetails: ConfirmationDetails(wickRejection: true, volumeSpike: false, consecutiveCloses: nil),
            bestPrice: nil,
            runnerStop: nil,
            runnerExitPrice: nil,
            risk1r: risk1r,
            t1PnlPct: t1PnlPct,
            runnerPnlPct: runnerPnlPct,
            emaTrendAligned: true,
            outcome: outcome,
            outcomePct: outcomePct,
            durationHours: durationHours,
            generatedAt: generatedAt,
            triggeredAt: triggeredAt,
            t1HitAt: t1HitAt,
            closedAt: closedAt,
            expiresAt: expiresAt,
            briefingText: nil
        )
    }

    // MARK: - SignalType Tests

    func testSignalType_isBuy() {
        XCTAssertTrue(SignalType.buy.isBuy)
        XCTAssertTrue(SignalType.strongBuy.isBuy)
        XCTAssertFalse(SignalType.sell.isBuy)
        XCTAssertFalse(SignalType.strongSell.isBuy)
    }

    func testSignalType_isStrong() {
        XCTAssertTrue(SignalType.strongBuy.isStrong)
        XCTAssertTrue(SignalType.strongSell.isStrong)
        XCTAssertFalse(SignalType.buy.isStrong)
        XCTAssertFalse(SignalType.sell.isStrong)
    }

    func testSignalType_displayName() {
        XCTAssertEqual(SignalType.strongBuy.displayName, "Strong Long")
        XCTAssertEqual(SignalType.buy.displayName, "Long Setup")
        XCTAssertEqual(SignalType.strongSell.displayName, "Strong Short")
        XCTAssertEqual(SignalType.sell.displayName, "Short Setup")
    }

    func testSignalType_rawValues() {
        XCTAssertEqual(SignalType.strongBuy.rawValue, "strong_buy")
        XCTAssertEqual(SignalType.buy.rawValue, "buy")
        XCTAssertEqual(SignalType.strongSell.rawValue, "strong_sell")
        XCTAssertEqual(SignalType.sell.rawValue, "sell")
    }

    // MARK: - SignalStatus Tests

    func testSignalStatus_isLive() {
        XCTAssertTrue(SignalStatus.active.isLive)
        XCTAssertTrue(SignalStatus.triggered.isLive)
        XCTAssertFalse(SignalStatus.invalidated.isLive)
        XCTAssertFalse(SignalStatus.targetHit.isLive)
        XCTAssertFalse(SignalStatus.expired.isLive)
    }

    func testSignalStatus_displayName() {
        XCTAssertEqual(SignalStatus.active.displayName, "Watching")
        XCTAssertEqual(SignalStatus.triggered.displayName, "In Play")
        XCTAssertEqual(SignalStatus.invalidated.displayName, "Stopped Out")
        XCTAssertEqual(SignalStatus.targetHit.displayName, "Target Hit")
        XCTAssertEqual(SignalStatus.expired.displayName, "Expired")
    }

    func testSignalStatus_rawValues() {
        XCTAssertEqual(SignalStatus.targetHit.rawValue, "target_hit")
        XCTAssertEqual(SignalStatus.active.rawValue, "active")
    }

    // MARK: - Computed Property Tests

    func testEntryPctFromTarget1_sellSignal() {
        let signal = makeSignal(entryMid: 66_250, target1: 64_688)
        let pct = signal.entryPctFromTarget1!
        // (64688 - 66250) / 66250 * 100 = -2.356%
        XCTAssertEqual(pct, -2.356, accuracy: 0.01)
    }

    func testEntryPctFromTarget1_buySignal() {
        let signal = makeSignal(signalType: .buy, entryMid: 60_000, target1: 63_000)
        let pct = signal.entryPctFromTarget1!
        // (63000 - 60000) / 60000 * 100 = 5.0%
        XCTAssertEqual(pct, 5.0, accuracy: 0.01)
    }

    func testEntryPctFromTarget1_nilWhenNoTarget() {
        let signal = makeSignal(target1: nil)
        XCTAssertNil(signal.entryPctFromTarget1)
    }

    func testEntryPctFromTarget2_nilWhenNoTarget() {
        let signal = makeSignal(target2: nil)
        XCTAssertNil(signal.entryPctFromTarget2)
    }

    func testEntryPctFromTarget2_sellSignal() {
        let signal = makeSignal(entryMid: 66_250, target2: 63_000)
        let pct = signal.entryPctFromTarget2!
        // (63000 - 66250) / 66250 * 100 = -4.906%
        XCTAssertEqual(pct, -4.906, accuracy: 0.01)
    }

    func testStopLossPct_sellSignal() {
        let signal = makeSignal(entryMid: 66_250, stopLoss: 67_561)
        let pct = signal.stopLossPct
        // (67561 - 66250) / 66250 * 100 = 1.978%
        XCTAssertEqual(pct, 1.978, accuracy: 0.01)
    }

    func testStopLossPct_buySignal() {
        let signal = makeSignal(signalType: .buy, entryMid: 60_000, stopLoss: 58_500)
        let pct = signal.stopLossPct
        // (58500 - 60000) / 60000 * 100 = -2.5%
        XCTAssertEqual(pct, -2.5, accuracy: 0.01)
    }

    // MARK: - Phase Detection Tests

    func testIsT1Hit_trueWhenT1HitAtSet() {
        let signal = makeSignal(t1HitAt: Date())
        XCTAssertTrue(signal.isT1Hit)
    }

    func testIsT1Hit_falseWhenNil() {
        let signal = makeSignal(t1HitAt: nil)
        XCTAssertFalse(signal.isT1Hit)
    }

    func testIsRunnerPhase_trueWhenT1HitAndTriggered() {
        let signal = makeSignal(status: .triggered, t1HitAt: Date())
        XCTAssertTrue(signal.isRunnerPhase)
    }

    func testIsRunnerPhase_falseWhenT1HitButClosed() {
        let signal = makeSignal(status: .targetHit, t1HitAt: Date())
        XCTAssertFalse(signal.isRunnerPhase)
    }

    func testIsRunnerPhase_falseWhenNoT1() {
        let signal = makeSignal(status: .triggered, t1HitAt: nil)
        XCTAssertFalse(signal.isRunnerPhase)
    }

    func testPhaseDescription_watchingT1() {
        let signal = makeSignal(status: .triggered, t1HitAt: nil)
        XCTAssertEqual(signal.phaseDescription, "Watching T1")
    }

    func testPhaseDescription_runnerTrailing() {
        let signal = makeSignal(status: .triggered, t1HitAt: Date())
        XCTAssertEqual(signal.phaseDescription, "Runner trailing")
    }

    func testPhaseDescription_closedStatuses() {
        XCTAssertEqual(makeSignal(status: .targetHit).phaseDescription, "Target Hit")
        XCTAssertEqual(makeSignal(status: .invalidated).phaseDescription, "Stopped Out")
        XCTAssertEqual(makeSignal(status: .expired).phaseDescription, "Expired")
    }

    // MARK: - R-Multiple Tests

    func testRMultiple_calculatesCorrectly() {
        // risk1r = 1311, entryMid = 66250
        // rPct = (1311 / 66250) * 100 = 1.979%
        // outcomePct = 3.958 => rMultiple = 3.958 / 1.979 = 2.0R
        let signal = makeSignal(
            entryMid: 66_250,
            risk1r: 1_311,
            outcomePct: 3.958
        )
        XCTAssertNotNil(signal.rMultiple)
        XCTAssertEqual(signal.rMultiple!, 2.0, accuracy: 0.05)
    }

    func testRMultiple_nilWhenNoOutcome() {
        let signal = makeSignal(outcomePct: nil)
        XCTAssertNil(signal.rMultiple)
    }

    func testRMultiple_nilWhenNoRisk1r() {
        let signal = makeSignal(risk1r: nil, outcomePct: 2.5)
        XCTAssertNil(signal.rMultiple)
    }

    func testRMultiple_nilWhenRisk1rZero() {
        let signal = makeSignal(risk1r: 0, outcomePct: 2.5)
        XCTAssertNil(signal.rMultiple)
    }

    func testRMultiple_negativeForLoss() {
        let signal = makeSignal(
            entryMid: 66_250,
            risk1r: 1_311,
            outcomePct: -1.979
        )
        XCTAssertNotNil(signal.rMultiple)
        XCTAssertEqual(signal.rMultiple!, -1.0, accuracy: 0.05)
    }

    // MARK: - TimeAgo Tests

    func testTimeAgo_justNow() {
        let signal = makeSignal(generatedAt: Date())
        XCTAssertEqual(signal.timeAgo, "Just now")
    }

    func testTimeAgo_hoursAgo() {
        let signal = makeSignal(generatedAt: Date().addingTimeInterval(-3 * 3600))
        XCTAssertEqual(signal.timeAgo, "3h ago")
    }

    func testTimeAgo_daysAgo() {
        let signal = makeSignal(generatedAt: Date().addingTimeInterval(-48 * 3600))
        XCTAssertEqual(signal.timeAgo, "2d ago")
    }

    // MARK: - CombinedPnlDisplay Tests

    func testCombinedPnlDisplay_positive() {
        let signal = makeSignal(outcomePct: 2.36)
        XCTAssertEqual(signal.combinedPnlDisplay, "+2.36%")
    }

    func testCombinedPnlDisplay_negative() {
        let signal = makeSignal(outcomePct: -1.5)
        XCTAssertEqual(signal.combinedPnlDisplay, "-1.50%")
    }

    func testCombinedPnlDisplay_nilWhenNoOutcome() {
        let signal = makeSignal(outcomePct: nil)
        XCTAssertNil(signal.combinedPnlDisplay)
    }

    // MARK: - Widget Configuration Tests

    func testFlashIntelWidget_existsInAllCases() {
        XCTAssertTrue(HomeWidgetType.allCases.contains(.flashIntel))
    }

    func testFlashIntelWidget_properties() {
        let widget = HomeWidgetType.flashIntel
        XCTAssertEqual(widget.displayName, "Swing Setups")
        XCTAssertEqual(widget.icon, "scope")
        XCTAssertEqual(widget.description, "Fibonacci pattern detection across timeframes")
        XCTAssertTrue(widget.isPremium)
        XCTAssertEqual(widget.rawValue, "flash_intel")
    }

    func testFlashIntelWidget_inDefaultOrder() {
        XCTAssertTrue(HomeWidgetType.defaultOrder.contains(.flashIntel))
    }

    func testFlashIntelWidget_inDefaultEnabled() {
        XCTAssertTrue(HomeWidgetType.defaultEnabled.contains(.flashIntel))
    }

    func testFlashIntelWidget_defaultOrderPosition() {
        let order = HomeWidgetType.defaultOrder
        guard let flashIdx = order.firstIndex(of: .flashIntel),
              let eventsIdx = order.firstIndex(of: .upcomingEvents) else {
            XCTFail("Missing widgets in default order")
            return
        }
        // Flash Intel should come right after Upcoming Events
        XCTAssertEqual(flashIdx, eventsIdx + 1)
    }

    // MARK: - Widget Configuration Migration Tests

    func testWidgetConfiguration_newWidgetGetsAddedOnMigration() {
        // Simulate a saved config that doesn't have flashIntel
        let oldOrder: [HomeWidgetType] = [.upcomingEvents, .riskScore, .fearGreedIndex, .marketMovers]
        let oldEnabled: Set<HomeWidgetType> = [.upcomingEvents, .fearGreedIndex, .marketMovers]
        var config = WidgetConfiguration(
            enabledWidgets: oldEnabled,
            widgetOrder: oldOrder,
            widgetSizes: [:]
        )

        // Simulate migration: add any missing widget types
        let savedWidgetSet = Set(config.widgetOrder)
        for widgetType in HomeWidgetType.allCases {
            if !savedWidgetSet.contains(widgetType) {
                config.widgetOrder.append(widgetType)
                if HomeWidgetType.defaultEnabled.contains(widgetType) {
                    config.enabledWidgets.insert(widgetType)
                }
            }
        }

        XCTAssertTrue(config.widgetOrder.contains(.flashIntel))
        XCTAssertTrue(config.enabledWidgets.contains(.flashIntel))
    }

    func testWidgetConfiguration_toggleWidget() {
        var config = WidgetConfiguration()
        XCTAssertTrue(config.isEnabled(.flashIntel))

        config.toggleWidget(.flashIntel)
        XCTAssertFalse(config.isEnabled(.flashIntel))

        config.toggleWidget(.flashIntel)
        XCTAssertTrue(config.isEnabled(.flashIntel))
    }

    func testWidgetConfiguration_sizeDefaults() {
        let config = WidgetConfiguration()
        XCTAssertEqual(config.sizeFor(.flashIntel), .standard)
    }

    func testWidgetConfiguration_setSize() {
        var config = WidgetConfiguration()
        config.setSize(.compact, for: .flashIntel)
        XCTAssertEqual(config.sizeFor(.flashIntel), .compact)

        config.setSize(.expanded, for: .flashIntel)
        XCTAssertEqual(config.sizeFor(.flashIntel), .expanded)
    }

    func testWidgetConfiguration_orderedEnabledWidgets() {
        var config = WidgetConfiguration()
        // Disable flashIntel
        config.toggleWidget(.flashIntel)
        let ordered = config.orderedEnabledWidgets
        XCTAssertFalse(ordered.contains(.flashIntel))

        // Re-enable
        config.toggleWidget(.flashIntel)
        let ordered2 = config.orderedEnabledWidgets
        XCTAssertTrue(ordered2.contains(.flashIntel))
    }

    // MARK: - JSON Decoding Tests

    func testTradeSignal_decodesFromJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "asset": "BTC",
            "signal_type": "sell",
            "status": "triggered",
            "entry_zone_low": 65800.0,
            "entry_zone_high": 66700.0,
            "entry_price_mid": 66250.0,
            "confluence_zone_id": null,
            "target_1": 64688.0,
            "target_2": 63000.0,
            "stop_loss": 67561.0,
            "risk_reward_ratio": 1.2,
            "invalidation_note": null,
            "btc_risk_score": 0.35,
            "fear_greed_index": 32,
            "macro_regime": "Risk-Off",
            "coinbase_ranking": 150,
            "arkline_score": 42,
            "bounce_confirmed": true,
            "confirmation_details": {"wick_rejection": true, "volume_spike": false},
            "best_price": null,
            "runner_stop": null,
            "runner_exit_price": null,
            "risk_1r": 1311.0,
            "t1_pnl_pct": null,
            "runner_pnl_pct": null,
            "ema_trend_aligned": true,
            "outcome": null,
            "outcome_pct": null,
            "duration_hours": null,
            "generated_at": "2026-03-05T18:21:00Z",
            "triggered_at": "2026-03-05T18:21:00Z",
            "t1_hit_at": null,
            "closed_at": null,
            "expires_at": "2026-03-08T18:21:00Z",
            "briefing_text": null
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = json.data(using: .utf8)!
        let signal = try decoder.decode(TradeSignal.self, from: data)

        XCTAssertEqual(signal.asset, "BTC")
        XCTAssertEqual(signal.signalType, .sell)
        XCTAssertEqual(signal.status, .triggered)
        XCTAssertEqual(signal.entryZoneLow, 65_800)
        XCTAssertEqual(signal.entryZoneHigh, 66_700)
        XCTAssertEqual(signal.target1, 64_688)
        XCTAssertEqual(signal.target2, 63_000)
        XCTAssertEqual(signal.stopLoss, 67_561)
        XCTAssertEqual(signal.riskRewardRatio, 1.2)
        XCTAssertEqual(signal.btcRiskScore, 0.35)
        XCTAssertEqual(signal.fearGreedIndex, 32)
        XCTAssertEqual(signal.macroRegime, "Risk-Off")
        XCTAssertTrue(signal.bounceConfirmed)
        XCTAssertEqual(signal.confirmationDetails?.wickRejection, true)
        XCTAssertEqual(signal.confirmationDetails?.volumeSpike, false)
        XCTAssertNil(signal.t1HitAt)
        XCTAssertFalse(signal.isT1Hit)
        XCTAssertFalse(signal.isRunnerPhase)
    }

    func testTradeSignal_decodesAllOutcomes() throws {
        for outcome in ["win", "loss", "partial"] {
            let json = """
            {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "asset": "BTC",
                "signal_type": "sell",
                "status": "target_hit",
                "entry_zone_low": 65800.0,
                "entry_zone_high": 66700.0,
                "entry_price_mid": 66250.0,
                "stop_loss": 67561.0,
                "risk_reward_ratio": 1.2,
                "bounce_confirmed": true,
                "outcome": "\(outcome)",
                "outcome_pct": 2.5,
                "generated_at": "2026-03-05T18:21:00Z"
            }
            """
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let signal = try decoder.decode(TradeSignal.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(signal.outcome?.rawValue, outcome)
        }
    }

    func testTradeSignal_decodesAllSignalTypes() throws {
        for (raw, expected) in [("strong_buy", SignalType.strongBuy), ("buy", .buy), ("strong_sell", .strongSell), ("sell", .sell)] {
            let json = """
            {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "asset": "BTC",
                "signal_type": "\(raw)",
                "status": "active",
                "entry_zone_low": 65800.0,
                "entry_zone_high": 66700.0,
                "entry_price_mid": 66250.0,
                "stop_loss": 67561.0,
                "risk_reward_ratio": 1.2,
                "bounce_confirmed": true,
                "generated_at": "2026-03-05T18:21:00Z"
            }
            """
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let signal = try decoder.decode(TradeSignal.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(signal.signalType, expected)
        }
    }

    // MARK: - Stress Tests

    func testTradeSignal_computedProperties_withExtremeValues() {
        // Very small entry price
        let small = makeSignal(entryMid: 0.001, target1: 0.002, stopLoss: 0.0005)
        XCTAssertEqual(small.entryPctFromTarget1!, 100.0, accuracy: 0.1)
        XCTAssertEqual(small.stopLossPct, -50.0, accuracy: 0.1)

        // Very large entry price
        let large = makeSignal(entryMid: 1_000_000, target1: 1_050_000, stopLoss: 990_000)
        XCTAssertEqual(large.entryPctFromTarget1!, 5.0, accuracy: 0.01)
        XCTAssertEqual(large.stopLossPct, -1.0, accuracy: 0.01)
    }

    func testTradeSignal_rMultiple_edgeCases() {
        // Very small risk1r (near zero but positive)
        let tinyRisk = makeSignal(entryMid: 66_250, risk1r: 0.01, outcomePct: 1.0)
        XCTAssertNotNil(tinyRisk.rMultiple)

        // Massive positive outcome
        let bigWin = makeSignal(entryMid: 66_250, risk1r: 1_311, outcomePct: 50.0)
        XCTAssertNotNil(bigWin.rMultiple)
        XCTAssertGreaterThan(bigWin.rMultiple!, 20.0)
    }

    func testWidgetConfiguration_allWidgetTypesInDefaultOrder() {
        let order = Set(HomeWidgetType.defaultOrder)
        for widget in HomeWidgetType.allCases {
            XCTAssertTrue(order.contains(widget), "\(widget) missing from defaultOrder")
        }
    }

    func testWidgetConfiguration_noDuplicatesInDefaultOrder() {
        let order = HomeWidgetType.defaultOrder
        XCTAssertEqual(order.count, Set(order).count, "Duplicate widgets in defaultOrder")
    }

    func testWidgetConfiguration_defaultEnabledIsSubsetOfOrder() {
        let orderSet = Set(HomeWidgetType.defaultOrder)
        for widget in HomeWidgetType.defaultEnabled {
            XCTAssertTrue(orderSet.contains(widget), "\(widget) enabled but not in order")
        }
    }

    func testWidgetConfiguration_encodeDecode() throws {
        var config = WidgetConfiguration()
        config.setSize(.compact, for: .flashIntel)
        // flashIntel starts enabled (in defaultEnabled), toggle it off
        config.toggleWidget(.flashIntel)

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(WidgetConfiguration.self, from: data)

        XCTAssertEqual(config, decoded)
        XCTAssertEqual(decoded.sizeFor(.flashIntel), .compact)
        XCTAssertFalse(decoded.isEnabled(.flashIntel))
    }

    func testWidgetConfiguration_stressToggleAllWidgets() {
        var config = WidgetConfiguration()

        // Disable all
        for widget in HomeWidgetType.allCases {
            config.setWidgetEnabled(widget, enabled: false)
        }
        XCTAssertTrue(config.orderedEnabledWidgets.isEmpty)

        // Enable all
        for widget in HomeWidgetType.allCases {
            config.setWidgetEnabled(widget, enabled: true)
        }
        XCTAssertEqual(config.orderedEnabledWidgets.count, HomeWidgetType.allCases.count)
    }

    func testWidgetConfiguration_rapidToggle() {
        var config = WidgetConfiguration()
        // Toggle flashIntel 1000 times — should end up back in original state (enabled)
        for _ in 0..<1000 {
            config.toggleWidget(.flashIntel)
        }
        XCTAssertTrue(config.isEnabled(.flashIntel))
    }

    // MARK: - WidgetSize Tests

    func testWidgetSize_allCases() {
        XCTAssertEqual(WidgetSize.allCases.count, 3)
        XCTAssertEqual(WidgetSize.allCases, [.compact, .standard, .expanded])
    }

    func testWidgetSize_displayNames() {
        XCTAssertEqual(WidgetSize.compact.displayName, "Compact")
        XCTAssertEqual(WidgetSize.standard.displayName, "Standard")
        XCTAssertEqual(WidgetSize.expanded.displayName, "Expanded")
    }

    func testWidgetSize_encodeDecode() throws {
        for size in WidgetSize.allCases {
            let data = try JSONEncoder().encode(size)
            let decoded = try JSONDecoder().decode(WidgetSize.self, from: data)
            XCTAssertEqual(size, decoded)
        }
    }
}
