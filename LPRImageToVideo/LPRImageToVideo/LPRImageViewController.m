//
//  LPRImageViewController.m
//  LPRImageToVideo
//
//  Created by 李沛然 on 2018/4/2.
//  Copyright © 2018年 aranzi-go. All rights reserved.
//

#import "LPRImageViewController.h"
#import "GPUImage.h"
#import "PlayViewController.h"

@interface LPRImageViewController ()<GPUImageMovieWriterDelegate>
{
    UIButton *_startBtn;
    UIButton *_endBtn;
    UIButton *_changeBtn;
    UISlider *_slider;
    
    GPUImagePicture *_sourcePicture;
    GPUImageOutput <GPUImageInput> *_sepiaFilter;
    GPUImageMovieWriter *_movieWriter;
    NSInteger _mySec;
    CADisplayLink *_displayLink;
    
    NSString *_pathToMovie;
}

- (void)_setUpDisplayFiltering;
- (void)_setUpDisplayLink;
- (void)_processImage;

@end

@implementation LPRImageViewController

#pragma mark -
#pragma mark Life cycle

- (void)dealloc
{
    NSLog(@"%s",__func__);
}

- (void)loadView
{
    CGRect mainScreenFrame = [[UIScreen mainScreen] bounds];
    GPUImageView *primaryView = [[GPUImageView alloc]initWithFrame:mainScreenFrame];
    self.view = primaryView;
    
    _startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _startBtn.frame = CGRectMake(100, 100, 100, 40);
    [_startBtn addTarget:self action:@selector(clickStartAction:) forControlEvents:UIControlEventTouchUpInside];
    _startBtn.backgroundColor = [UIColor orangeColor];
    [_startBtn setTitle:@"开始" forState:UIControlStateNormal];
    
    _endBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _endBtn.frame = CGRectMake(100, 220, 100, 40);
    [_endBtn addTarget:self action:@selector(clickEndAction:) forControlEvents:UIControlEventTouchUpInside];
    _endBtn.backgroundColor = [UIColor orangeColor];
    [_endBtn setTitle:@"结束" forState:UIControlStateNormal];
    
    _changeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _changeBtn.frame = CGRectMake(100, 300, 150, 40);
    [_changeBtn addTarget:self action:@selector(clickChangeAction:) forControlEvents:UIControlEventTouchUpInside];
    _changeBtn.backgroundColor = [UIColor orangeColor];
    [_changeBtn setTitle:@"切换为第二张图片" forState:UIControlStateNormal];
    
    _slider = [[UISlider alloc]initWithFrame:CGRectMake(220, 100, 100, 40)];
    _slider.backgroundColor = [UIColor grayColor];
    [_slider addTarget:self action:@selector(clickSliderChangeValueAction:) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:_startBtn];
    [self.view addSubview:_endBtn];
    [self.view addSubview:_changeBtn];
    [self.view addSubview:_slider];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self _setUpDisplayFiltering];
    [self _setUpDisplayLink];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Public methods

#pragma mark -
#pragma mark Private methods

- (void)_setUpDisplayFiltering
{
    UIImage *inputImage = [UIImage imageNamed:@"photo2.png"];
    _pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
    unlink([_pathToMovie UTF8String]);
    NSURL *movieURL = [NSURL fileURLWithPath:_pathToMovie];
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:CGSizeMake(480.0, 640.0)];
    _movieWriter.delegate = self;
    _sourcePicture = [[GPUImagePicture alloc]initWithImage:inputImage];
    _sepiaFilter = [[GPUImageTiltShiftFilter alloc]init];
    GPUImageView *imageView = (GPUImageView *)self.view;
    
    [_sepiaFilter forceProcessingAtSize:imageView.sizeInPixels];
    [_sourcePicture addTarget:_sepiaFilter];
    [_sepiaFilter addTarget:_movieWriter];
    [_sepiaFilter addTarget:imageView];
//    [self _processImage];
}

- (void)_setUpDisplayLink
{
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkAction:)];
    _displayLink.preferredFramesPerSecond = 30;
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)_processImage
{
    [_sourcePicture processImage:CMTimeMake(_mySec++, 30)];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)clickStartAction:(id)sender
{
    NSLog(@"%s",__func__);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"START" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"已开始" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (!_displayLink)
        {
            [self _setUpDisplayLink];
        }
        [_movieWriter startRecording];
    }]];
    [self presentViewController:alert animated:YES completion:^{
    }];
}

- (IBAction)clickEndAction:(id)sender
{
    NSLog(@"%s",__func__);
    [_sepiaFilter removeTarget:_movieWriter];
    [_movieWriter finishRecording];
    
    [_displayLink invalidate];
    _displayLink = nil;
}

- (IBAction)clickChangeAction:(id)sender
{
    [_sourcePicture replaceTextureWithSubimage:[UIImage imageNamed:@"photo1.png"]];
//    [self _processImage];
}

- (IBAction)clickSliderChangeValueAction:(UISlider *)sender
{
    CGFloat midpoint = [(UISlider *)sender value];
    [(GPUImageTiltShiftFilter *)_sepiaFilter setTopFocusLevel:midpoint - 0.1];
    [(GPUImageTiltShiftFilter *)_sepiaFilter setBottomFocusLevel:midpoint + 0.1];
//    [self _processImage];
}

- (IBAction)displayLinkAction:(CADisplayLink *)sender
{
    [self _processImage];
}

#pragma mark -
#pragma mark GPUImageMovieWriterDelegate

- (void)movieRecordingCompleted
{
    NSLog(@"%s",__func__);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"OVER" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"已结束,去沙盒查看吧" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    }]];
    [self presentViewController:alert animated:YES completion:^{
    }];
}

- (void)movieRecordingFailedWithError:(NSError*)error
{
    NSLog(@"%s===%@",__func__,error.description);
}

@end
