//
//  ViewController.m
//  SHWebClientSocketApp
//
//  Created by shouian on 13/5/12.
//  Copyright (c) 2013年 Sail. All rights reserved.
//

#import "ViewController.h"

unsigned long unpacki32(char *buf)
{
    return (buf[0]<<24) | (buf[1]<<16) | (buf[2]<<8) | buf[3];
}

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    context = [CIContext contextWithOptions:nil];
    cameraPreviewView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:cameraPreviewView];
    
    // Configure the camera
    [self setUpCamera];
    // Run the camera
    [session startRunning];
    [self embedPreviewInView:cameraPreviewView];
    [self connectToServer];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    // Layout the imageView
    [self layoutPreviewInView:cameraPreviewView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Set up the IP Address
- (void)connectToServer
{
//    NSString *ip = @"192.168.1.2";
    NSString *ip = @"172.20.10.2";
    NSInteger port = 9899;
    
    CFReadStreamRef readStream = NULL;
    CFWriteStreamRef writeStream = NULL;
    
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)ip, port, &readStream, &writeStream);
    if (readStream && writeStream) {
        
        CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
        
        oStream = (__bridge NSOutputStream *)writeStream;
        [oStream setDelegate:self];
        [oStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [oStream open];
    }
    
}

#pragma mark - NSStream Delegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    if (eventCode == NSStreamEventHasSpaceAvailable) {
        
        if (image) {
            
            @autoreleasepool {
                CGImageRef imageRef = [context createCGImage:image fromRect:image.extent];
                UIImage *tempImage = [UIImage imageWithCGImage:imageRef];
                // Convert UIImage to NSData
                NSData *imageData = UIImageJPEGRepresentation(tempImage, 0.01);
                unsigned int dataLength = [imageData length];
                
                NSLog(@"data length %d", dataLength);
                
                uint8_t lengthbuffer[4];
                lengthbuffer[0] = (dataLength >> 24) & 0xFF;
                lengthbuffer[1] = (dataLength >> 16) & 0xFF;
                lengthbuffer[2] = (dataLength >> 8) & 0xFF;
                lengthbuffer[3] = dataLength & 0xFF;
                
//                NSLog(@"length %d", dataLength);
//                NSLog(@"max length %d", [imageData length]);
                
                // Now write it to server
                // 1. Write length
                [oStream write:lengthbuffer maxLength:4];
                // 2. Write data
                [oStream write:(const uint8_t *)[imageData bytes] maxLength:[imageData length]];
                CGImageRelease(imageRef);
            }
        }
    }
}

#pragma mark - Set up Camera
- (void)setUpCamera
{
    session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset640x480;
    
    [session beginConfiguration]; // Configuration
    
    // Get the back camera
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *backCamera = nil;
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionBack) {
            backCamera = device;
            break;
        }
    }
    
    // Set up the intput
    NSError *error;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
    [session addInput:deviceInput];
    
    // Set up the output
    AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    // Run on another thread
    dispatch_queue_t queue = dispatch_queue_create("mycamera", NULL);
    [dataOutput setSampleBufferDelegate:self queue:queue];
    dataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [session addOutput:dataOutput];
    
    // Finish configuration
    [session commitConfiguration];
    
}

// Camera Delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    @autoreleasepool {
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
        image = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer options:(__bridge_transfer NSDictionary *)attachments];
        
        // Rotate the image
        image = [image imageByApplyingTransform:CGAffineTransformMakeRotation(-M_PI_2)];
        CGPoint origin = [image extent].origin;
        image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(-origin.x, -origin.y)];
    }
}

- (void)embedPreviewInView:(UIView *)view;
{
    if (!session) {
        return;
    }
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    previewLayer.frame = view.frame;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [view.layer addSublayer:previewLayer];
}

- (AVCaptureVideoPreviewLayer *) previewInView: (UIView *) view
{
    for (CALayer *layer in view.layer.sublayers)
        if ([layer isKindOfClass:[AVCaptureVideoPreviewLayer class]])
            return (AVCaptureVideoPreviewLayer *)layer;
    
    return nil;
}

- (void)layoutPreviewInView:(UIView *)view
{
    AVCaptureVideoPreviewLayer *layer = [self previewInView:view];
    if (!layer) {
        return;
    }
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    CATransform3D transform = CATransform3DIdentity;
    if (orientation == UIDeviceOrientationPortrait) ;
    else if (orientation == UIDeviceOrientationLandscapeLeft)
        transform = CATransform3DMakeRotation(-M_PI_2, 0.0f, 0.0f, 1.0f);
    else if (orientation == UIDeviceOrientationLandscapeRight)
        transform = CATransform3DMakeRotation(M_PI_2, 0.0f, 0.0f, 1.0f);
    else if (orientation == UIDeviceOrientationPortraitUpsideDown)
        transform = CATransform3DMakeRotation(M_PI, 0.0f, 0.0f, 1.0f);
    
    layer.transform = transform;
    layer.frame = view.frame;
    
}

@end
