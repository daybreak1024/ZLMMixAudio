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
    
    OSStatus result = noErr;

    /* 获取资源路径 */
    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)path, kCFURLPOSIXPathStyle, false);
    
    ExtAudioFileRef fp = 0;
    /* 打开文件 */
    result = ExtAudioFileOpenURL(url, &fp);
    NSAssert(result == noErr || fp, @"ExtAudioFileOpenURL result Error");
    
    /* 读取文件的实际 formt*/
    AudioStreamBasicDescription fileFormat;
    UInt32 propSize = sizeof(fileFormat);;
    result = ExtAudioFileGetProperty(fp, kExtAudioFileProperty_FileDataFormat, &propSize, &fileFormat);
    NSAssert(result == noErr, @"ExtAudioFileGetProperty result Error");
    
//    UInt32 channel = fileFormat.mChannelsPerFrame; // 声道数
    UInt32 channel = 1;
    if (fileFormat.mChannelsPerFrame == 2) {
        channel = 2;
    }
    // 计算出原始和转化后的 sample frames 比例
    double rateRatio = kGraphSampleRate / fileFormat.mSampleRate;
    
    
    /*设置读取 formt*/
    // 读取时的格式
    AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:kGraphSampleRate channels:channel interleaved:NO];
    propSize = sizeof(AudioStreamBasicDescription);
    // 设置从文件中读出的音频格式
    result = ExtAudioFileSetProperty(fp, kExtAudioFileProperty_ClientDataFormat,propSize, clientFormat.streamDescription);
    NSAssert(result == noErr, @"ExtAudioFileSetProperty result Error");
    
    
    /* 获取文件的 frames length (设置读取格式后读取才能读取准确)*/
    UInt64 numFrames = 0; // 帧数
    propSize = sizeof(numFrames);
    result = ExtAudioFileGetProperty(fp, kExtAudioFileProperty_FileLengthFrames,&propSize, &numFrames);
    NSAssert(result == noErr, @"ExtAudioFileSetProperty result Error");
    
    // 算出转化后的 numFrames 数量
    numFrames = numFrames * rateRatio;
   
    // 初始化数据结构体
    SoundBuffer soundBuffer;
    memset(&soundBuffer, 0, sizeof(SoundBuffer));
    soundBuffer.numFrames = (UInt32)numFrames;
    soundBuffer.channelCount = channel;
    soundBuffer.asbd      = *(clientFormat.streamDescription);
    UInt32 samples = (UInt32)numFrames;

    soundBuffer.leftData = (Float32 *)calloc(samples, sizeof(Float32));
    if (channel == 2) {
        soundBuffer.rightData = (Float32 *)calloc(samples, sizeof(Float32));
    }
    soundBuffer.sampleNum = 0;

    //如果是立体声，还要多为AudioBuffer申请一个空间存放右声道数据
    AudioBufferList *bufList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + sizeof(AudioBuffer)*(channel-1));
    AudioBuffer emptyBuffer = {0};
    bufList->mNumberBuffers = channel;
    
    for (int arrayIndex = 0; arrayIndex < channel; arrayIndex++) {
        bufList->mBuffers[arrayIndex] = emptyBuffer;
    }
    bufList->mBuffers[0].mNumberChannels = 1;
    bufList->mBuffers[0].mData = soundBuffer.leftData;
    bufList->mBuffers[0].mDataByteSize = (UInt32)numFrames*sizeof(Float32);
    
    if (2 == channel) {
        bufList->mBuffers[1].mNumberChannels = 1;
        bufList->mBuffers[1].mDataByteSize = (UInt32)numFrames*sizeof(Float32);
        bufList->mBuffers[1].mData = soundBuffer.rightData;
    }
    
    UInt32 numberOfPacketsToRead = (UInt32) numFrames;
    // 读取数据
    ExtAudioFileRead(fp, &numberOfPacketsToRead, bufList);
    NSAssert(result == noErr, @"ExtAudioFileRead result Error");

    free(bufList);
    ExtAudioFileDispose(fp);
 
    return soundBuffer;
}
@end
