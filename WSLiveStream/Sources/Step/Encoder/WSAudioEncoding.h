//
//  LFAudioEncoding.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "WSAudioFrame.h"
#import "WSLiveAudioConfiguration.h"



@protocol WSAudioEncoding;
/// 编码器编码后回调
@protocol WSAudioEncodingDelegate <NSObject>
@required
- (void)audioEncoder:(nullable id<WSAudioEncoding>)encoder audioFrame:(nullable WSAudioFrame *)frame;
@end

/// 编码器抽象的接口
@protocol WSAudioEncoding <NSObject>
@required
- (void)encodeAudioData:(nullable NSData*)audioData timeStamp:(uint64_t)timeStamp;
- (void)stopEncoder;
@optional
- (nullable instancetype)initWithAudioStreamConfiguration:(nullable WSLiveAudioConfiguration *)configuration;
- (void)setDelegate:(nullable id<WSAudioEncodingDelegate>)delegate;
- (nullable NSData *)adtsData:(NSInteger)channel rawDataLength:(NSInteger)rawDataLength;
@end

