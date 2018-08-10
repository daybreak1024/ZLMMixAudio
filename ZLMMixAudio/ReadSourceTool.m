//
//  ReadSourceTool.m
//  ZLMMixAudio
//
//  Created by 周黎明 on 2018/8/10.
//  Copyright © 2018 周黎明. All rights reserved.
//

#import "ReadSourceTool.h"
#import <AVFoundation/AVFoundation.h>
const Float64 kGraphSampleRate = 44100.0; // 48000.0 optional tests

@implementation ReadSourceTool
+ (SoundBuffer)getAudioFormLoacl:(NSString *)path{
    SoundBuffer soundBufferP;
    memset(&soundBufferP, 0, sizeof(SoundBuffer));
    
    OSStatus result = noErr;

    // 获取资源路径
    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, false);
    
    ExtAudioFileRef fp;
    // 打开文件
    result = ExtAudioFileOpenURL(url, &fp);
    NSAssert(result == noErr, @"ExtAudioFileOpenURL result Error");
    
    // 读取文件的实际 formt
    AudioStreamBasicDescription fileFormat;
    UInt32 propSize = sizeof(AudioStreamBasicDescription);;
    result = ExtAudioFileGetProperty(fp, kExtAudioFileProperty_FileDataFormat, &propSize, &fileFormat);
    NSAssert(result == noErr, @"ExtAudioFileGetProperty result Error");
    
    // 获取文件的 frames length
    UInt64 numFrames = 0; // 帧数
    propSize = sizeof(numFrames);
    result = ExtAudioFileGetProperty(fp, kExtAudioFileProperty_FileLengthFrames,&propSize, &numFrames);
    NSAssert(result == noErr, @"ExtAudioFileSetProperty result Error");
    
    double rateRatio = kGraphSampleRate/fileFormat.mSampleRate;// 计算出原始和转化后的 sample frames 比例
    numFrames = numFrames * rateRatio; // 算出转化后的 numFrames 数量
    UInt32 channel = fileFormat.mChannelsPerFrame; // 声道数
    // 设置读取 formt
    AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                   sampleRate:kGraphSampleRate
                                                                     channels:channel
                                                                  interleaved:NO]; // 读取的格式
    // 设置从文件中读出的音频格式
    result = ExtAudioFileSetProperty(fp, kExtAudioFileProperty_ClientDataFormat,propSize, clientFormat.streamDescription);
    NSAssert(result == noErr, @"ExtAudioFileSetProperty result Error");
    
    // 初始化数据结构体
    soundBufferP.numFrames = (UInt32)numFrames;
    soundBufferP.channelCount = channel;
    soundBufferP.asbd      = *(clientFormat.streamDescription);
    soundBufferP.leftData = (Float32 *)calloc(numFrames, sizeof(Float32));
    if (channel == 2) {
        soundBufferP.rightData = (Float32 *)calloc(numFrames, sizeof(Float32));
    }
    soundBufferP.sampleNum = 0;
    
    AudioBufferList *bufList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer)*(channel-1));
    bufList->mNumberBuffers = channel;

    AudioBuffer emptyBuffer = {0};
    for (int arrayIndex = 0; arrayIndex < channel; arrayIndex++) {
        bufList->mBuffers[arrayIndex] = emptyBuffer;
        bufList->mBuffers[arrayIndex].mNumberChannels = 1;
        bufList->mBuffers[arrayIndex].mData = (arrayIndex == 0) ? soundBufferP.leftData : soundBufferP.rightData;
        bufList->mBuffers[arrayIndex].mDataByteSize = (UInt32)numFrames*sizeof(Float32);
    }
    
    // 读取数据
    UInt32 numberOfPacketsToRead = (UInt32) numFrames;
    result = ExtAudioFileRead(fp, &numberOfPacketsToRead,bufList);
    NSAssert(result == noErr, @"ExtAudioFileRead result Error");

    free(bufList);
    ExtAudioFileDispose(fp);

    
    return soundBufferP;
}
@end
