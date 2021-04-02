//
//  LFStreamRTMPSocket.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "WSStreamRTMPSocket.h"

#if __has_include(<pili-librtmp/rtmp.h>)
#import <pili-librtmp/rtmp.h>
#else
#import "rtmp.h"
#endif

static const NSInteger RetryTimesBreaken = 5;  ///<  重连1分钟  3秒一次 一共20次
static const NSInteger RetryTimesMargin = 3;


#define RTMP_RECEIVE_TIMEOUT    2
#define DATA_ITEMS_MAX_COUNT 100
#define RTMP_DATA_RESERVE_SIZE 400
#define RTMP_HEAD_SIZE (sizeof(RTMPPacket) + RTMP_MAX_HEADER_SIZE)

#define SAVC(x)    static const AVal av_ ## x = AVC(#x)

static const AVal av_setDataFrame = AVC("@setDataFrame");
static const AVal av_SDKVersion = AVC("WSLiveStream 0.0.0");
SAVC(onMetaData);
SAVC(duration);
SAVC(width);
SAVC(height);
SAVC(videocodecid);
SAVC(videodatarate);
SAVC(framerate);
SAVC(audiocodecid);
SAVC(audiodatarate);
SAVC(audiosamplerate);
SAVC(audiosamplesize);
//SAVC(audiochannels);
SAVC(stereo);
SAVC(encoder);
//SAVC(av_stereo);
SAVC(fileSize);
SAVC(avc1);
SAVC(mp4a);

@interface WSStreamRTMPSocket ()<LFStreamingBufferDelegate>
{
    PILI_RTMP *_rtmp;
}
@property (nonatomic, weak) id<WSStreamSocketDelegate> delegate;
@property (nonatomic, strong) WSLiveStreamInfo *stream;
@property (nonatomic, strong) WSStreamingBuffer *buffer;
@property (nonatomic, strong) WSLiveDebug *debugInfo;
@property (nonatomic, strong) dispatch_queue_t rtmpSendQueue;
//错误信息
@property (nonatomic, assign) RTMPError error;
@property (nonatomic, assign) NSInteger retryTimes4netWorkBreaken;
@property (nonatomic, assign) NSInteger reconnectInterval;
@property (nonatomic, assign) NSInteger reconnectCount;

@property (atomic, assign) BOOL isSending;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isConnecting;
@property (nonatomic, assign) BOOL isReconnecting;

@property (nonatomic, assign) BOOL sendVideoHead;
@property (nonatomic, assign) BOOL sendAudioHead;

@end

@implementation WSStreamRTMPSocket

#pragma mark -- LFStreamSocket
- (nullable instancetype)initWithStream:(nullable WSLiveStreamInfo *)stream{
    return [self initWithStream:stream reconnectInterval:0 reconnectCount:0];
}

- (nullable instancetype)initWithStream:(nullable WSLiveStreamInfo *)stream reconnectInterval:(NSInteger)reconnectInterval reconnectCount:(NSInteger)reconnectCount{
    if (!stream) @throw [NSException exceptionWithName:@"LFStreamRtmpSocket init error" reason:@"stream is nil" userInfo:nil];
    if (self = [super init]) {
        _stream = stream;
        if (reconnectInterval > 0) _reconnectInterval = reconnectInterval;
        else _reconnectInterval = RetryTimesMargin;
        
        if (reconnectCount > 0) _reconnectCount = reconnectCount;
        else _reconnectCount = RetryTimesBreaken;
        
        [self addObserver:self forKeyPath:@"isSending" options:NSKeyValueObservingOptionNew context:nil];//这里改成observer主要考虑一直到发送出错情况下，可以继续发送
    }
    return self;
}

- (void)dealloc{
    [self removeObserver:self forKeyPath:@"isSending"];
}

- (void)start {
    dispatch_async(self.rtmpSendQueue, ^{
        [self _start];
    });
}

