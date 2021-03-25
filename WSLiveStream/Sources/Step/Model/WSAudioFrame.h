//
//  LFAudioFrame.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "WSFrame.h"

@interface WSAudioFrame : WSFrame

/// flv打包中aac的header
@property (nonatomic, strong) NSData *audioInfo;

@end
