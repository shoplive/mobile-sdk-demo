# SDK 공개 표면은 AAR 의 consumer-rules.pro + @Keep 으로 이미 보호된다.
# 앱 쪽에 추가로 필요한 규칙만 둔다.

# 데모앱이 리플렉션으로 쓰는 것은 없다. 아래는 Compose/Kotlin 기본 유지 규칙.
-dontwarn org.jetbrains.annotations.**
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions
