import XCTest
import SwiftData
@testable import NudgeAI

final class FakeIdentityStore: AppleIdentityStore {
    var id: String?
    func saveIdentifier(_ identifier: String) throws { id = identifier }
    func readIdentifier() throws -> String? { id }
    func deleteIdentifier() throws { id = nil }
}

@MainActor
final class IdentityOnboardingTests: XCTestCase {
    private func makeManager(state: AppleCredentialState, store: FakeIdentityStore = FakeIdentityStore())
        throws -> (AppleIdentityManager, SettingsRepository, FakeIdentityStore) {
        let repo = SwiftDataSettingsRepository(modelContext: try TestStore.makeContext())
        return (AppleIdentityManager(store: store, settingsRepository: repo, credentialState: { _ in state }), repo, store)
    }

    func testCredentialStateMapping() {
        XCTAssertTrue(AppleIdentityRules.remainsSignedIn(.authorized))
        XCTAssertTrue(AppleIdentityRules.remainsSignedIn(.unknown))
        XCTAssertTrue(AppleIdentityRules.remainsSignedIn(.transferred))
        XCTAssertFalse(AppleIdentityRules.remainsSignedIn(.revoked))
        XCTAssertFalse(AppleIdentityRules.remainsSignedIn(.notFound))
    }

    func testInitialsAndDisplayName() {
        XCTAssertEqual(AppleIdentityRules.initials(for: nil), "Y")
        XCTAssertEqual(AppleIdentityRules.initials(for: "amit kavatkar"), "AK")
        XCTAssertEqual(AppleIdentityRules.displayName(given: "Amit", family: nil), "Amit")
        XCTAssertNil(AppleIdentityRules.displayName(given: nil, family: " "))
    }

    func testSignInPersistsNameAndLaterNilNameKeepsIt() throws {
        let (manager, repo, store) = try makeManager(state: .authorized)
        try manager.completeSignIn(userIdentifier: "uid", displayName: "Amit K")
        try manager.completeSignIn(userIdentifier: "uid", displayName: nil)
        XCTAssertEqual(store.id, "uid")
        XCTAssertEqual(try repo.fetchSettings().appleDisplayName, "Amit K")
        XCTAssertTrue(manager.isSignedIn)
    }

    func testSignOutClearsIdentityButKeepsNudgesAndKeys() throws {
        let context = try TestStore.makeContext()
        let repo = SwiftDataSettingsRepository(modelContext: context)
        let keys = InMemoryKeyStore()
        try keys.saveAPIKey("mock-key", for: .deepseek)
        context.insert(ReminderItem(rawText: "keep me", createdAt: Date(), source: .inApp))
        try context.save()
        let manager = AppleIdentityManager(store: FakeIdentityStore(), settingsRepository: repo, credentialState: { _ in .authorized })
        try manager.completeSignIn(userIdentifier: "uid", displayName: "Amit")
        try manager.signOut()
        XCTAssertFalse(manager.isSignedIn)
        XCTAssertNil(try repo.fetchSettings().appleDisplayName)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReminderItem>()).count, 1)
        XCTAssertEqual(try keys.readAPIKey(for: .deepseek), "mock-key")
    }

    func testLaunchCheckRevokedSignsOutAuthorizedKeeps() async throws {
        let (revoked, _, rStore) = try makeManager(state: .revoked, store: FakeIdentityStore())
        try revoked.completeSignIn(userIdentifier: "uid", displayName: "A")
        await revoked.refreshOnLaunch()
        XCTAssertNil(rStore.id)

        let (ok, _, oStore) = try makeManager(state: .authorized)
        try ok.completeSignIn(userIdentifier: "uid", displayName: "A")
        await ok.refreshOnLaunch()
        XCTAssertEqual(oStore.id, "uid")
    }

    func testOnboardingStepOrderAndProgress() {
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .signIn, .choosePlatform, .teachSiri, .permissions])
        XCTAssertEqual(OnboardingStep.total, 5)
        XCTAssertEqual(OnboardingStep.welcome.position, 1)
        XCTAssertEqual(OnboardingStep.permissions.position, 5)
    }

    func testConnectionStatusMapping() {
        XCTAssertEqual(ProviderConnectionStatus.resolve(selected: .none, activeProvider: .none, hasKey: false, isUnreachable: false), .notConnected)
        XCTAssertEqual(ProviderConnectionStatus.resolve(selected: .deepseek, activeProvider: .deepseek, hasKey: false, isUnreachable: false), .notConnected)
        XCTAssertEqual(ProviderConnectionStatus.resolve(selected: .deepseek, activeProvider: .anthropic, hasKey: true, isUnreachable: false), .notConnected)
        XCTAssertEqual(ProviderConnectionStatus.resolve(selected: .anthropic, activeProvider: .anthropic, hasKey: true, isUnreachable: false), .connected)
        XCTAssertEqual(ProviderConnectionStatus.resolve(selected: .anthropic, activeProvider: .anthropic, hasKey: true, isUnreachable: true), .cantReach)
    }

    func testKeyCheckMessagesDistinguishCases() {
        let invalid = KeyCheckMessages.message(for: KeyCheckError.invalidKey, provider: .deepseek)
        let balance = KeyCheckMessages.message(for: KeyCheckError.rejected(402), provider: .deepseek)
        let other = KeyCheckMessages.message(for: KeyCheckError.rejected(400), provider: .deepseek)
        let offline = KeyCheckMessages.message(for: KeyCheckError.unreachable, provider: .deepseek)
        XCTAssertEqual(Set([invalid, balance, other, offline]).count, 4)
        XCTAssertTrue(balance.contains("balance"))
    }

    func testSkipPlatformLeavesProviderNoneAndSwitchKeepsOtherKey() async throws {
        let context = try TestStore.makeContext()
        let repo = SwiftDataSettingsRepository(modelContext: context)
        let keys = InMemoryKeyStore()
        try keys.saveAPIKey("mock-a", for: .anthropic)
        let service = ProviderConnectionService(apiKeyStore: keys, settingsRepository: repo)
        let vm = OnboardingViewModel(
            connectService: service,
            identity: AppleIdentityManager(store: FakeIdentityStore(), settingsRepository: repo, credentialState: { _ in .unknown }),
            settingsRepository: repo,
            startingStep: .choosePlatform
        )
        vm.skipPlatform()
        XCTAssertEqual(vm.step, .teachSiri)
        XCTAssertEqual(try repo.fetchSettings().provider, .none)
        try repo.update { $0.changeProvider(to: .deepseek) }
        XCTAssertEqual(try keys.readAPIKey(for: .anthropic), "mock-a")
    }
}
