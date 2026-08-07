import ProjectDescription

// 이 프로젝트는 Tuist 로 .xcodeproj 를 생성하고, 생성된 결과물(ShopliveOnboardingDemo.xcodeproj)도
// 저장소에 포함한다. 다만 SDK 는 SPM 으로 받고 그 바이너리는 커밋하지 않으므로, 클론 직후 한 번은
// `tuist install` 이 필요하다. 그 뒤로는 Tuist 없이 열어서 빌드할 수 있고, Tuist 는 프로젝트 구성이나
// SDK 버전을 바꿔 "재생성"할 때만 쓴다.
let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: .all,
        swiftVersion: nil
    )
)
