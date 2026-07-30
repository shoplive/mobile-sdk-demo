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
 * Audio-level metering extension for RTCPeerConnectionFactory.
 *
 * Lets the host app drive a UI level meter (LED bar) from the same audio
 * device the factory uses for recording — eliminating the need for a separate
 * AudioQueue mic input client which contends with the ADM and can cause
 * silent capture in the streaming path.
 *
 * Backed by virtual hooks added to webrtc::AudioDeviceModule and the iOS
 * AudioDeviceIOS implementation. Only the iOS built-in ADM implements these;
 * other ADMs return -1 / no-op silently.
 */
@interface RTC_OBJC_TYPE (RTCPeerConnectionFactory) (AudioLevel)

/**
 * Activate the built-in ADM's audio capture independently of any
 * peerConnection. While metering is active, the underlying AudioUnit stays
 * running even when no peerConnection is attached and even after
 * peerConnection is closed.
 *
 * Idempotent. Safe to call from main thread; the underlying impl marshals to
 * its own internal thread as needed.
 *
 * @return YES on success, NO if the ADM does not support metering.
 */
- (BOOL)setMeteringActive:(BOOL)active;

/**
 * Register (or clear with `nil`) a handler that receives the current RMS
 * audio level in dB at ~60Hz whenever PCM is being captured.
 *
 * The handler is invoked on the main queue (the bridge hops via
 * `dispatch_async(dispatch_get_main_queue(), ...)`), so it is safe to update
 * UI directly. dB value is clamped to [-100, 0].
 */
- (void)setAudioLevelHandler:(nullable void (^)(float dB))handler;

@end

NS_ASSUME_NONNULL_END