- (void)_start {
    if (!_stream) return;
    if (_isConnecting) return;
    if (_rtmp != NULL) return;
    self.debugInfo.streamId = self.stream.streamId;
    self.debugInfo.uploadUrl = self.stream.url;
    self.debugInfo.isRtmp = YES;
    if (_isConnecting) return;
    
    _isConnecting = YES;
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
        [self.delegate socketStatus:self status:LivePending];
    }
    
    if (_rtmp != NULL) {
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
    }
    [self RTMP264_Connect:(char *)[_stream.url cStringUsingEncoding:NSASCIIStringEncoding]];
}

- (void)stop {
    dispatch_async(self.rtmpSendQueue, ^{
        [self _stop];
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    });
}

- (void)_stop {
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
        [self.delegate socketStatus:self status:LiveStop];
    }
    if (_rtmp != NULL) {
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
        _rtmp = NULL;
    }
    [self clean];
}

- (void)sendFrame:(WSFrame *)frame {
    if (!frame) return;
    [self.buffer appendObject:frame];
    
    if(!self.isSending){
        [self sendFrame];
    }
}

- (void)setDelegate:(id<WSStreamSocketDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark -- CustomMethod
- (void)sendFrame {
    __weak typeof(self) _self = self;
     dispatch_async(self.rtmpSendQueue, ^{
        if (!_self.isSending && _self.buffer.list.count > 0) {
            _self.isSending = YES;

            if (!_self.isConnected || _self.isReconnecting || _self.isConnecting || !_rtmp){
                _self.isSending = NO;
                return;
            }

            // 调用发送接口
            WSFrame *frame = [_self.buffer popFirstObject];
            if ([frame isKindOfClass:[WSVideoFrame class]]) {
                if (!_self.sendVideoHead) {
                    _self.sendVideoHead = YES;
                    if(!((WSVideoFrame*)frame).sps || !((WSVideoFrame*)frame).pps){
                        _self.isSending = NO;
                        return;
                    }
                    [_self sendVideoHeader:(WSVideoFrame *)frame];
                } else {
                    [_self sendVideo:(WSVideoFrame *)frame];
                }
            } else {
                if (!_self.sendAudioHead) {
                    _self.sendAudioHead = YES;
                    if(!((WSAudioFrame*)frame).audioInfo){
                        _self.isSending = NO;
                        return;
                    }
                    [_self sendAudioHeader:(WSAudioFrame *)frame];
                } else {
                    [_self sendAudio:frame];
                }
            }

            //debug更新
            _self.debugInfo.totalFrame++;
            _self.debugInfo.dropFrame += _self.buffer.lastDropFrames;
            _self.buffer.lastDropFrames = 0;

            _self.debugInfo.dataFlow += frame.data.length;
            _self.debugInfo.elapsedMilli = CACurrentMediaTime() * 1000 - _self.debugInfo.timeStamp;
            if (_self.debugInfo.elapsedMilli < 1000) {
                _self.debugInfo.bandwidth += frame.data.length;
                if ([frame isKindOfClass:[WSAudioFrame class]]) {
                    _self.debugInfo.capturedAudioCount++;
                } else {
                    _self.debugInfo.capturedVideoCount++;
                }

                _self.debugInfo.unSendCount = _self.buffer.list.count;
            } else {
                _self.debugInfo.currentBandwidth = _self.debugInfo.bandwidth;
                _self.debugInfo.currentCapturedAudioCount = _self.debugInfo.capturedAudioCount;
                _self.debugInfo.currentCapturedVideoCount = _self.debugInfo.capturedVideoCount;
                if (_self.delegate && [_self.delegate respondsToSelector:@selector(socketDebug:debugInfo:)]) {
                    [_self.delegate socketDebug:_self debugInfo:_self.debugInfo];
                }
                _self.debugInfo.bandwidth = 0;
                _self.debugInfo.capturedAudioCount = 0;
                _self.debugInfo.capturedVideoCount = 0;
                _self.debugInfo.timeStamp = CACurrentMediaTime() * 1000;
            }
            
            //修改发送状态
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // 这里只为了不循环调用sendFrame方法 调用栈是保证先出栈再进栈
                _self.isSending = NO;
            });
            
        }
    });
}

