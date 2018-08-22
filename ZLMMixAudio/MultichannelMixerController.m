//
//  MultichannelMixerController.m
//  ZLMMixAudio
//
//  Created by 周黎明 on 2018/8/10.
//  Copyright © 2018 周黎明. All rights reserved.
//

#import "MultichannelMixerController.h"
#import "ReadSourceTool.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVAudioFormat.h>

#define kRemoteIOInputBus 1
#define kRemoteIOOutputBus 1

@interface MultichannelMixerController (){
    AUGraph _mGraph;
    AudioUnit _mMixer;
    AudioUnit _mOutput;
    SoundBuffer *  _soundBufferList;
    
    AudioBufferList *_buffers;

}
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) AVAudioFormat *mAudioFormat;
@property (nonatomic, strong) NSArray *files;
@property (nonatomic, strong) dispatch_queue_t taskQueue;

@end
@implementation MultichannelMixerController
- (instancetype)initWithLoaclFilesPath:(NSArray<NSString *> *)files{
    if (self = [super init]) {
        _isPlaying = false;
        _files = files;
        self.taskQueue = dispatch_queue_create("com.netease.NASA.audioCapture.Queue", NULL);
        dispatch_sync(self.taskQueue, ^{
            // 加载本地音频
            [self loadFiles];
            
            [self initializeAUGraph];
        });
        
        
    }
    return self;
}
- (void)dealloc{
    dispatch_sync(self.taskQueue, ^{
        DisposeAUGraph(self->_mGraph);
        
        if (self->_soundBufferList != NULL) {
            free(self->_soundBufferList);
        }
        
        if (self->_buffers != NULL) {
            if (self->_buffers->mBuffers[0].mData) {
                free(self->_buffers->mBuffers[0].mData);
                self->_buffers->mBuffers[0].mData = NULL;
            }
            free(self->_buffers);
            self->_buffers = NULL;
        }
        
    });
}
#pragma mark - Public
// stars render
- (void)startAUGraph{
    dispatch_sync(self.taskQueue, ^{
        
        OSStatus result = AUGraphStart(self->_mGraph);
        NSAssert(result == noErr, @"AUGraphStart result Error");
        
        self.isPlaying = true;
    });
}

// stops render
- (void)stopAUGraph{
    printf("STOP\n");
    dispatch_sync(self.taskQueue, ^{
        
        Boolean isRunning = false;
        OSStatus result = AUGraphIsRunning(self->_mGraph, &isRunning);
        NSAssert(result == noErr, @"AUGraphIsRunning result Error");
        
        if (isRunning) {
            result = AUGraphStop(self->_mGraph);
            NSAssert(result == noErr, @"AUGraphStop result Error");
            
            self.isPlaying = false;
        }
        
    });
}
- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue
{
    dispatch_sync(self.taskQueue, ^{
        
        printf("BUS %d isON %f\n", (unsigned int)inputNum, isONValue);
        
        OSStatus result = AudioUnitSetParameter(self->_mMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, inputNum, isONValue, 0);
        if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Enable result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    });
    
}

// sets the input volume for a specific bus
- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value {
    dispatch_sync(self.taskQueue, ^{
        
        OSStatus result = AudioUnitSetParameter(self->_mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, inputNum, value, 0);
        if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    });
}

// sets the overall mixer output volume
- (void)setOutputVolume:(AudioUnitParameterValue)value {
    dispatch_sync(self.taskQueue, ^{
        
        OSStatus result = AudioUnitSetParameter(self->_mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0);
        if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    });
}
#pragma mark - Private
- (void)loadFiles{
    if (self.files && [self.files count] > 0) {
        _soundBufferList = (SoundBuffer *)malloc(sizeof(SoundBuffer) * self.files.count);
        
        for (int i = 0 ; i<[self.files count]; ++i) {
            SoundBuffer soundBuffer = [ReadSourceTool getAudioFormLoacl:self.files[i]];
            _soundBufferList[i] = soundBuffer;
        }
        
    }
    
}

