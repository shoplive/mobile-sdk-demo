import ProjectDescription

// 이 프로젝트는 Tuist 로 .xcodeproj 를 생성하지만, 생성된 결과물(ShopliveOnboardingDemo.xcodeproj)은
// 그 자체로 완결이라 고객사는 Tuist 없이 열어서 빌드할 수 있다. Tuist 는 "재생성"이 필요할 때만 쓴다.
let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: .all,
        swiftVersion: nil
    )
)
