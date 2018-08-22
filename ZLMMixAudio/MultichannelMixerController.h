//
//  MultichannelMixerController.h
//  ZLMMixAudio
//
//  Created by 周黎明 on 2018/8/10.
//  Copyright © 2018 周黎明. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVAudioFormat.h>
NS_ASSUME_NONNULL_BEGIN

@interface MultichannelMixerController : NSObject
- (instancetype)initWithLoaclFilesPath:(NSArray <NSString *>* _Nullable )files;

@property (nonatomic, assign, readonly) BOOL isPlaying;
- (void)startAUGraph;
- (void)stopAUGraph;

- (void)enableInput:(UInt32)inputNum isOn:(AudioUnitParameterValue)isONValue;
- (void)setInputVolume:(UInt32)inputNum value:(AudioUnitParameterValue)value;
- (void)setOutputVolume:(AudioUnitParameterValue)value;

@end

NS_ASSUME_NONNULL_END
