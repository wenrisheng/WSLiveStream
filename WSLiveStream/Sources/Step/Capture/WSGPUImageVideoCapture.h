
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "WSLiveVideoConfiguration.h"
#import "WSVideoCapture.h"

@interface WSGPUImageVideoCapture : NSObject<WSVideoCapture>

/// 视频采集代理
@property (nullable, nonatomic, weak) id<WSVideoCaptureDelegate> delegate;

/// 开启/关闭视频
@property (nonatomic, assign) BOOL running;

/// 设置预览view
@property (null_resettable, nonatomic, strong) UIView *preView;

/// 摄像头方向, 默认是前摄像头
@property (nonatomic, assign) AVCaptureDevicePosition captureDevicePosition;

/// 是否开启美颜
@property (nonatomic, assign) BOOL beautyFace;

/// 是否开启闪光灯
@property (nonatomic, assign) BOOL torch;

/// 设置反向,默认YES
@property (nonatomic, assign) BOOL mirror;

/// 设置美颜等级，默认0.5，范围0.0～1.0
@property (nonatomic, assign) CGFloat beautyLevel;

/// 设置亮度等级，默认0.5，范围0.0～1.0
@property (nonatomic, assign) CGFloat brightLevel;

/// 设置颜色饱和度，默认0.5，范围0.0～1.0
@property (nonatomic, assign) CGFloat toneLevel;

/// 设置摄像机缩放倍数，默认1.0，范围1.0～3.0
@property (nonatomic, assign) CGFloat zoomScale;

/// 设置视频帧率，即每秒播放多少帧，肉眼能识别的是16帧，一般设置成30帧
@property (nonatomic, assign) NSInteger videoFrameRate;

/// 设置水印view
@property (nonatomic, strong, nullable) UIView *warterMarkView;

/// 当前帧图片
@property (nonatomic, strong, nullable) UIImage *currentImage;

/// 视频是否保存在本地
@property (nonatomic, assign) BOOL saveLocalVideo;

/// 本地录像保存路径
@property (nonatomic, strong, nullable) NSURL *saveLocalVideoPath;


- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

- (nullable instancetype)initWithVideoConfiguration:(nullable WSLiveVideoConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

@end
