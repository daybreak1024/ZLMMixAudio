//
//  ReadSourceTool.h
//  ZLMMixAudio
//
//  Created by 周黎明 on 2018/8/10.
//  Copyright © 2018 周黎明. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudioKit/CoreAudioKit.h>
NS_ASSUME_NONNULL_BEGIN
extern const Float64 kGraphSampleRate;
@interface ReadSourceTool : NSObject{
    AudioBuffer sourceBuffer;
}
- (instancetype)initWithAudioFormat:(AVAudioFormat *)audioFormat;
@end

NS_ASSUME_NONNULL_END