- (void)clean {
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    _isConnected = NO;
    _sendAudioHead = NO;
    _sendVideoHead = NO;
    self.debugInfo = nil;
    [self.buffer removeAllObject];
    self.retryTimes4netWorkBreaken = 0;
}

- (NSInteger)RTMP264_Connect:(char *)push_url {
    //由于摄像头的timestamp是一直在累加，需要每次得到相对时间戳
    //分配与初始化
    _rtmp = PILI_RTMP_Alloc();
    PILI_RTMP_Init(_rtmp);

    //设置URL
    if (PILI_RTMP_SetupURL(_rtmp, push_url, &_error) == FALSE) {
        //log(LOG_ERR, "RTMP_SetupURL() failed!");
        goto Failed;
    }

    _rtmp->m_errorCallback = RTMPErrorCallback;
    _rtmp->m_connCallback = ConnectionTimeCallback;
    _rtmp->m_userData = (__bridge void *)self;
    _rtmp->m_msgCounter = 1;
    _rtmp->Link.timeout = RTMP_RECEIVE_TIMEOUT;
    
    //设置可写，即发布流，这个函数必须在连接前使用，否则无效
    PILI_RTMP_EnableWrite(_rtmp);

    //连接服务器
    if (PILI_RTMP_Connect(_rtmp, NULL, &_error) == FALSE) {
        goto Failed;
    }

    //连接流
    if (PILI_RTMP_ConnectStream(_rtmp, 0, &_error) == FALSE) {
        goto Failed;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
        [self.delegate socketStatus:self status:LiveStart];
    }

    [self sendMetaData];

    _isConnected = YES;
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    return 0;

Failed:
    PILI_RTMP_Close(_rtmp, &_error);
    PILI_RTMP_Free(_rtmp);
    _rtmp = NULL;
    [self reconnect];
    return -1;
}

#pragma mark -- Rtmp Send

- (void)sendMetaData {
    PILI_RTMPPacket packet;

    char pbuf[2048], *pend = pbuf + sizeof(pbuf);

    packet.m_nChannel = 0x03;                   // control channel (invoke)
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = RTMP_PACKET_TYPE_INFO;
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = _rtmp->m_stream_id;
    packet.m_hasAbsTimestamp = TRUE;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    char *enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_setDataFrame);
    enc = AMF_EncodeString(enc, pend, &av_onMetaData);

    *enc++ = AMF_OBJECT;

    enc = AMF_EncodeNamedNumber(enc, pend, &av_duration, 0.0);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_fileSize, 0.0);

    // videosize
    enc = AMF_EncodeNamedNumber(enc, pend, &av_width, _stream.videoConfiguration.videoSize.width);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_height, _stream.videoConfiguration.videoSize.height);

    // video
    enc = AMF_EncodeNamedString(enc, pend, &av_videocodecid, &av_avc1);

    enc = AMF_EncodeNamedNumber(enc, pend, &av_videodatarate, _stream.videoConfiguration.videoBitRate / 1000.f);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_framerate, _stream.videoConfiguration.videoFrameRate);

    // audio
    enc = AMF_EncodeNamedString(enc, pend, &av_audiocodecid, &av_mp4a);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiodatarate, _stream.audioConfiguration.audioBitrate);

    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiosamplerate, _stream.audioConfiguration.audioSampleRate);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiosamplesize, 16.0);
    enc = AMF_EncodeNamedBoolean(enc, pend, &av_stereo, _stream.audioConfiguration.numberOfChannels == 2);

    // sdk version
    enc = AMF_EncodeNamedString(enc, pend, &av_encoder, &av_SDKVersion);

    *enc++ = 0;
    *enc++ = 0;
    *enc++ = AMF_OBJECT_END;

    packet.m_nBodySize = (uint32_t)(enc - packet.m_body);
    if (!PILI_RTMP_SendPacket(_rtmp, &packet, FALSE, &_error)) {
        return;
    }
}