- (void)initializeAUGraph{
    
    // bufferList 里存放着一堆 buffers，buffers 的长度是动态的
    uint32_t numberBuffers = 1;
    _buffers = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    _buffers->mNumberBuffers = numberBuffers;
    
    AUNode outputNode;
    AUNode mixerNode;
    
    OSStatus result = noErr;

    // 创建 AUGraph
    result = NewAUGraph(&_mGraph);
    NSAssert(result == noErr, @"NewAUGraph result Error");
    
    // 创建 AudioComponentDescriptions，用于获取 AUNode ，然后在获取对应的 AudioUnit
    // remoteIO-oupt
    AudioComponentDescription output_desc ;
    output_desc.componentType          = kAudioUnitType_Output;
    output_desc.componentSubType       = kAudioUnitSubType_RemoteIO;
    output_desc.componentManufacturer  = kAudioUnitManufacturer_Apple;
    output_desc.componentFlags         = 0;
    output_desc.componentFlagsMask     = 0;
    
    // multichannel mixer unit
    AudioComponentDescription mixer_desc ;
    mixer_desc.componentType          = kAudioUnitType_Mixer;
    mixer_desc.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
    mixer_desc.componentManufacturer  = kAudioUnitManufacturer_Apple;
    mixer_desc.componentFlags         = 0;
    mixer_desc.componentFlagsMask     = 0;
    
    // 根据 AudioComponentDescriptions 创建 AUNode
    result = AUGraphAddNode(_mGraph, &output_desc, &outputNode);
    NSAssert(result == noErr, @"AUGraphNewNode-output_desc result Error");
    
    result = AUGraphAddNode(_mGraph, &mixer_desc, &mixerNode );
    NSAssert(result == noErr, @"AUGraphNewNode-mixer_desc result Error");

    // 将 node 连接起来
    result = AUGraphConnectNodeInput(_mGraph, mixerNode, 0, outputNode, 0);
    NSAssert(result == noErr, @"AUGraphConnectNodeInput result Error");
    
    // 打开AUGraph, 但是未进行初始化
    result = AUGraphOpen(_mGraph);
    NSAssert(result == noErr, @"AUGraphOpen result Error");

    // 获取对应的 AudioUnit
    result = AUGraphNodeInfo(_mGraph, mixerNode, NULL, &_mMixer);
    NSAssert(result == noErr, @"AUGraphNodeInfo-mMixer result Error");
    
    result = AUGraphNodeInfo(_mGraph, outputNode, NULL, &_mOutput);
    NSAssert(result == noErr, @"AUGraphNodeInfo-mOutput result Error");
  
    [self audioUnitSetProperty];
    
    // now that we've set everything up we can initialize the graph, this will also validate the connections
    result = AUGraphInitialize(_mGraph);
    NSAssert(result == noErr, @"AUGraphInitialize result Error");

    CAShow(_mGraph);
}
- (void)audioUnitSetProperty{
    UInt32 captureNumbus = 2;
    
    OSStatus result = noErr;
   
    // set bus count.
    UInt32 numbuses = (UInt32)([self.files count] + 1);
    // 设置混音输入的源的 Element（ bus） 数量
    result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses));
    NSAssert(result == noErr, @"AudioUnitSetProperty result Error");

    // Increase the maximum frames per slice allows the mixer unit to accommodate the
    //    larger slice size used when the screen is locked.
    UInt32 maximumFramesPerSlice = 4096;
    result = AudioUnitSetProperty (_mMixer,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global,0,&maximumFramesPerSlice,sizeof (maximumFramesPerSlice));
    NSAssert(result == noErr, @"kAudioUnitProperty_MaximumFramesPerSlice result Error");

    
    // 设置 混音输入数据的回调 和 输入源的 Fromat
    for (int i = 0; i < numbuses; ++i) {
    
        AVAudioFormat *mAudioFormat = nil;
        AURenderCallbackStruct rcbs;
        if (i < [self.files count]) {
            // 创建 render callback
            rcbs.inputProc = &renderInputOfBGM;
            rcbs.inputProcRefCon = (__bridge void * _Nullable)(self);
            
            // 为 AUGraph 生成统一的 ASBD（AudioStreamBasicDescription）
            AVAudioFormat *mAudioFormatA = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                            sampleRate:kGraphSampleRate
                                                                              channels:_soundBufferList[i].channelCount
                                                                           interleaved:NO];
            mAudioFormat = mAudioFormatA;
        }else{
            // 创建 render callback
            rcbs.inputProc = &renderInputOfCapture;
            rcbs.inputProcRefCon = (__bridge void * _Nullable)(self);
            
            AVAudioFormat *mAudioFormatB = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                            sampleRate:kGraphSampleRate
                                                                              channels:captureNumbus
                                                                           interleaved:NO];
            mAudioFormat = mAudioFormatB;
        }
        
        // 设置 render callback
        result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, i, &rcbs, sizeof(rcbs));
        NSAssert(result == noErr, @"AudioUnitSetProperty result Error");
        
        // 设置输入源的Fromat
        result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
        NSAssert(result == noErr, @"AudioUnitSetProperty result Error");
        
    }
    
    
    /*remote I/O 设置*/
    // 打开语音录入
    UInt32 flagOne = 1;
     result =AudioUnitSetProperty(_mOutput, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));
    NSAssert(result == noErr, @"kAudioUnitProperty_SampleRate result Error");
    
   // 设置语音录入格式
    AudioStreamBasicDescription desc = {0};
    desc.mSampleRate = kGraphSampleRate;
    desc.mFormatID = kAudioFormatLinearPCM;
    desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    desc.mChannelsPerFrame = captureNumbus;
    desc.mFramesPerPacket = 1;
    desc.mBitsPerChannel = 16;
    desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
    desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
    
    result = AudioUnitSetProperty(_mOutput, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,&desc , sizeof(AudioStreamBasicDescription));
    NSAssert(result == noErr, @"kAudioUnitProperty_SampleRate result Error");
    
    // 设置数据采集回调函数
    AURenderCallbackStruct cb;
    cb.inputProcRefCon = (__bridge void *)(self);
    cb.inputProc = handleInputBuffer;
    result =AudioUnitSetProperty(_mOutput, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Output, 1, &cb, sizeof(cb));
    NSAssert(result == noErr, @"kAudioUnitProperty_SampleRate result Error");
    
}
#pragma mark - audioUnit 回调
#pragma mark 录音硬件输入回调
static OSStatus handleInputBuffer(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    @autoreleasepool {
        MultichannelMixerController *source = (__bridge MultichannelMixerController *)inRefCon;
        if (!source) {
            return -1;
        }
        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 1;
        source->_buffers->mBuffers[0] = buffer;

        // 获得录制的采样数据
        OSStatus status = AudioUnitRender(source->_mOutput,
                                          ioActionFlags,
                                          inTimeStamp,
                                          inBusNumber,
                                          inNumberFrames,
                                          source->_buffers);
        
//        printf("bus %d sample %d\n", (unsigned int)inBusNumber,status);
//        [source writePCMData:source->_buffers->mBuffers[0].mData size:source->_buffers->mBuffers[0].mDataByteSize];

        return status;
    }
}
#pragma 混音输入源回调
static OSStatus renderInputOfBGM(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
    MultichannelMixerController *source = (__bridge MultichannelMixerController *)inRefCon;
    
    SoundBuffer *sndbuf =  &(source->_soundBufferList[inBusNumber]);

    UInt32 sample = sndbuf->sampleNum;      // frame number to start from
    UInt32 bufSamples = sndbuf->numFrames;  // total number of frames in the sound buffer
    Float32 *leftData = sndbuf->leftData; // audio data buffer
    Float32 *rightData = sndbuf->rightData; // audio data buffer

    Float32 *outA = (Float32 *)ioData->mBuffers[0].mData; // output audio buffer for L channel
    Float32 *outB = (Float32 *)ioData->mBuffers[1].mData; // output audio buffer for R channel
    
    for (UInt32 i = 0; i < inNumberFrames; ++i) {
        outA[i] = leftData[sample];

        if (sndbuf->channelCount == 2) {
            outB[i] = rightData[sample];
        }
        sample++;
        
        if (sample > bufSamples) {
            // start over from the beginning of the data, our audio simply loops
            printf("looping data for bus %d after %ld source frames rendered\n", (unsigned int)inBusNumber, (long)sample-1);
            sample = 0;
        }
    }
    
    sndbuf->sampleNum = sample; // keep track of where we are in the source data buffer
    
    printf("bus %d sample %d\n", (unsigned int)inBusNumber, (unsigned int)sample);
    
    return noErr;
    
}
static OSStatus renderInputOfCapture(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
    MultichannelMixerController *source = (__bridge MultichannelMixerController *)inRefCon;
    
    Float32 *outA = (Float32 *)ioData->mBuffers[0].mData; // output audio buffer for L channel
    Float32 *outB = (Float32 *)ioData->mBuffers[1].mData; // output audio buffer for R channel

    AudioBufferList buffers = *(source->_buffers);
    AudioBuffer buffer = buffers.mBuffers[0];
    Float32 *data =  buffer.mData;
    for (UInt32 i = 0; i < inNumberFrames && i < buffer.mDataByteSize ; ++i) {
        outA[i] = data[i];
        outB[i] = data[i];
    }
    printf("bus %d sample %d,%d\n", (unsigned int)inBusNumber, buffer.mDataByteSize, inNumberFrames);

//    for (int i = 0; i < buffers.mNumberBuffers; i++) {
//        AudioBuffer ab = buffers.mBuffers[i];
//        memset(ab.mData, 0, ab.mDataByteSize);
//    }
//
//         采样数据已经在 bufferList 中的 buffers 中了
//                if (source.muted) {
//                    for (int i = 0; i < buffers.mNumberBuffers; i++) {
//                        AudioBuffer ab = buffers.mBuffers[i];
//                        memset(ab.mData, 0, ab.mDataByteSize);
//                    }
//                }
    
        return noErr;
    
}

- (void)writePCMData:(Byte *)buffer size:(int)size {
    static FILE *file = NULL;
    NSString *path = [NSTemporaryDirectory() stringByAppendingString:@"/record.pcm"];
    if (!file) {
        file = fopen(path.UTF8String, "w");
    }
    fwrite(buffer, size, 1, file);
}

@end
