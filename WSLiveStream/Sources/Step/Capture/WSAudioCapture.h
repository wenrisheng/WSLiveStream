
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "WSLiveAudioConfiguration.h"

#pragma mark -- AudioCaptureNotification
/** compoentFialed will post the notification */
extern NSString *_Nullable const LFAudioComponentFailedToCreateNotification;

@class WSAudioCapture;

@protocol WSAudioCaptureDelegate <NSObject>

- (void)captureOutput:(nullable WSAudioCapture *)capture audioData:(nullable NSData*)audioData;

@end


@interface WSAudioCapture : NSObject

@property (nullable, nonatomic, weak) id<WSAudioCaptureDelegate> delegate;

/// muted will memset 0
@property (nonatomic, assign) BOOL muted;
@property (nonatomic, assign) BOOL running;

#pragma mark - Initializer

- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;


- (nullable instancetype)initWithAudioConfiguration:(nullable WSLiveAudioConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@end
