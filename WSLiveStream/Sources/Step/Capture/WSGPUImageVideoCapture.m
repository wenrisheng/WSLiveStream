//
//  WSVideoCapture.m
//  WSLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "WSGPUImageVideoCapture.h"
#import "GPUImageBeautyFilter.h"
#import "GPUImageEmptyFilter.h"

#if __has_include(<GPUImage/GPUImage.h>)
#import <GPUImage/GPUImage.h>
#elif __has_include("GPUImage/GPUImage.h")
#import "GPUImage/GPUImage.h"
#else
#import "GPUImage.h"
#endif

@interface WSGPUImageVideoCapture ()

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) GPUImageBeautyFilter *beautyFilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageCropFilter *cropfilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *output;
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) WSLiveVideoConfiguration *configuration;

@property (nonatomic, strong) GPUImageAlphaBlendFilter *blendFilter;
@property (nonatomic, strong) GPUImageUIElement *uiElementInput;
@property (nonatomic, strong) UIView *waterMarkContentView;

@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;

@end

@implementation WSGPUImageVideoCapture

@synthesize torch = _torch;
@synthesize beautyLevel = _beautyLevel;
@synthesize brightLevel = _brightLevel;
@synthesize toneLevel = _toneLevel;
@synthesize zoomScale = _zoomScale;

#pragma mark -
- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.videoCamera) {
        [self.videoCamera stopCameraCapture];
        self.videoCamera = nil;
    }
    if (self.gpuImageView) {
        [self.gpuImageView removeFromSuperview];
        self.gpuImageView = nil;
    }
}

- (instancetype)initWithVideoConfiguration:(WSLiveVideoConfiguration *)configuration {
    self = [super init];
    if (self = [super init]) {
        self.configuration = configuration;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        
        self.beautyFace = YES;
        self.beautyLevel = 0.5;
        self.brightLevel = 0.5;
        self.toneLevel = 0.5;
        self.zoomScale = 1.0;
        self.mirror = YES;
        self.saveLocalVideo = NO;
        
        self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionFront];
        self.videoCamera.outputImageOrientation = _configuration.outputImageOrientation; // 设置视频输出方向，不然看到的视频会反向
        self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
        self.videoCamera.horizontallyMirrorRearFacingCamera = NO;
        self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate; // 设置帧率
    }
    return self;
}

#pragma mark -- Setter Getter

- (void)setRunning:(BOOL)running {
    if (_running == running) {
        return;
    }
    _running = running;
    
    if (!_running) {
        [self idleTimeDisabled:NO];
        [self.videoCamera stopCameraCapture];
        if(self.saveLocalVideo) {
            [self.movieWriter finishRecording];
        }
    } else {
        // 禁止手机休眠
        [self idleTimeDisabled:YES];
        [self reloadFilter];
        [self.videoCamera startCameraCapture];
        if(self.saveLocalVideo) {
            [self.movieWriter startRecording];
        }
    }
}

- (void)idleTimeDisabled:(BOOL)disabled
{
    if ([NSThread isMainThread] == NO) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication sharedApplication].idleTimerDisabled = disabled;
        });
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = disabled;
    }
}

- (void)setPreView:(UIView *)preView {
    if (preView == self.gpuImageView.superview) {
        return;
    }
    if (self.gpuImageView.superview) {
        [self.gpuImageView removeFromSuperview];
    }
    [preView insertSubview:self.gpuImageView atIndex:0];
    UIView *subView = self.gpuImageView;
    UIView *superView = preView;
    subView.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0];
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:subView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:superView attribute:NSLayoutAttributeRight multiplier:1.0 constant:0];
    [superView addConstraints:@[top, bottom, left, right]];
}

