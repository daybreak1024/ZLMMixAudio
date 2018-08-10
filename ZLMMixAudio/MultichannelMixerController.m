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

@interface MultichannelMixerController (){
    AUGraph _mGraph;
    AudioUnit _mMixer;
    AudioUnit _mOutput;
}
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) AVAudioFormat *mAudioFormat;
@end
@implementation MultichannelMixerController
- (instancetype)init{
    if (self = [super init]) {
        _isPlaying = false;
        
        
    }
    return self;
}
- (void)dealloc{
    DisposeAUGraph(_mGraph);

}
- (void)loadFiles{
    NSString *sourceA = [[NSBundle mainBundle] pathForResource:@"GuitarMonoSTP" ofType:@"aif"];
    NSString *sourceB = [[NSBundle mainBundle] pathForResource:@"Zac Efron;Drew Seeley;Vanessa Hudgens-Breaking Free" ofType:@"mp3"];
    SoundBuffer SoundBufferA = [ReadSourceTool getAudioFormLoacl:sourceA];
    SoundBuffer SoundBufferB = [ReadSourceTool getAudioFormLoacl:sourceB];
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
    output_desc.componentType          = kAudioUnitType_Mixer;
    output_desc.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
    output_desc.componentManufacturer  = kAudioUnitManufacturer_Apple;
    output_desc.componentFlags         = 0;
    output_desc.componentFlagsMask     = 0;
    
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

    // 为 AUGraph 生成统一的 ASBD（AudioStreamBasicDescription）
    AVAudioFormat *mAudioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                   sampleRate:kGraphSampleRate
                                                                     channels:2
                                                                  interleaved:NO];
    // set bus count
    UInt32 numbuses = 2;
    // 设置混音输入的源的 Element（ bus） 数量
    result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &numbuses, sizeof(numbuses));
    NSAssert(result == noErr, @"AudioUnitSetProperty result Error");

    // 设置 混音输入数据的回调 和 输入源的 Fromat
    for (int i = 0; i < numbuses; ++i) {
        // 创建 render callback
        AURenderCallbackStruct rcbs;
        rcbs.inputProc = &renderInput;
        rcbs.inputProcRefCon = (__bridge void * _Nullable)(self);
        
        
        // 设置 render callback
        result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, i, &rcbs, sizeof(rcbs));
        NSAssert(result == noErr, @"AudioUnitSetProperty result Error");
        
        // 设置输入源的Fromat
        result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
        NSAssert(result == noErr, @"AudioUnitSetProperty result Error");

    }
    
    // 设置输出的 Fromat
    result = AudioUnitSetProperty(_mMixer, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
    NSAssert(result == noErr, @"AudioUnitSetProperty result Error");

    result = AudioUnitSetProperty(_mOutput, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1,  mAudioFormat.streamDescription, sizeof(AudioStreamBasicDescription));
    NSAssert(result == noErr, @"AudioUnitSetProperty result Error");
    
}


static OSStatus renderInput(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
    MultichannelMixerController *source = (__bridge MultichannelMixerController *)inRefCon;
    
//    SoundBuffer * sndbuf = source->mSoundBuffer;
//    
//    UInt32 sample = sndbuf[inBusNumber].sampleNum;      // frame number to start from
//    UInt32 bufSamples = sndbuf[inBusNumber].numFrames;  // total number of frames in the sound buffer
//    Float32 *data = sndbuf[inBusNumber].data; // audio data buffer
//    
//    Float32 *outA = (Float32 *)ioData->mBuffers[0].mData; // output audio buffer for L channel
//    Float32 *outB = (Float32 *)ioData->mBuffers[1].mData; // output audio buffer for R channel
//    
//    for (UInt32 i = 0; i < inNumberFrames; ++i) {
//        
//        if (1 == inBusNumber) {
//            outA[i] = data[sample++];
//            outB[i] = data[sample++];
//        } else {
//            outA[i] = data[sample++];
//            outB[i] = data[sample++];;
//        }
//        
//        if (sample > bufSamples) {
//            // start over from the beginning of the data, our audio simply loops
//            printf("looping data for bus %d after %ld source frames rendered\n", (unsigned int)inBusNumber, (long)sample-1);
//            sample = 0;
//        }
//    }
//    
//    sndbuf[inBusNumber].sampleNum = sample; // keep track of where we are in the source data buffer
//    //    }
    
    
    //printf("bus %d sample %d\n", (unsigned int)inBusNumber, (unsigned int)sample);
    
    return noErr;
    
}

@end
