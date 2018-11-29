//
//  GLView.h
//  01-多滤镜处理
//
//  Created by chunxiao on 2018/3/5.
//  Copyright © 2018年 千帆 All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GLView : UIView
{
    CAEAGLLayer *_eaglLayer;//图层
    EAGLContext *_context;//上下文
    GLuint       _framebuffer;
    GLuint       _renderbuffer;

    GLuint       _texture;//纹理
    
    GLuint       _tempFramebuffer;
    GLuint       _tempTexture;
    GLuint       _tempRenderBuffer;
    
    GLuint       _programHandle;
    GLuint       _tempProgramHandle;

}

@property (nonatomic, assign) CGFloat temperature;//色温
@property (nonatomic, assign) CGFloat saturation;//饱和度

//将图片加入到GLView上
- (void)layoutGLViewWithImage:(UIImage *)image;

@end
