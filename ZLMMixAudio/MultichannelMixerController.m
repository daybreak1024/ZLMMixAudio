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
#define kNumbuses 2 // 目前只有 _soundBufferA 和 _soundBufferB 两个
@interface MultichannelMixerController (){
    AUGraph _mGraph;
    AudioUnit _mMixer;
    AudioUnit _mOutput;
    SoundBuffer _soundBufferA;
    SoundBuffer _soundBufferB;
}
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) AVAudioFormat *mAudioFormat;
@end
@implementation MultichannelMixerController
- (instancetype)init{
    if (self = [super init]) {
        _isPlaying = false;
        
        [self initializeAUGraph];
    }
    return self;
}
- (void)dealloc{
    DisposeAUGraph(_mGraph);

}
#pragma mark - Public
// stars render
- (void)startAUGraph{
    
    OSStatus result = AUGraphStart(_mGraph);
    NSAssert(result == noErr, @"AUGraphStart result Error");

    self.isPlaying = true;
}

// stops render
- (void)stopAUGraph{
    printf("STOP\n");
    
    Boolean isRunning = false;
    
    OSStatus result = AUGraphIsRunning(_mGraph, &isRunning);
    NSAssert(result == noErr, @"AUGraphIsRunning result Error");

    if (isRunning) {
        result = AUGraphStop(_mGraph);
        NSAssert(result == noErr, @"AUGraphStop result Error");

        self.isPlaying = false;
    }
}
- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue
{
    printf("BUS %d isON %f\n", (unsigned int)inputNum, isONValue);
    
    OSStatus result = AudioUnitSetParameter(_mMixer, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, inputNum, isONValue, 0);
    if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Enable result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
    
}

// sets the input volume for a specific bus
- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value
{
    OSStatus result = AudioUnitSetParameter(_mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, inputNum, value, 0);
    if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Volume Input result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
}

// sets the overall mixer output volume
- (void)setOutputVolume:(AudioUnitParameterValue)value
{
    OSStatus result = AudioUnitSetParameter(_mMixer, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, value, 0);
    if (result) { printf("AudioUnitSetParameter kMultiChannelMixerParam_Volume Output result %ld %08lX %4.4s\n", (long)result, (long)result, (char*)&result); return; }
}
#pragma mark - Private
- (void)loadFiles{
    NSString *sourceA = [[NSBundle mainBundle] pathForResource:@"GuitarMonoSTP" ofType:@"aif"];
    NSString *sourceB = [[NSBundle mainBundle] pathForResource:@"Zac Efron;Drew Seeley;Vanessa Hudgens-Breaking Free" ofType:@"mp3"];
//    NSString *sourceB = [[NSBundle mainBundle] pathForResource:@"DrumsMonoSTP" ofType:@"aif"];

    
    _soundBufferA = [ReadSourceTool getAudioFormLoacl:sourceA];
    _soundBufferB = [ReadSourceTool getAudioFormLoacl:sourceB];
}

- (void)initializeAUGraph{
    
    AUNode outputNode;
    AUNode mixerNode;
    
    // 加载本地音频
    [self performSelectorInBackground:@selector(loadFiles) withObject:nil];
    
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
    OSStatus result = noErr;
   
    // set bus count 有几个设置几个，当前只有两个。
    UInt32 numbuses = kNumbuses;
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
        // 创建 render callback
        AURenderCallbackStruct rcbs;
        rcbs.inputProc = &renderInput;
        rcbs.inputProcRefCon = (__bridge void * _Nullable)(self);
        
        
        // 设置 render callback
        result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, i, &rcbs, sizeof(rcbs));
        NSAssert(result == noErr, @"AudioUnitSetProperty result Error");
        
        // 为 AUGraph 生成统一的 ASBD（AudioStreamBasicDescription）
        AVAudioFormat *mAudioFormat = nil;
        if (i == 0) {
            AVAudioFormat *mAudioFormatA = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                            sampleRate:kGraphSampleRate
                                                                              channels:1
                                                                           interleaved:NO];
            mAudioFormat = mAudioFormatA;
        }else{
            AVAudioFormat *mAudioFormatB = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                            sampleRate:kGraphSampleRate
                                                                              channels:2
                                                                           interleaved:NO];
            mAudioFormat = mAudioFormatB;
        }
        
        
        
        // 设置输入源的Fromat
        result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
        NSAssert(result == noErr, @"AudioUnitSetProperty result Error");

    }
    
    // 设置输出的 Fromat
    double sample = kGraphSampleRate;
    
    result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_SampleRate,
                         kAudioUnitScope_Output, 0,&sample , sizeof(sample));
    NSAssert(result == noErr, @"kAudioUnitProperty_SampleRate result Error");

//    result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
//    NSAssert(result == noErr, @"AudioUnitSetProperty result Error");

//    result = AudioUnitSetProperty(_mOutput, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,  mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
//    NSAssert(result == noErr, @"AudioUnitSetProperty result Error");
    
}


static OSStatus renderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
    MultichannelMixerController *source = (__bridge MultichannelMixerController *)inRefCon;
    
//    SoundBuffer * sndbuf = source->mSoundBuffer;
//
    SoundBuffer *sndbuf = inBusNumber == 1 ? &(source->_soundBufferB): &(source->_soundBufferA);

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

@end
