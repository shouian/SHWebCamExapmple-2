//
//  ViewController.h
//  SHWebClientSocketApp
//
//  Created by shouian on 13/5/12.
//  Copyright (c) 2013年 Sail. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Accelerate/Accelerate.h>
#import <CoreImage/CoreImage.h>

#import <MediaPlayer/MediaPlayer.h>
#import <CoreVideo/CoreVideo.h>

@interface ViewController : UIViewController <NSStreamDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
{
    // Streaming setting
    NSInputStream *iStream;
    NSOutputStream *oStream;
    // Camera setting
    AVCaptureSession *session;
    UIView *cameraPreviewView;
    
    CIImage *image;
    CIContext *context;
}

@end
