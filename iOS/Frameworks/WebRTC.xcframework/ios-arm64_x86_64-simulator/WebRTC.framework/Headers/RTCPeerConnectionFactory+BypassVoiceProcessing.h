/*
 *  Copyright (c) 2026 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import <Foundation/Foundation.h>

#import <WebRTC/RTCPeerConnectionFactory.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Bypass-voice-processing extension for RTCPeerConnectionFactory.
 *
 * Lets the host app opt out of Apple's VPIO (Voice Processing I/O) audio unit
 * hardware AEC/AGC/NS for the captured mic stream — useful for broadcasting
 * scenarios where the host already manages microphone gain and does not want
 * the hardware AGC to pump up the noise floor on quiet input (which manifests
 * as crackling artifacts at low signal levels after Opus encoding).
 *
 * When YES is passed, the iOS ADM still uses the VPIO audio unit (so the
 * RTCPeerConnectionFactory+AudioLevel metering tap continues to work), but
 * sets `kAUVoiceIOProperty_BypassVoiceProcessing = 1` on the input bus,
 * disabling the built-in AEC/AGC/NS.
 *
 * Scoped to the factory instance — other factories created without this init
 * are unaffected.
 */
@interface RTC_OBJC_TYPE (RTCPeerConnectionFactory) (BypassVoiceProcessing)

- (instancetype)
    initWithEncoderFactory:
        (nullable id<RTC_OBJC_TYPE(RTCVideoEncoderFactory)>)encoderFactory
            decoderFactory:
                (nullable id<RTC_OBJC_TYPE(RTCVideoDecoderFactory)>)
                    decoderFactory
     bypassVoiceProcessing:(BOOL)bypassVoiceProcessing;

@end

NS_ASSUME_NONNULL_END
