import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct PopoverFooterStateTests {
    @Test func canRefreshIsInverseOfIsRefreshing() {
        let state = PopoverFooterState(lastUpdatedAt: nil, isRefreshing: true, canRefresh: false)
        #expect(state.isRefreshing == true)
        #expect(state.canRefresh == false)
    }

    @Test func equatable() {
        let date = Date(timeIntervalSince1970: 0)
        let a = PopoverFooterState(lastUpdatedAt: date, isRefreshing: false, canRefresh: true)
        let b = PopoverFooterState(lastUpdatedAt: date, isRefreshing: false, canRefresh: true)
        #expect(a == b)
    }

    @MainActor
    @Test func footer_emptyState_hasNilTimestampAndCanRefresh() {
        let vm = StatusViewModel()
        let state = PopoverFooterState.from(viewModel: vm, selected: .claude)
        #expect(state.lastUpdatedAt == nil)
        #expect(state.isRefreshing == false)
        #expect(state.canRefresh == true)
    }

    @MainActor
    @Test func footer_whileRefreshing_disablesRefresh() {
        let vm = StatusViewModel()
        vm.testSet_isRefreshAllInFlight(true)
        let state = PopoverFooterState.from(viewModel: vm, selected: .claude)
        #expect(state.isRefreshing == true)
        #expect(state.canRefresh == false)
    }

    @MainActor
    @Test func footer_lastUpdatedAt_isScopedToSelectedTab() {
        let vm = StatusViewModel()
        let oldClaude = Date(timeIntervalSince1970: 1_000)
        let freshCodex = Date(timeIntervalSince1970: 2_000)
        vm.testSet_lastClaudeRefreshAt(oldClaude)
        vm.testSet_lastCodexRefreshAt(freshCodex)

        #expect(PopoverFooterState.from(viewModel: vm, selected: .claude).lastUpdatedAt == oldClaude)
        #expect(PopoverFooterState.from(viewModel: vm, selected: .codex).lastUpdatedAt == freshCodex)
    }
}
