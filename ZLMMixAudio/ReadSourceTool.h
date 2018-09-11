//
//  ReadSourceTool.h
//  ZLMMixAudio
//
//  Created by 周黎明 on 2018/8/10.
//  Copyright © 2018 周黎明. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudioKit/CoreAudioKit.h>
typedef struct {
    AudioStreamBasicDescription asbd;
    UInt32                      channelCount;
    Float32                     *leftData;
    Float32                     *rightData;
    UInt32                      numFrames;
    UInt32                      sampleNum;
} SoundBuffer;

extern const Float64 kGraphSampleRate;

NS_ASSUME_NONNULL_BEGIN
@interface ReadSourceTool : NSObject
+ (SoundBuffer)getAudioFormLoacl:(NSString *)path;
@end

NS_ASSUME_NONNULL_END
