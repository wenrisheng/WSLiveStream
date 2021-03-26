//
//  LFHardwareAudioEncoder.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "WSAudioEncoding.h"

@interface WSHardwareAudioEncoder : NSObject<WSAudioEncoding>

- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

@end
