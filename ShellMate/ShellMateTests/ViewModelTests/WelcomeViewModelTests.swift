import XCTest
@testable import ShellMate

/// WelcomeViewModel 单元测试
/// 覆盖步骤导航、回调分发及状态流转
@MainActor
final class WelcomeViewModelTests: XCTestCase {

    // MARK: - 测试属性

    var vm: WelcomeViewModel!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        vm = WelcomeViewModel()
    }

    override func tearDown() async throws {
        vm = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialStep_isZero() {
        XCTAssertEqual(vm.currentStep, 0)
    }

    func testStepsCount_isThree() {
        XCTAssertEqual(vm.steps.count, 3)
    }

    func testFeaturesCount_isFour() {
        XCTAssertEqual(vm.features.count, 4)
    }

    // MARK: - nextStep

    func testNextStep_incrementsCurrentStep() {
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 1)
    }

    func testNextStep_twice_incrementsToTwo() {
        vm.nextStep()
        vm.nextStep()
        XCTAssertEqual(vm.currentStep, 2)
    }

    // MARK: - goToStep

    func testGoToStep_setsCorrectStep() {
        vm.goToStep(2)
        XCTAssertEqual(vm.currentStep, 2)
    }

    func testGoToStep_zero_resetsToFirst() {
        vm.nextStep()
        vm.goToStep(0)
        XCTAssertEqual(vm.currentStep, 0)
    }

    // MARK: - 回调分发

    func testSkip_invokesOnDismiss() {
        var called = false
        vm.onDismiss = { called = true }
        vm.skip()
        XCTAssertTrue(called)
    }

    func testCreateSession_invokesOnCreateSession() {
        var called = false
        vm.onCreateSession = { called = true }
        vm.createSession()
        XCTAssertTrue(called)
    }

    func testImportConfiguration_invokesOnImportConfiguration() {
        var called = false
        vm.onImportConfiguration = { called = true }
        vm.importConfiguration()
        XCTAssertTrue(called)
    }

    // MARK: - 回调为 nil 时不崩溃

    func testSkip_withoutCallback_doesNotCrash() {
        vm.onDismiss = nil
        XCTAssertNoThrow(vm.skip())
    }

    // MARK: - 步骤数据完整性

    func testStepData_hasNonEmptyEmoji() {
        for step in vm.steps {
            XCTAssertFalse(step.emoji.isEmpty, "步骤 emoji 不应为空")
        }
    }

    func testStepData_hasNonEmptyTitle() {
        for step in vm.steps {
            XCTAssertFalse(step.title.isEmpty, "步骤标题不应为空")
        }
    }

    func testFeatureData_hasNonEmptyLabel() {
        for feature in vm.features {
            XCTAssertFalse(feature.label.isEmpty, "功能标签不应为空")
        }
    }

    // MARK: - 初始化带回调

    func testInit_withCallbacks_storesCorrectly() {
        var dismissed = false
        let vm2 = WelcomeViewModel(onDismiss: { dismissed = true })
        vm2.skip()
        XCTAssertTrue(dismissed)
    }
}
