//
//  ZLMMixVideoViewController.m
//  ZLMMixAudio
//
//  Created by 周黎明 on 2018/8/10.
//  Copyright © 2018 周黎明. All rights reserved.
//

#import "ZLMMixVideoViewController.h"
#import "MultichannelMixerController.h"
@interface ZLMMixVideoViewController ()
@property (nonatomic, strong) MultichannelMixerController *mixerController;
@end

@implementation ZLMMixVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _mixerController = [[MultichannelMixerController alloc] init];

}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (IBAction)palyClick:(UIButton *)sender {
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self.mixerController startAUGraph];
    }else{
        [self.mixerController stopAUGraph];
    }
}
// handle input on/off switch action
- (IBAction)enableInput:(UISwitch *)sender
{
    UInt32 inputNum = (UInt32)[sender tag];
    AudioUnitParameterValue isOn = (AudioUnitParameterValue)sender.isOn;
    
//    if (0 == inputNum) self.bus0VolumeSlider.enabled = isOn;
//    if (1 == inputNum) self.bus1VolumeSlider.enabled = isOn;
    
    [self.mixerController enableInput:inputNum isOn:isOn];
}
- (IBAction)setInputVolume:(UISlider *)sender
{
    UInt32 inputNum = (UInt32)[sender tag];
    AudioUnitParameterValue value = sender.value;
    
    [self.mixerController setInputVolume:inputNum value:value];
}
@end
