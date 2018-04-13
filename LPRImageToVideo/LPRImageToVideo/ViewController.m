//
//  ViewController.m
//  LPRImageToVideo
//
//  Created by 李沛然 on 2018/3/17.
//  Copyright © 2018年 aranzi-go. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController ()<GPUImageVideoCameraDelegate>
{
    CVPixelBufferRef _imageBuffer;
    dispatch_semaphore_t _seam;
}

#define vWidth 324
#define vHeight 576

@property (nonatomic, strong) GPUImageVideoCamera *camera;
@property (nonatomic, strong) GPUImageView *preview;
@property (nonatomic, strong) UIButton *btn;

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSMutableArray *imageArrays;
@property (nonatomic, assign) BOOL enable;
@property (nonatomic, assign) BOOL end;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;

- (void)_initLocalData;
- (void)_initGPUImage;
- (void)_initMovieWriter;
- (CVPixelBufferRef)_pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size;

@end

@implementation ViewController

#pragma mark -
#pragma mark LifeCircle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self _initGPUImage];
    [self _initLocalData];
    [self _initMovieWriter];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Private methods

- (void)_initLocalData
{
    [self.imageArrays addObjectsFromArray:@[@"photo1.png",@"photo2.png",@"photo3.png",@"photo4.png"]];
    _seam = dispatch_semaphore_create(0);
}

- (void)_initGPUImage
{
    //init & configure camera
    _camera = [[GPUImageVideoCamera alloc]initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionBack];
    _camera.outputImageOrientation = UIDeviceOrientationPortrait;
    _camera.horizontallyMirrorFrontFacingCamera = YES;
    _camera.delegate = self;
    
    //init & configure preview
    _preview = [[GPUImageView alloc]initWithFrame:self.view.frame];
    [self.view addSubview:_preview];
    [_camera addTarget:_preview];
    [_camera startCameraCapture];
    
    //init & configure btn
    _btn = [[UIButton alloc]initWithFrame:CGRectMake(20, self.view.frame.size.height - 100, 100, 48)];
    _btn.backgroundColor = [UIColor orangeColor];
    [_btn setTitle:@"点击开始" forState:UIControlStateNormal];
    [_btn addTarget:self action:@selector(onBeginCombineAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btn];
}

- (void)_initMovieWriter
{
    NSLog(@"%s",__func__);
    NSDate *date = [NSDate date];
    NSString *string = [NSString stringWithFormat:@"%ld-%dX%d.mov",(unsigned long)date.timeIntervalSince1970*1000,vWidth,vHeight];
    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingString:string];
    if ([[NSFileManager defaultManager]fileExistsAtPath:cachePath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
    }
    NSURL *exportURL = [NSURL fileURLWithPath:cachePath];
    _url = exportURL;
    CGSize size = CGSizeMake(vWidth,vHeight);// 定义视频的大小
    __block AVAssetWriter *videoWriter = [[AVAssetWriter alloc]initWithURL:exportURL fileType:AVFileTypeQuickTimeMovie error:nil];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecTypeH264, AVVideoCodecKey, [NSNumber numberWithInt:size.width], AVVideoWidthKey, [NSNumber numberWithInt:size.height], AVVideoHeightKey, nil];
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    AVAssetWriterInputPixelBufferAdaptor * adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    
    if ([videoWriter canAddInput:writerInput])
    {
        NSLog(@"Can Add Input");
    }
    else
    {
        NSLog(@"No Can Add Input");
    }
    
    [videoWriter addInput:writerInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_queue_t dispatchQueue = dispatch_queue_create("mediainputqueue", NULL);
    int __block frame = 0;
    //开始写视频帧
    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
        while ([writerInput isReadyForMoreMediaData])
        {
            if (_end)// 结束标志
            {
                [writerInput markAsFinished];
                if (videoWriter.status == AVAssetWriterStatusWriting)
                {
                    NSCondition *cond = [[NSCondition alloc]init];
                    [cond lock];
                    [videoWriter finishWritingWithCompletionHandler:^{
                        [cond lock];
                        [cond signal];
                        [cond unlock];
                    }];
                    [cond wait];
                    [cond unlock];
                    [self savePhotoCamera:self.url];
                }
                NSLog(@"end---url:%@",self.url);
                break;
            }
            
            dispatch_semaphore_wait(_seam, DISPATCH_TIME_FOREVER);
            if (_imageBuffer)
            {
                if ([adaptor appendPixelBuffer:_imageBuffer withPresentationTime:CMTimeMake(frame, 30)])
                {
                    frame += 30;
                }
                else
                {
                    NSLog(@"fail");
                }
                // 释放buffer
                CVPixelBufferRelease(_imageBuffer);
                _imageBuffer = NULL;
            }
        }
    }];
}

- (void)savePhotoCamera:(NSURL *)urlString
{
    NSLog(@"%s",__func__);
}

- (CVPixelBufferRef)_pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,[NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, CVPixelBufferGetBytesPerRow(pxbuffer), rgbColorSpace, kCGImageAlphaPremultipliedFirst);
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);

    return pxbuffer;
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    
    CGFloat frameWidth = CGImageGetWidth(image);
    CGFloat frameHeight = CGImageGetHeight(image);
    
    __unused CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                                   frameWidth,
                                                   frameHeight,
                                                   kCVPixelFormatType_32ARGB,
                                                   (__bridge CFDictionaryRef) options,
                                                   &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    NSLog(@"CVPixelBufferCreate status : %d",status);
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pxbuffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           frameWidth,
                                           frameHeight),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

#pragma mark -
#pragma mark IBActions

- (void)onBeginCombineAction:(UIButton *)sender
{
    NSLog(@"%s",__func__);
    _enable = YES;
    CGSize size = CGSizeMake(vWidth,vHeight);
    for (int i = 0; i < self.imageArrays.count; ++i)
    {
        CGImageRef tmpImageRef = ((UIImage *)[UIImage imageNamed:[self.imageArrays objectAtIndex:i]]).CGImage;
        CVPixelBufferRef imageBuffer = [self _pixelBufferFromCGImage:tmpImageRef size:size];
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        _imageBuffer = CVPixelBufferRetain(imageBuffer);
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        dispatch_semaphore_signal(_seam);
    }
    _end = YES;
}

#pragma mark -
#pragma mark Public methods

#pragma mark -
#pragma mark GPUImageVideoCameraDelegate

- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
//    NSLog(@"%s",__func__);
}

#pragma mark -
#pragma mark Custom accessors

- (NSMutableArray *)imageArrays
{
    if (!_imageArrays)
    {
        _imageArrays = [[NSMutableArray alloc]init];
    }
    return _imageArrays;
}

@end
