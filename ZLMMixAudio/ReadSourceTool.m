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
+ (AudioBuffer)getAudioFormLoacl:(NSString *)path{
    AVAudioFormat *clientFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                                   sampleRate:kGraphSampleRate
                                                                     channels:1
                                                                  interleaved:YES];
}
@end