- (void)sendVideoHeader:(WSVideoFrame *)videoFrame {
    if (videoFrame.vps) {
        [self sendH265VideoHeader:videoFrame];
    } else {
        [self sendH264VideoHeader:videoFrame];
    }
}

- (void)sendH264VideoHeader:(WSVideoFrame *)videoFrame {

    unsigned char *body = NULL;
    NSInteger iIndex = 0;
    NSInteger rtmpLength = 1024;
    const char *sps = videoFrame.sps.bytes;
    const char *pps = videoFrame.pps.bytes;
    NSInteger sps_len = videoFrame.sps.length;
    NSInteger pps_len = videoFrame.pps.length;

    body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);

    body[iIndex++] = 0x17;
    body[iIndex++] = 0x00;

    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;

    body[iIndex++] = 0x01;
    body[iIndex++] = sps[1];
    body[iIndex++] = sps[2];
    body[iIndex++] = sps[3];
    body[iIndex++] = 0xff;

    /*sps*/
    body[iIndex++] = 0xe1;
    body[iIndex++] = (sps_len >> 8) & 0xff;
    body[iIndex++] = sps_len & 0xff;
    memcpy(&body[iIndex], sps, sps_len);
    iIndex += sps_len;

    /*pps*/
    body[iIndex++] = 0x01;
    body[iIndex++] = (pps_len >> 8) & 0xff;
    body[iIndex++] = (pps_len) & 0xff;
    memcpy(&body[iIndex], pps, pps_len);
    iIndex += pps_len;

    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
    free(body);
}

- (void)sendH265VideoHeader:(WSVideoFrame *)videoFrame {
// https://blog.csdn.net/qq_33795447/article/details/89457581
    const char *sps = videoFrame.sps.bytes;
    const char *pps = videoFrame.pps.bytes;
    const char *vps = videoFrame.vps.bytes;
    NSInteger sps_len = videoFrame.sps.length;
    NSInteger pps_len = videoFrame.pps.length;
    NSInteger vps_len = videoFrame.vps.length;
    
    NSInteger rtmpLength = 1024;
    unsigned char * body=NULL;
    body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);
        int i = 0;
        body[i++] = 0x1C;
        body[i++] = 0x00;
        body[i++] = 0x00;
        body[i++] = 0x00;
        body[i++] = 0x00;
        body[i++] = 0x00;
     
        //general_profile_idc 8bit
        body[i++] = sps[1];
        //general_profile_compatibility_flags 32 bit
        body[i++] = sps[2];
        body[i++] = sps[3];
        body[i++] = sps[4];
        body[i++] = sps[5];
     
        // 48 bit NUll nothing deal in rtmp
        body[i++] = sps[6];
        body[i++] = sps[7];
        body[i++] = sps[8];
        body[i++] = sps[9];
        body[i++] = sps[10];
        body[i++] = sps[11];
     
        //general_level_idc
        body[i++] = sps[12];
     
        // 48 bit NUll nothing deal in rtmp
        body[i++] = 0x00;
        body[i++] = 0x00;
        body[i++] = 0x00;
        body[i++] = 0x00;
        body[i++] = 0x00;
        body[i++] = 0x00;
     
        //bit(16) avgFrameRate;
        body[i++] = 0x00;
        body[i++] = 0x00;
     
        /* bit(2) constantFrameRate; */
        /* bit(3) numTemporalLayers; */
        /* bit(1) temporalIdNested; */
        body[i++] = 0x00;
     
        /* unsigned int(8) numOfArrays; 03 */
        body[i++] = 0x03;
     
        printf("HEVCDecoderConfigurationRecord data = %s\n", body);
        body[i++] = 0x20;  //vps 32
        body[i++] = (1 >> 8) & 0xff;
        body[i++] = 1 & 0xff;
        body[i++] = (vps_len >> 8) & 0xff;
        body[i++] = (vps_len) & 0xff;
        memcpy(&body[i], vps, vps_len);
        i += vps_len;
     
        //sps
        body[i++] = 0x21; //sps 33
        body[i++] = (1 >> 8) & 0xff;
        body[i++] = 1 & 0xff;
        body[i++] = (sps_len >> 8) & 0xff;
        body[i++] = sps_len & 0xff;
        memcpy(&body[i], sps, sps_len);
        i += sps_len;
     
        //pps
        body[i++] = 0x22; //pps 34
        body[i++] = (1 >> 8) & 0xff;
        body[i++] = 1 & 0xff;
        body[i++] = (pps_len >> 8) & 0xff;
        body[i++] = (pps_len) & 0xff;
        memcpy(&body[i], pps, pps_len);
        i += pps_len;
     
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:i nTimestamp:0];
    free(body);
}