- (UIView *)preView {
    return self.gpuImageView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    if(captureDevicePosition == self.videoCamera.cameraPosition) {
        return;
    }
    [self.videoCamera rotateCamera];
    self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    [self reloadMirror];
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return [self.videoCamera cameraPosition];
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate {
    if (videoFrameRate <= 0) {
        return;
    }
    if (videoFrameRate == self.videoCamera.frameRate) {
        return;
    }
    self.videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate {
    return self.videoCamera.frameRate;
}

- (void)setTorch:(BOOL)torch {
    if (!self.videoCamera.captureSession) {
        return;
    }
    BOOL ret = NO;
    AVCaptureSession *session = (AVCaptureSession *)self.videoCamera.captureSession;
    [session beginConfiguration];
    if (self.videoCamera.inputCamera) {
        if (self.videoCamera.inputCamera.torchAvailable) {
            NSError *err = nil;
            if ([self.videoCamera.inputCamera lockForConfiguration:&err]) {
                [self.videoCamera.inputCamera setTorchMode:(torch ? AVCaptureTorchModeOn : AVCaptureTorchModeOff) ];
                [self.videoCamera.inputCamera unlockForConfiguration];
                ret = (self.videoCamera.inputCamera.torchMode == AVCaptureTorchModeOn);
            } else {
                ret = NO;
            }
        }
    }
    [session commitConfiguration];
    _torch = ret;
}

- (BOOL)torch {
    return self.videoCamera.inputCamera.torchMode;
}

- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
}

- (void)setBeautyFace:(BOOL)beautyFace{
    _beautyFace = beautyFace;
    [self reloadFilter];
}

- (void)setBeautyLevel:(CGFloat)beautyLevel {
    _beautyLevel = beautyLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setBeautyLevel:_beautyLevel];
    }
}

- (CGFloat)beautyLevel {
    return _beautyLevel;
}

- (void)setBrightLevel:(CGFloat)brightLevel {
    _brightLevel = brightLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setBrightLevel:brightLevel];
    }
}

- (CGFloat)brightLevel {
    return _brightLevel;
}

- (void)setToneLevel:(CGFloat)toneLevel
{
    _toneLevel = toneLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setToneLevel:toneLevel];
    }
}

- (CGFloat)toneLevel
{
    return _toneLevel;
}

- (void)setZoomScale:(CGFloat)zoomScale {
    if (self.videoCamera && self.videoCamera.inputCamera) {
        AVCaptureDevice *device = (AVCaptureDevice *)self.videoCamera.inputCamera;
        if ([device lockForConfiguration:nil]) {
            device.videoZoomFactor = zoomScale;
            [device unlockForConfiguration];
            _zoomScale = zoomScale;
        }
    }
}

- (CGFloat)zoomScale {
    return _zoomScale;
}

- (void)setWarterMarkView:(UIView *)warterMarkView{
    if(_warterMarkView && _warterMarkView.superview){
        [_warterMarkView removeFromSuperview];
        _warterMarkView = nil;
    }
    _warterMarkView = warterMarkView;
    self.blendFilter.mix = warterMarkView.alpha;
    [self.waterMarkContentView addSubview:_warterMarkView];
    [self reloadFilter];
}

- (GPUImageUIElement *)uiElementInput{
    if(!_uiElementInput){
        _uiElementInput = [[GPUImageUIElement alloc] initWithView:self.waterMarkContentView];
    }
    return _uiElementInput;
}

- (GPUImageAlphaBlendFilter *)blendFilter {
    if(!_blendFilter){
        _blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
        _blendFilter.mix = 1.0;
        [_blendFilter disableSecondFrameCheck];
    }
    return _blendFilter;
}

- (UIView *)waterMarkContentView {
    if(!_waterMarkContentView){
        _waterMarkContentView = [UIView new];
        _waterMarkContentView.frame = CGRectMake(0, 0, self.configuration.videoSize.width, self.configuration.videoSize.height);
        _waterMarkContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _waterMarkContentView;
}

- (GPUImageView *)gpuImageView {
    if(!_gpuImageView){
        _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    }
    return _gpuImageView;
}

-(UIImage *)currentImage {
    if(_filter){
        [_filter useNextFrameForImageCapture];
        return _filter.imageFromCurrentFramebuffer;
    }
    return nil;
}

- (GPUImageMovieWriter*)movieWriter {
    if(!_movieWriter){
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.saveLocalVideoPath size:self.configuration.videoSize];
        _movieWriter.encodingLiveVideo = YES;
        _movieWriter.shouldPassthroughAudio = YES;
        self.videoCamera.audioEncodingTarget = self.movieWriter;
    }
    return _movieWriter;
}

