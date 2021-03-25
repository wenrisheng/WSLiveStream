//
//  LFStreamSocket.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WSLiveStreamInfo.h"
#import "WSStreamingBuffer.h"
#import "WSLiveDebug.h"



@protocol WSStreamSocket;
@protocol WSStreamSocketDelegate <NSObject>

/** callback buffer current status (回调当前缓冲区情况，可实现相关切换帧率 码率等策略)*/
- (void)socketBufferStatus:(nullable id <WSStreamSocket>)socket status:(LFLiveBuffferState)status;
/** callback socket current status (回调当前网络情况) */
- (void)socketStatus:(nullable id <WSStreamSocket>)socket status:(WSLiveState)status;
/** callback socket errorcode */
- (void)socketDidError:(nullable id <WSStreamSocket>)socket errorCode:(WSLiveSocketErrorCode)errorCode;
@optional
/** callback debugInfo */
- (void)socketDebug:(nullable id <WSStreamSocket>)socket debugInfo:(nullable WSLiveDebug *)debugInfo;
@end

@protocol WSStreamSocket <NSObject>
- (void)start;
- (void)stop;
- (void)sendFrame:(nullable WSFrame *)frame;
- (void)setDelegate:(nullable id <WSStreamSocketDelegate>)delegate;
@optional
- (nullable instancetype)initWithStream:(nullable WSLiveStreamInfo *)stream;
- (nullable instancetype)initWithStream:(nullable WSLiveStreamInfo *)stream reconnectInterval:(NSInteger)reconnectInterval reconnectCount:(NSInteger)reconnectCount;
@end
