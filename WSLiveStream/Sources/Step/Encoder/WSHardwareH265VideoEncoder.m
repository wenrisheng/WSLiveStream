//
//  WSHardwareH265VideoEncoder.m
//  WSLiveStream
//
//  Created by jack on 2021/3/29.
//

#import "WSHardwareH265VideoEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface WSHardwareH265VideoEncoder (){
    VTCompressionSessionRef compressionSession;
    NSInteger frameCount;
    NSData *sps;
    NSData *pps;
    FILE *fp;
    BOOL enabledWriteVideoFile;
}

@property (nonatomic, strong) WSLiveVideoConfiguration *configuration;
@property (nonatomic, weak) id<WSVideoEncodingDelegate> h264Delegate;
@property (nonatomic) NSInteger currentVideoBitRate;
@property (nonatomic) BOOL isBackGround;

@end

@implementation WSHardwareH265VideoEncoder

- (instancetype)initWithVideoStreamConfiguration:(WSLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;
        [self resetCompressionSession];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
#ifdef DEBUG
        enabledWriteVideoFile = NO;
        [self initForFilePath];
#endif
        
    }
    return self;
}

- (void)initForFilePath {
    NSString *path = [self GetFilePathByfileName:@"IOSCamDemo.asf"];
    NSLog(@"%@", path);
    self->fp = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}

@end
