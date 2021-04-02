//
//  CaptureClientVC.m
//  WSLiveStream
//
//  Created by jack on 2021/3/22.
//

#import "CaptureClientVC.h"
#import <WSLiveStream/WSLiveStreamPublish.h>

inline static NSString *formatedSpeed(float bytes, float elapsed_milli) {
    if (elapsed_milli <= 0) {
        return @"N/A";
    }

    if (bytes <= 0) {
        return @"0 KB/s";
    }

    float bytes_per_sec = ((float)bytes) * 1000.f /  elapsed_milli;
    if (bytes_per_sec >= 1000 * 1000) {
        return [NSString stringWithFormat:@"%.2f MB/s", ((float)bytes_per_sec) / 1000 / 1000];
    } else if (bytes_per_sec >= 1000) {
        return [NSString stringWithFormat:@"%.1f KB/s", ((float)bytes_per_sec) / 1000];
    } else {
        return [NSString stringWithFormat:@"%ld B/s", (long)bytes_per_sec];
    }
}

@interface CaptureClientVC () <WSLiveSessionDelegate>

@property (nonatomic, strong) WSSession *session;

@property (weak, nonatomic) IBOutlet UIView *preView;

- (IBAction)toneSliderValueChanged:(id)sender;
- (IBAction)brightSliderValueChanged:(id)sender;
- (IBAction)beautySliderValueChanged:(id)sender;

@end

@implementation CaptureClientVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!self.session) {
        CGSize videoSize = self.preView.frame.size;
        WSLiveVideoConfiguration *videoConfiguration = [WSLiveVideoConfiguration new];
    //    videoConfiguration.outputImageOrientation = UIInterfaceOrientationPortrait;
        videoConfiguration.videoSize = videoSize;
        videoConfiguration.videoBitRate = 800*1024;
        videoConfiguration.videoMaxBitRate = 1000*1024;
        videoConfiguration.videoMinBitRate = 500*1024;
        videoConfiguration.videoFrameRate = 24;
        videoConfiguration.videoMaxKeyframeInterval = 48;
        videoConfiguration.outputImageOrientation = UIInterfaceOrientationPortrait;
        videoConfiguration.autorotate = NO;
        videoConfiguration.sessionPreset = CaptureSessionPreset720x1280;
        videoConfiguration.enableH264 = YES;
        videoConfiguration.enableH265 = NO;
        self.session = [[WSSession alloc] initWithAudioConfiguration:[WSLiveAudioConfiguration defaultConfiguration] videoConfiguration:videoConfiguration captureType:LFLiveCaptureDefaultMask];

        self.session.delegate = self;
        self.session.showDebugInfo = NO;
        self.session.preView = self.preView;
    //    self.session.mirror = NO;

        [self requestAccessForVideo];
        [self requestAccessForAudio];

        WSLiveStreamInfo *stream = [WSLiveStreamInfo new];
        stream.url = @"rtmp://192.168.0.169/live/livestream";
        [self.session startLive:stream];
    }
}

- (void)requestAccessForVideo {
    __weak typeof(self) _self = self;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: {
        // 许可对话没有出现，发起授权许可
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.session setRunning:YES];
                    });
                }
            }];
        break;
    }
    case AVAuthorizationStatusAuthorized: {
        // 已经开启授权，可继续
        dispatch_async(dispatch_get_main_queue(), ^{
            [_self.session setRunning:YES];
        });
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        // 用户明确地拒绝授权，或者相机设备无法访问

        break;
    default:
        break;
    }
}

- (void)requestAccessForAudio {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            }];
        break;
    }
    case AVAuthorizationStatusAuthorized: {
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        break;
    default:
        break;
    }
}


#pragma mark -- LFStreamingSessionDelegate
/** live status changed will callback */
- (void)liveSession:(nullable WSSession *)session liveStateDidChange:(WSLiveState)state {
    NSLog(@"liveStateDidChange: %ld", state);
    NSString *str = nil;
    switch (state) {
    case LiveReady:
            str = @"未连接";
        break;
    case LivePending:
            str = @"连接中";
        break;
    case LiveStart:
            str = @"已连接";
        break;
    case LiveError:
            str = @"连接错误";
        break;
    case LiveStop:
            str = @"未连接";
        break;
    default:
        break;
    }
    NSLog(@"liveStateDidChange: %@", str);
}


- (void)liveSession:(nullable WSSession *)session debugInfo:(nullable WSLiveDebug *)debugInfo {
    NSLog(@"debugInfo uploadSpeed: %@", formatedSpeed(debugInfo.currentBandwidth, debugInfo.elapsedMilli));
}


- (void)liveSession:(nullable WSSession *)session errorCode:(WSLiveSocketErrorCode)errorCode {
    NSLog(@"errorCode: %ld", errorCode);
}

- (IBAction)toneSliderValueChanged:(UISlider *)sender {
    self.session.toneLevel = sender.value;
}

- (IBAction)beautySliderValueChanged:(UISlider *)sender {
    self.session.beautyLevel = sender.value;
}

- (IBAction)brightSliderValueChanged:(UISlider *)sender {
    self.session.brightLevel = sender.value;
}
@end
