//
//  AudioCapture.h
//  ZLMMixAudio
//
//  Created by 周黎明 on 2018/8/20.
//  Copyright © 2018 周黎明. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioCapture : NSObject{
@public;
    AudioBufferList *_buffers;
}
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) AudioComponentInstance componetInstance;
@property (nonatomic, assign) UInt32 channels;
@end

NS_ASSUME_NONNULL_END
