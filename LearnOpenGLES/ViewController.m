//
//  ViewController.m
//  01-多滤镜处理
//
//  Created by chunxiao on 2018/3/5.
//  Copyright © 2018年 千帆 All rights reserved.
//

#import "ViewController.h"
#import "GLContainerView.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet GLContainerView *glContainerView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.glContainerView.image = [UIImage imageNamed:@"Lena"];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action
- (IBAction)actionValueChanged:(UISlider *)sender {
    self.glContainerView.colorTempValue = sender.value;
}

- (IBAction)actionSaturationValueChanged:(UISlider *)sender {
    self.glContainerView.saturationValue = sender.value;
}

@end
