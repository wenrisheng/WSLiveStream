//
//  LFVideoEncoding.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WSVideoFrame.h"
#import "WSLiveVideoConfiguration.h"

@protocol WSVideoEncoding;
/// 编码器编码后回调
@protocol WSVideoEncodingDelegate <NSObject>
@required
- (void)videoEncoder:(nullable id<WSVideoEncoding>)encoder videoFrame:(nullable WSVideoFrame *)frame;
@end

/// 编码器抽象的接口
@protocol WSVideoEncoding <NSObject>
@required
- (void)encodeVideoData:(nullable CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;
@optional
@property (nonatomic, assign) NSInteger videoBitRate;
- (nullable instancetype)initWithVideoStreamConfiguration:(nullable WSLiveVideoConfiguration *)configuration;
- (void)setDelegate:(nullable id<WSVideoEncodingDelegate>)delegate;
- (void)stopEncoder;
@end