- (void)sendVideo:(WSVideoFrame *)frame {
    if (frame.vps) {
        [self sendH265Video:frame];
    } else {
        [self sendH264Video:frame];
    }
}

- (void)sendH264Video:(WSVideoFrame *)frame {
   // 字节说明：
    ///  第N字节          说明
    ///             0
    NSInteger i = 0;
    NSInteger rtmpLength = frame.data.length + 9;
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);

    // 是否为关键帧
    if (frame.isKeyFrame) {
        body[i++] = 0x17;        // 1:I帧  7:AVC
    } else {
        body[i++] = 0x27;        // 2:P帧  7:AVC
    }
    // AVPacketType：
    // 0x00 -- AVC sequence header （即AVCc 保存AVC的profie和 SPS PPS等信息）
    // 0x01 -- AVC NALU 普通的NALU
    // 0X02 -- AVC end of sequence
    body[i++] = 0x01;
    
    body[i++] = 0x00; //
    body[i++] = 0x00;
    body[i++] = 0x00;
    
    body[i++] = (frame.data.length >> 24) & 0xff;
    body[i++] = (frame.data.length >> 16) & 0xff;
    body[i++] = (frame.data.length >>  8) & 0xff;
    body[i++] = (frame.data.length) & 0xff;
    memcpy(&body[i], frame.data.bytes, frame.data.length);

    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:frame.timestamp];
    free(body);
}

- (void)sendH265Video:(WSVideoFrame *)frame
{
    NSInteger i = 0;
    NSInteger rtmpLength = frame.data.length + 9;
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);

    // 是否为关键帧
    if (frame.isKeyFrame) {
        body[i++] = 0x1C;        // 1:I帧  C:AVC/H264
    } else {
        body[i++] = 0x2C;        // 2:P帧  C:AVC/H265
    }
    // AVPacketType：
    // 0x00 -- AVC sequence header （即AVCc 保存AVC的profie和 SPS PPS等信息）
    // 0x01 -- AVC NALU 普通的NALU
    // 0X02 -- AVC end of sequence
    body[i++] = 0x01;
    
    body[i++] = 0x00; //
    body[i++] = 0x00;
    body[i++] = 0x00;
    
    body[i++] = (frame.data.length >> 24) & 0xff;
    body[i++] = (frame.data.length >> 16) & 0xff;
    body[i++] = (frame.data.length >>  8) & 0xff;
    body[i++] = (frame.data.length) & 0xff;
    memcpy(&body[i], frame.data.bytes, frame.data.length);

    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:frame.timestamp];
    free(body);
}

- (NSInteger)sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger)size nTimestamp:(uint64_t)nTimestamp {
    NSInteger rtmpLength = size;
    PILI_RTMPPacket rtmp_pack;
    PILI_RTMPPacket_Reset(&rtmp_pack);
    PILI_RTMPPacket_Alloc(&rtmp_pack, (uint32_t)rtmpLength);

    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body, data, size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType; // 包类型
    if (_rtmp) rtmp_pack.m_nInfoField2 = _rtmp->m_stream_id;
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size != 4) {
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;

    NSInteger nRet = [self RtmpPacketSend:&rtmp_pack];

    PILI_RTMPPacket_Free(&rtmp_pack);
    return nRet;
}

