//
//  LFLiveAudioConfiguration.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>

/// 音频码率 (默认96Kbps)
typedef NS_ENUM (NSUInteger, WSLiveAudioBitRate) {
    /// 32Kbps 音频码率
    LiveAudioBitRate_32Kbps = 32000,
    /// 64Kbps 音频码率
    LiveAudioBitRate_64Kbps = 64000,
    /// 96Kbps 音频码率
    LiveAudioBitRate_96Kbps = 96000,
    /// 128Kbps 音频码率
    LiveAudioBitRate_128Kbps = 128000,
    /// 默认音频码率，默认为 96Kbps
    LiveAudioBitRate_Default = LiveAudioBitRate_96Kbps
};

/// 音频采样率 (默认44.1KHz)
typedef NS_ENUM (NSUInteger, WSLiveAudioSampleRate){
    /// 16KHz 采样率
    LiveAudioSampleRate_16000Hz = 16000,
    /// 44.1KHz 采样率
    LiveAudioSampleRate_44100Hz = 44100,
    /// 48KHz 采样率
    LiveAudioSampleRate_48000Hz = 48000,
    /// 默认音频采样率，默认为 44.1KHz
    LiveAudioSampleRate_Default = LiveAudioSampleRate_44100Hz
};

///  Audio Live quality（音频质量）
typedef NS_ENUM (NSUInteger, LiveAudioQuality){
    /// 低音频质量 audio sample rate: 16KHz audio bitrate: numberOfChannels 1 : 32Kbps  2 : 64Kbps
    LiveAudioQualityLow = 0,
    /// 中音频质量 audio sample rate: 44.1KHz audio bitrate: 96Kbps
    LiveAudioQualityMedium = 1,
    /// 高音频质量 audio sample rate: 44.1MHz audio bitrate: 128Kbps
    LiveAudioQualityHigh = 2,
    /// 超高音频质量 audio sample rate: 48KHz, audio bitrate: 128Kbps
    LiveAudioQualityVeryHigh = 3,
    /// 默认音频质量 audio sample rate: 44.1KHz, audio bitrate: 96Kbps
    LiveAudioQualityDefault = LiveAudioQualityHigh
};

@interface WSLiveAudioConfiguration : NSObject<NSCoding, NSCopying>

/// 默认音频配置
+ (instancetype)defaultConfiguration;
/// 音频配置
+ (instancetype)defaultConfigurationForQuality:(LiveAudioQuality)audioQuality;

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================
/// 声道数目(default 2)
@property (nonatomic, assign) NSUInteger numberOfChannels;
/// 采样率
@property (nonatomic, assign) WSLiveAudioSampleRate audioSampleRate;
/// 码率
@property (nonatomic, assign) WSLiveAudioBitRate audioBitrate;
/// flv编码音频头 44100 为0x12 0x10
@property (nonatomic, assign, readonly) char *asc;
/// 缓存区长度
@property (nonatomic, assign,readonly) NSUInteger bufferLength;

@end
