//
//  LFVideoFrame.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "WSFrame.h"


@interface WSVideoFrame : WSFrame

@property (nonatomic, assign) BOOL isKeyFrame;
@property (nonatomic, strong) NSData *vps;
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;

@end