- (NSInteger)RtmpPacketSend:(PILI_RTMPPacket *)packet {
    if (_rtmp && PILI_RTMP_IsConnected(_rtmp)) {
        int success = PILI_RTMP_SendPacket(_rtmp, packet, 0, &_error);
        return success;
    }
    return -1;
}

- (void)sendAudioHeader:(WSAudioFrame *)audioFrame {

    NSInteger rtmpLength = audioFrame.audioInfo.length + 2;     /*spec data长度,一般是2*/
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);

    /*AF 00 + AAC RAW data*/
    body[0] = 0xAF;
    body[1] = 0x00;
    memcpy(&body[2], audioFrame.audioInfo.bytes, audioFrame.audioInfo.length);          /*spec_buf是AAC sequence header数据*/
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:0];
    free(body);
}

- (void)sendAudio:(WSFrame *)frame {

    NSInteger rtmpLength = frame.data.length + 2;    /*spec data长度,一般是2*/
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);

    /*AF 01 + AAC RAW data*/
    body[0] = 0xAF;
    body[1] = 0x01;
    memcpy(&body[2], frame.data.bytes, frame.data.length);
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:frame.timestamp];
    free(body);
}

// 断线重连
- (void)reconnect {
    dispatch_async(self.rtmpSendQueue, ^{
        if (self.retryTimes4netWorkBreaken++ < self.reconnectCount && !self.isReconnecting) {
            self.isConnected = NO;
            self.isConnecting = NO;
            self.isReconnecting = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                 [self performSelector:@selector(_reconnect) withObject:nil afterDelay:self.reconnectInterval];
            });
           
        } else if (self.retryTimes4netWorkBreaken >= self.reconnectCount) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
                [self.delegate socketStatus:self status:LiveError];
            }
            if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidError:errorCode:)]) {
                [self.delegate socketDidError:self errorCode:LiveSocketErrorReConnectTimeOut];
            }
        }
    });
}

- (void)_reconnect{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    _isReconnecting = NO;
    if(_isConnected) return;
    
    _isReconnecting = NO;
    if (_isConnected) return;
    if (_rtmp != NULL) {
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
        _rtmp = NULL;
    }
    _sendAudioHead = NO;
    _sendVideoHead = NO;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
        [self.delegate socketStatus:self status:LiveRefresh];
    }
    
    if (_rtmp != NULL) {
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
    }
    [self RTMP264_Connect:(char *)[_stream.url cStringUsingEncoding:NSASCIIStringEncoding]];
}

#pragma mark -- CallBack
void RTMPErrorCallback(RTMPError *error, void *userData) {
    WSStreamRTMPSocket *socket = (__bridge WSStreamRTMPSocket *)userData;
    if (error->code < 0) {
        [socket reconnect];
    }
}

void ConnectionTimeCallback(PILI_CONNECTION_TIME *conn_time, void *userData) {
}

#pragma mark -- LFStreamingBufferDelegate
- (void)streamingBuffer:(nullable WSStreamingBuffer *)buffer bufferState:(LFLiveBuffferState)state{
    if(self.delegate && [self.delegate respondsToSelector:@selector(socketBufferStatus:status:)]){
        [self.delegate socketBufferStatus:self status:state];
    }
}

#pragma mark -- Observer
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if([keyPath isEqualToString:@"isSending"]){
        if(!self.isSending){
            [self sendFrame];
        }
    }
}

#pragma mark -- Getter Setter

- (WSStreamingBuffer *)buffer {
    if (!_buffer) {
        _buffer = [[WSStreamingBuffer alloc] init];
        _buffer.delegate = self;

    }
    return _buffer;
}

- (WSLiveDebug *)debugInfo {
    if (!_debugInfo) {
        _debugInfo = [[WSLiveDebug alloc] init];
    }
    return _debugInfo;
}

- (dispatch_queue_t)rtmpSendQueue{
    if(!_rtmpSendQueue){
        _rtmpSendQueue = dispatch_queue_create("com.youku.LaiFeng.RtmpSendQueue", NULL);
    }
    return _rtmpSendQueue;
}

@end
