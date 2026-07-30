//
//  PortSelectManagerWrapper.h
//  all
//
//  Created by SLSLave on 5/9/25.
//


#import <Foundation/Foundation.h>
#import <WebRTC/RTCMacros.h>

NS_ASSUME_NONNULL_BEGIN

// enum 정의를 인터페이스 선언 전에 추가
typedef NS_ENUM(NSInteger, RTCPortSelectType) {
    RTCPortSelectTypeWifi = 0,
    RTCPortSelectTypeCellular = 1,
    RTCPortSelectTypeBoth = 2
};

RTC_OBJC_EXPORT
@interface RTCPortSelectManagerWrapper : NSObject

- (void)hasWifi:(BOOL)hasWifi;

- (void)setForceWifiOnly:(BOOL)value;

- (void)setPortType:(RTCPortSelectType)type;

// Backup connection switching을 활성화/비활성화합니다.
// OME 등 backup connection을 지원하지 않는 서버 환경에서 false로 설정하면
// 신호 약화 시 connection switching으로 인한 packet loss를 방지합니다.
// 기본값: YES
- (void)setBackupConnectionEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