#pragma mark -- 处理帧数据
- (void)processVideo:(GPUImageOutput *)output {
    __weak typeof(self) _self = self;
    @autoreleasepool {
        GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
        CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];
        if (pixelBuffer && _self.delegate && [_self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]) {
            [_self.delegate captureOutput:_self pixelBuffer:pixelBuffer];
        }
    }
}

- (void)reloadFilter {
    [self.filter removeAllTargets];
    [self.blendFilter removeAllTargets];
    [self.uiElementInput removeAllTargets];
    [self.videoCamera removeAllTargets];
    [self.output removeAllTargets];
    [self.cropfilter removeAllTargets];
    
    if (self.beautyFace) { // 开启美颜
        self.output = [[GPUImageEmptyFilter alloc] init];
        self.filter = [[GPUImageBeautyFilter alloc] init];
        self.beautyFilter = (GPUImageBeautyFilter *)self.filter;
    } else { // 不开启美颜
        self.output = [[GPUImageEmptyFilter alloc] init];
        self.filter = [[GPUImageEmptyFilter alloc] init];
        self.beautyFilter = nil;
    }
    
    /// 调节镜像
    [self reloadMirror];
    
    // 480*640 比例为4:3  强制转换为16:9
    if([self.configuration.avSessionPreset isEqualToString:AVCaptureSessionPreset640x480]){
        CGRect cropRect = self.configuration.landscape ? CGRectMake(0, 0.125, 1, 0.75) : CGRectMake(0.125, 0, 0.75, 1);
        self.cropfilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
        [self.videoCamera addTarget:self.cropfilter];
        [self.cropfilter addTarget:self.filter];
    }else{
        [self.videoCamera addTarget:self.filter];
    }
    
    // 添加水印
    if(self.warterMarkView){
        // filter和uiElementInput同时输出到blendFilter混合通道
        [self.filter addTarget:self.blendFilter];
        /// GPUImageUIElement将waterMarkContentView属性的视图转为纹理，输入到输出源
        [self.uiElementInput addTarget:self.blendFilter];
        
        [self.blendFilter addTarget:self.gpuImageView];
        if(self.saveLocalVideo) {
            [self.blendFilter addTarget:self.movieWriter];
        }
        [self.filter addTarget:self.output];
        [self.uiElementInput update];
    }else{
        [self.filter addTarget:self.output];
        [self.output addTarget:self.gpuImageView];
        if(self.saveLocalVideo) {
            [self.output addTarget:self.movieWriter];
        }
    }
    
    [self.filter forceProcessingAtSize:self.configuration.videoSize];
    [self.output forceProcessingAtSize:self.configuration.videoSize];
    [self.blendFilter forceProcessingAtSize:self.configuration.videoSize];
    [self.uiElementInput forceProcessingAtSize:self.configuration.videoSize];
    
    
    // 输出数据
    __weak typeof(self) _self = self;
    [self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        [_self processVideo:output];
    }];
    
}

- (void)reloadMirror{
    if(self.mirror && self.captureDevicePosition == AVCaptureDevicePositionFront){
        self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
    }else{
        self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
    }
}

#pragma mark Notification

- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self.videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)statusBarChanged:(NSNotification *)notification {
    UIInterfaceOrientation statusBar = [[UIApplication sharedApplication] statusBarOrientation];

    if(self.configuration.autorotate){ // 配置了自动旋转
        if (self.configuration.landscape) {
            if (statusBar == UIInterfaceOrientationLandscapeLeft) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
            } else if (statusBar == UIInterfaceOrientationLandscapeRight) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
            }
        } else {
            if (statusBar == UIInterfaceOrientationPortrait) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortraitUpsideDown;
            } else if (statusBar == UIInterfaceOrientationPortraitUpsideDown) {
                self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
            }
        }
    }
}

@end
