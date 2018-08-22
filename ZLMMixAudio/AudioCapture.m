//
//  AudioCapture.m
//  ZLMMixAudio
//
//  Created by 周黎明 on 2018/8/20.
//  Copyright © 2018 周黎明. All rights reserved.
//

#import "AudioCapture.h"
#import "ReadSourceTool.h"
@interface AudioCapture ()

@property (nonatomic, assign) AudioComponent component;

@end
@implementation AudioCapture
- (instancetype)init{
    self = [super init];
    if(self){
        _channels = 2;
        AudioComponentDescription acd;
        acd.componentType = kAudioUnitType_Output;
        acd.componentSubType = kAudioUnitSubType_RemoteIO;
        acd.componentManufacturer = kAudioUnitManufacturer_Apple;
        acd.componentFlags = 0;
        acd.componentFlagsMask = 0;
        // 获得一个元件
        self.component = AudioComponentFindNext(NULL, &acd);
        // 获得 Audio Unit 实例
        OSStatus status = noErr;
        status = AudioComponentInstanceNew(self.component, &_componetInstance);
        if (status != noErr) {
            [self handleAudioComponentCreationFailure];
        }
        // 为录制打开 IO
        UInt32 flagOne = 1;
        AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
        // 描述音频格式
        AudioStreamBasicDescription desc = {0};
        desc.mSampleRate = kGraphSampleRate;
        desc.mFormatID = kAudioFormatLinearPCM;
        desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        desc.mChannelsPerFrame = _channels;
        desc.mFramesPerPacket = 1;
        desc.mBitsPerChannel = 16;
        desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
        desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
        // 设置音频格式
        AudioUnitSetProperty(self.componetInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &desc, sizeof(desc));
        // 设置数据采集回调函数
        AURenderCallbackStruct cb;
        cb.inputProcRefCon = (__bridge void *)(self);
        cb.inputProc = handleInputBuffer;
        AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));
        // 初始化
        status = AudioUnitInitialize(self.componetInstance);
        if (status != noErr) {
            [self handleAudioComponentCreationFailure];
        }
        
    }
    return self;
}

- (void)setRunning:(BOOL)running {
    if (_running == running) {
        return;
    }
    _running = running;
    if (running) {
            // 设置音频的Category，用于处理和其他app音频关系
            AudioOutputUnitStart(self.componetInstance);    // 开启 Audio Unit
    } else {
            AudioOutputUnitStop(self.componetInstance); // 停止 Audio Unit
    }
}

- (void)handleAudioComponentCreationFailure {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"error");
    });
}

static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    @autoreleasepool {
        AudioCapture *source = (__bridge AudioCapture *)inRefCon;
        if (!source) {
            return -1;
        }
        
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;
        
        AudioBufferList buffers;    // bufferList 里存放着一堆 buffers，buffers 的长度是动态的
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = buffer;
        // 获得录制的采样数据
        OSStatus status = AudioUnitRender(source.componetInstance,
                                          ioActionFlags,
                                          inTimeStamp,
                                          inBusNumber,
                                          inNumberFrames,
                                          &buffers);
        // 采样数据已经在 bufferList 中的 buffers 中了
//        if (source.muted) {
//            for (int i = 0; i < buffers.mNumberBuffers; i++) {
//                AudioBuffer ab = buffers.mBuffers[i];
//                memset(ab.mData, 0, ab.mDataByteSize);
//            }
//        }
//
//        if (!status) {
//            if (source.delegate && [source.delegate respondsToSelector:@selector(captureOutput:audioData:)]) {
//                [source.delegate captureOutput:source audioData:[NSData dataWithBytes:buffers.mBuffers[0].mData length:buffers.mBuffers[0].mDataByteSize]];
//            }
//        }
        source->_buffers = &buffers;
        return status;
    }
}
@end
