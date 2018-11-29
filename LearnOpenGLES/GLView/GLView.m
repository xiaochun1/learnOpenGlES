//
//  GLView.m
//  01-多滤镜处理
//
//  Created by chunxiao on 2018/3/5.
//  Copyright © 2018年 千帆 All rights reserved.
//

#import "GLView.h"
@import OpenGLES;

//顶点结构体
typedef struct
{
    float position[4];//顶点x,y,z,w
    float textureCoordinate[2];//纹理 s,t
} CustomVertex;

//属性枚举
enum
{
    ATTRIBUTE_POSITION = 0,//属性_顶点
    ATTRIBUTE_INPUT_TEXTURE_COORDINATE,//属性_输入纹理坐标
    TEMP_ATTRIBUTE_POSITION,//色温_属性_顶点位置
    TEMP_ATTRIBUTE_INPUT_TEXTURE_COORDINATE,//色温_属性_输入纹理坐标
    NUM_ATTRIBUTES//属性个数
};

//属性数组
GLint glViewAttributes[NUM_ATTRIBUTES];

enum
{
    UNIFORM_INPUT_IMAGE_TEXTURE = 0,//输入纹理
    TEMP_UNIFORM_INPUT_IMAGE_TEXTURE,//色温_输入纹理
    UNIFORM_TEMPERATURE,//色温
    UNIFORM_SATURATION,//饱和度
    NUM_UNIFORMS//Uniforms个数
};

//Uniforms数组
GLint glViewUniforms[NUM_UNIFORMS];

@implementation GLView

#pragma mark - Life Cycle
- (void)dealloc {
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    _context = nil;
}

#pragma mark - Override
// 想要显示 OpenGL 的内容, 需要把它缺省的 layer 设置为一个特殊的 layer(CAEAGLLayer).
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Setup
- (void)setup {
    
    //1.设置色温和饱和度
    [self setupData];
    //2.设置图层
    [self setupLayer];
    //3.设置图形上下文
    [self setupContext];
    //4.设置renderBuffer
    [self setupRenderBuffer];
    //5.设置frameBuffer
    [self setupFrameBuffer];
    
    //6.检查FrameBuffer
    NSError *error;
    NSAssert1([self checkFramebuffer:&error], @"%@",error.userInfo[@"ErrorMessage"]);
    
    //7.链接shader 色温
    [self compileTemperatureShaders];
    
    //8.链接shader 饱和度
    [self compileSaturationShaders];
    
    //9.设置VBO (Vertex Buffer Objects)
    [self setupVBOs];
    
    //10.设置纹理
    [self setupTemp];
}

//设置色温\饱和度初始值
- (void)setupData {
    _temperature = 0.5;
    _saturation = 0.5;
}

//设置图层
- (void)setupLayer {
    // 用于显示的layer
    _eaglLayer = (CAEAGLLayer *)self.layer;
    //  CALayer默认是透明的，而透明的层对性能负荷很大。所以将其关闭。
    _eaglLayer.opaque = YES;
}


//设置图形上下文
- (void)setupContext {
    if (!_context) {
        // 创建GL环境上下文
        // EAGLContext 管理所有通过 OpenGL 进行 Draw 的信息.
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    NSAssert(_context && [EAGLContext setCurrentContext:_context], @"初始化GL环境失败");
}

//设置RenderBuffer
- (void)setupRenderBuffer {
    // 释放旧的 renderbuffer
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    // 生成renderbuffer ( renderbuffer = 用于展示的窗口 )
    glGenRenderbuffers(1, &_renderbuffer);
    // 绑定renderbuffer
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    // GL_RENDERBUFFER 的内容存储到实现 EAGLDrawable 协议的 CAEAGLLayer
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
}

//设置FrameBuffer
- (void)setupFrameBuffer {
    // 释放旧的 framebuffer
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    // 生成 framebuffer ( framebuffer = 画布 )
    glGenFramebuffers(1, &_framebuffer);
    // 绑定 fraembuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    // framebuffer 不对绘制的内容做存储, 所以这一步是将 framebuffer 绑定到 renderbuffer ( 绘制的结果就存在 renderbuffer )
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _renderbuffer);
}

- (void)setupVBOs {
   
    //顶点坐标和纹理坐标
    static const CustomVertex vertices[] =
    {
        { .position = { -1.0, -1.0, 0, 1 }, .textureCoordinate = { 0.0, 0.0 } },
        { .position = {  1.0, -1.0, 0, 1 }, .textureCoordinate = { 1.0, 0.0 } },
        { .position = { -1.0,  1.0, 0, 1 }, .textureCoordinate = { 0.0, 1.0 } },
        { .position = {  1.0,  1.0, 0, 1 }, .textureCoordinate = { 1.0, 1.0 } }
    };
    
    //初始化缓存区
    //创建VBO的3个步骤
    //1.生成新缓存对象glGenBuffers
    //2.绑定缓存对象glBindBuffer
    //3.将顶点数据拷贝到缓存对象中glBufferData

    GLuint vertexBuffer;
    
    // STEP 1 创建缓存对象并返回缓存对象的标识符
    glGenBuffers(1, &vertexBuffer);
    // STEP 2 将缓存对象对应到相应的缓存上
    /*
     glBindBuffer (GLenum target, GLuint buffer);
     target:告诉VBO缓存对象时保存顶点数组数据还是索引数组数据 :GL_ARRAY_BUFFER\GL_ELEMENT_ARRAY_BUFFER
     任何顶点属性，如顶点坐标、纹理坐标、法线与颜色分量数组都使用GL_ARRAY_BUFFER。用于glDraw[Range]Elements()的索引数据需要使用GL_ELEMENT_ARRAY绑定。注意，target标志帮助VBO确定缓存对象最有效的位置，如有些系统将索引保存AGP或系统内存中，将顶点保存在显卡内存中。
     buffer: 缓存区对象
     */
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    /*
     数据拷贝到缓存对象
     void glBufferData(GLenum target，GLsizeiptr size, const GLvoid*  data, GLenum usage);
     target:可以为GL_ARRAY_BUFFER或GL_ELEMENT_ARRAY
     size:待传递数据字节数量
     data:源数据数组指针
     usage:
     GL_STATIC_DRAW
     GL_STATIC_READ
     GL_STATIC_COPY
     GL_DYNAMIC_DRAW
     GL_DYNAMIC_READ
     GL_DYNAMIC_COPY
     GL_STREAM_DRAW
     GL_STREAM_READ
     GL_STREAM_COPY
     
     ”static“表示VBO中的数据将不会被改动（一次指定多次使用），
     ”dynamic“表示数据将会被频繁改动（反复指定与使用），
     ”stream“表示每帧数据都要改变（一次指定一次使用）。
     ”draw“表示数据将被发送到GPU以待绘制（应用程序到GL），
     ”read“表示数据将被客户端程序读取（GL到应用程序），”
     */
    // STEP 3 数据拷贝到缓存对象
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
}


- (void)setupTemp {
    //申请_tempFramesBuffe标记
    glGenFramebuffers(1, &_tempFramebuffer);
    //绑定纹理之前,激活纹理
    glActiveTexture(GL_TEXTURE0);
    //申请纹理标记
    glGenTextures(1, &_tempTexture);
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, _tempTexture);
    //将图片载入纹理
    /*
     glTexImage2D (GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const GLvoid *pixels)
     参数列表:
     1.target,目标纹理
     2.level,一般设置为0
     3.internalformat,纹理中颜色组件
     4.width,纹理图像的宽度
     5.height,纹理图像的高度
     6.border,边框的宽度
     7.format,像素数据的颜色格式
     8.type,像素数据数据类型
     9.pixels,内存中指向图像数据的指针
     */
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    //设置纹理参数
    //放大\缩小过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //绑定FrameBuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _tempFramebuffer);
    
    //应用FBO渲染到纹理（glGenTextures），直接绘制到纹理中。glCopyTexImage2D是渲染到FrameBuffer->复制FrameBuffer中的像素产生纹理。glFramebufferTexture2D直接渲染生成纹理，做全屏渲染（比如全屏模糊）时比glCopyTexImage2D高效的多。
    /*
     glFramebufferTexture2D (GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level)
     参数列表:
     1.target,GL_FRAMEBUFFER
     2.attachment,附着点名称
     3.textarget,GL_TEXTURE_2D
     4.texture,纹理对象
     5.level,一般为0
     */
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _tempTexture, 0);
}

#pragma mark - Private
- (BOOL)checkFramebuffer:(NSError *__autoreleasing *)error {
    
    // 检查 framebuffer 是否创建成功
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSString *errorMessage = nil;
    BOOL result = NO;
    switch (status)
    {
        case GL_FRAMEBUFFER_UNSUPPORTED:
            errorMessage = @"framebuffer不支持该格式";
            result = NO;
            break;
        case GL_FRAMEBUFFER_COMPLETE:
            NSLog(@"framebuffer 创建成功");
            result = YES;
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
            errorMessage = @"Framebuffer不完整 缺失组件";
            result = NO;
            break;
        case GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS:
            errorMessage = @"Framebuffer 不完整, 附加图片必须要指定大小";
            result = NO;
            break;
        default:
            // 一般是超出GL纹理的最大限制
            errorMessage = @"未知错误 error !!!!";
            result = NO;
            break;
    }
    NSLog(@"%@",errorMessage ? errorMessage : @"");
    *error = errorMessage ? [NSError errorWithDomain:@"com.Yue.error"
                                                code:status
                                            userInfo:@{@"ErrorMessage" : errorMessage}] : nil;
    return result;
}


- (GLuint)compileShader:(NSString *)shaderName withType:(GLenum)shaderType {
    
    //路径
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:nil];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        exit(1);
    }
    //创建临时shader
    GLuint shaderHandle = glCreateShader(shaderType);
    //获取shader路径-C语言字符串
    const char* shaderStringUFT8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    /*
     glShaderSource (GLuint shader, GLsizei count, const GLchar* const *string, const GLint* length)
     参数列表:
     1.shader,着色器对象
     2.count,个数
     3.string,着色器文件路径
     4.length,长度
     */
    glShaderSource(shaderHandle, 1, &shaderStringUFT8, &shaderStringLength);
    
    //编译shader
    glCompileShader(shaderHandle);
    
    //判断是否编译成功
    GLint compileSuccess;
    //获取编译信息
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    
    //打印编译时出错信息
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"glGetShaderiv ShaderIngoLog: %@", messageString);
        exit(1);
    }
    return shaderHandle;
    
}

//色温处理shaders编译
- (void)compileTemperatureShaders {
    
    
    //1.vertex shader路径
    GLuint vertexShader = [self compileShader:@"XCVertexShader.vsh" withType:GL_VERTEX_SHADER];
    //2.fragment shder路径
    GLuint fragmentShader = [self compileShader:@"XCTemperature.fsh" withType:GL_FRAGMENT_SHADER];
    
    //创建program
    _programHandle = glCreateProgram();
    //将vertes Shader 和 fragment Shader 附着到program上
    glAttachShader(_programHandle, vertexShader);
    glAttachShader(_programHandle, fragmentShader);
    
    //链接program
    glLinkProgram(_programHandle);
    
    //获取链接状态
    GLint linkSuccess;
    glGetProgramiv(_programHandle, GL_LINK_STATUS, &linkSuccess);
    
    //链接失败处理
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(_programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"glGetProgramiv ShaderIngoLog: %@", messageString);
        exit(1);
    }
    
    //使用program
    glUseProgram(_programHandle);
    
    /*
     每一个attribute在vertex shader里面有一个location，它是用来传递数据的入口
     glGetAttribLocation是用来获得vertex attribute的入口的，在我们要传递数据之前，首先要告诉OpenGL，所以要调用glEnableVertexAttribArray。最后的数据通过glVertexAttribPointer传进来。它的第一个参数就是glGetAttribLocation返回的值。
     glGetAttribLocation (GLuint program, const GLchar* name)
     参数列表:
     1.program,程序
     2.name,属性名称-对应VSH中的名称
     
     返回值是变量的位置
     */
    
    //顶点坐标
    glViewAttributes[ATTRIBUTE_POSITION] = glGetAttribLocation(_programHandle, "position");
    
    //输入的纹理坐标
    glViewAttributes[ATTRIBUTE_INPUT_TEXTURE_COORDINATE]  = glGetAttribLocation(_programHandle, "inputTextureCoordinate");
    
    //输入的图像纹理
    /*
     不同于顶点属性在每个顶点有其自己的值，一个一致变量在一个图元的绘制过程中是不会改变的，所以其值不能在glBegin/glEnd中设置。一致变量适合描述在一个图元中、一帧中甚至一个场景中都不变的值。一致变量在顶点shader和片断shader中都是只读的。
     
     首先你需要获得变量在内存中的位置，这个信息只有在连接程序之后才可获得。注意，在获得存储位置前还必须使用程序（调用glUseProgram）。
     
     glGetUniformLocation (GLuint program, const GLchar* name)
     参数列表:
     1.program
     2.name 属性名称-对应VSH中的名称
     
     返回值:变量的位置
     */
    glViewUniforms[UNIFORM_INPUT_IMAGE_TEXTURE] = glGetUniformLocation(_programHandle, "inputImageTexture");
    
    //色温值
    glViewUniforms[UNIFORM_TEMPERATURE] = glGetUniformLocation(_programHandle, "temperature");
    
    /*
     默认情况下，出于性能考虑，所有顶点着色器的属性（Attribute）变量都是关闭的，意味着数据在着色器端是不可见的，哪怕数据已经上传到GPU，由glEnableVertexAttribArray启用指定属性，才可在顶点着色器中访问逐顶点的属性数据。
     glVertexAttribPointer或VBO只是建立CPU和GPU之间的逻辑连接，从而实现了CPU数据上传至GPU。但是，数据在GPU端是否可见，即，着色器能否读取到数据，由是否启用了对应的属性决定，这就是glEnableVertexAttribArray的功能，允许顶点着色器读取GPU（服务器端）数据。
     
     那么，glEnableVertexAttribArray应该在glVertexAttribPointer之前还是之后调用？答案是都可以，只要在绘图调用（glDraw*系列函数）前调用即可。
     */
    glEnableVertexAttribArray(glViewAttributes[ATTRIBUTE_POSITION]);
    glEnableVertexAttribArray(glViewAttributes[ATTRIBUTE_INPUT_TEXTURE_COORDINATE]);
    
}

//饱和度
- (void)compileSaturationShaders {
    
    //获取路径
    //Vertex Shader是一样的
    GLuint vertexShader = [self compileShader:@"XCVertexShader.vsh" withType:GL_VERTEX_SHADER];
    
    //片元着色器是不一样的
    GLuint fragmentShader = [self compileShader:@"XCSaturation.fsh" withType:GL_FRAGMENT_SHADER];
    
    //创建program
    _tempProgramHandle = glCreateProgram();
    //将vertes Shader 和 fragment Shader 附着到program上
    glAttachShader(_tempProgramHandle, vertexShader);
    glAttachShader(_tempProgramHandle, fragmentShader);
    
    //链接Program
    glLinkProgram(_tempProgramHandle);
    
    //获取link状态
    GLint linkSuccess;
    glGetProgramiv(_tempProgramHandle, GL_LINK_STATUS, &linkSuccess);
    
    //link失败处理
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(_tempProgramHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"glGetProgramiv ShaderIngoLog: %@", messageString);
        exit(1);
    }
    
    //使用program
    glUseProgram(_tempProgramHandle);
    
    /*
     每一个attribute在vertex shader里面有一个location，它是用来传递数据的入口
     glGetAttribLocation是用来获得vertex attribute的入口的，在我们要传递数据之前，首先要告诉OpenGL，所以要调用glEnableVertexAttribArray。最后的数据通过glVertexAttribPointer传进来。它的第一个参数就是glGetAttribLocation返回的值。
     glGetAttribLocation (GLuint program, const GLchar* name)
     参数列表:
     1.program,程序
     2.name,属性名称-对应VSH中的名称
     
     返回值是变量的位置
     */
    
    //顶点坐标
    glViewAttributes[TEMP_ATTRIBUTE_POSITION] = glGetAttribLocation(_tempProgramHandle, "position");
    
    // //输入的纹理坐标
    glViewAttributes[TEMP_ATTRIBUTE_INPUT_TEXTURE_COORDINATE]  = glGetAttribLocation(_tempProgramHandle, "inputTextureCoordinate");
    
    //输入的图像纹理
    /*
     不同于顶点属性在每个顶点有其自己的值，一个一致变量在一个图元的绘制过程中是不会改变的，所以其值不能在glBegin/glEnd中设置。一致变量适合描述在一个图元中、一帧中甚至一个场景中都不变的值。一致变量在顶点shader和片断shader中都是只读的。
     
     首先你需要获得变量在内存中的位置，这个信息只有在连接程序之后才可获得。注意，在获得存储位置前还必须使用程序（调用glUseProgram）。
     
     glGetUniformLocation (GLuint program, const GLchar* name)
     参数列表:
     1.program
     2.name 属性名称-对应VSH中的名称
     
     返回值:变量的位置
     */
    glViewUniforms[TEMP_UNIFORM_INPUT_IMAGE_TEXTURE] = glGetUniformLocation(_tempProgramHandle, "inputImageTexture");
    
    //饱和度值
    glViewUniforms[UNIFORM_SATURATION] = glGetUniformLocation(_tempProgramHandle, "saturation");
    
    /*
     默认情况下，出于性能考虑，所有顶点着色器的属性（Attribute）变量都是关闭的，意味着数据在着色器端是不可见的，哪怕数据已经上传到GPU，由glEnableVertexAttribArray启用指定属性，才可在顶点着色器中访问逐顶点的属性数据。
     glVertexAttribPointer或VBO只是建立CPU和GPU之间的逻辑连接，从而实现了CPU数据上传至GPU。但是，数据在GPU端是否可见，即，着色器能否读取到数据，由是否启用了对应的属性决定，这就是glEnableVertexAttribArray的功能，允许顶点着色器读取GPU（服务器端）数据。
     
     那么，glEnableVertexAttribArray应该在glVertexAttribPointer之前还是之后调用？答案是都可以，只要在绘图调用（glDraw*系列函数）前调用即可。
     */
    glEnableVertexAttribArray(glViewAttributes[TEMP_ATTRIBUTE_POSITION]);
    glEnableVertexAttribArray(glViewAttributes[TEMP_ATTRIBUTE_INPUT_TEXTURE_COORDINATE]);

}

- (void)render {
    
    //绘制第一个滤镜
    //使用program
    glUseProgram(_tempProgramHandle);
    
    //绑定frameBuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _tempFramebuffer);
    
    //设置视口
    glViewport(0, 0, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor);
    
    //设置清屏颜色
    glClearColor(0, 0, 1, 1);
    
    //清理屏幕
    glClear(GL_COLOR_BUFFER_BIT);
    
    //为当前的program指定uniform值
    /*
     glUniform1i (GLint location, GLint x)
     参数列表:
     1.location,位置
     2.value,值
     */
    //纹理
    glUniform1i(glViewUniforms[TEMP_UNIFORM_INPUT_IMAGE_TEXTURE], 1);
    //饱和度
    glUniform1f(glViewUniforms[UNIFORM_SATURATION], _saturation);
    
    /*
     void glVertexAttribPointer( GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride,const GLvoid * pointer);
     从CPU内存中把数据传递到GPU中
     参数列表:
     1.index,索引值
     2.size,组件属性
     3.type,类型
     4.normalied,是否归一化
     5.stride,偏移量,步长
     6.pointer,指针位置
     */
    //顶点数据
    glVertexAttribPointer(glViewAttributes[TEMP_ATTRIBUTE_POSITION], 4, GL_FLOAT, GL_FALSE, sizeof(CustomVertex), 0);
    //纹理数据
    glVertexAttribPointer(glViewAttributes[TEMP_ATTRIBUTE_INPUT_TEXTURE_COORDINATE], 2, GL_FLOAT, GL_FALSE, sizeof(CustomVertex), (GLvoid *)(sizeof(float) * 4));
    
    //绘制
    /*
     glDrawArrays (GLenum mode, GLint first, GLsizei count);
     参数列表:
     1.mode,模式
     2.first,从数组的哪一位开始绘制,一般设置为0
     3.count,顶点个数
     */
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    
    // 绘制第二个滤镜
    //使用program
    glUseProgram(_programHandle);
    
    //绑定FrameBuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    //绑定RenderBuffer
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    //设置清屏颜色
    glClearColor(1, 0, 0, 1);
    
    //清除颜色缓存区
    glClear(GL_COLOR_BUFFER_BIT);
    
    //设置视口
    glViewport(0, 0, self.frame.size.width * self.contentScaleFactor, self.frame.size.height * self.contentScaleFactor);
    
    //为当前的program指定uniform值
    /*
     glUniform1i (GLint location, GLint x)
     参数列表:
     1.location,位置
     2.value,值
     */
    
    //纹理
    glUniform1i(glViewUniforms[UNIFORM_INPUT_IMAGE_TEXTURE], 0);
    
    //色温
    glUniform1f(glViewUniforms[UNIFORM_TEMPERATURE], _temperature);
    
    /*
     void glVertexAttribPointer( GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride,const GLvoid * pointer);
     从CPU内存中把数据传递到GPU中
     参数列表:
     1.index,索引值
     2.size,组件属性
     3.type,类型
     4.normalied,是否归一化
     5.stride,偏移量,步长
     6.pointer,指针位置
     */
    //顶点数据
    glVertexAttribPointer(glViewAttributes[ATTRIBUTE_POSITION], 4, GL_FLOAT, GL_FALSE, sizeof(CustomVertex), 0);
    //纹理数据
    glVertexAttribPointer(glViewAttributes[ATTRIBUTE_INPUT_TEXTURE_COORDINATE], 2, GL_FLOAT, GL_FALSE, sizeof(CustomVertex), (GLvoid *)(sizeof(float) * 4));
    
    //绘制
    /*
     glDrawArrays (GLenum mode, GLint first, GLsizei count);
     参数列表:
     1.mode,模式
     2.first,从数组的哪一位开始绘制,一般设置为0
     3.count,顶点个数
     */
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    //要求本地窗口系统显示OpenGL ES渲染缓存绑定到RenderBuffer上
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - Public 
- (void)layoutGLViewWithImage:(UIImage *)image {
    //1.设置
    [self setup];
    
    //2.设置纹理图片
    [self setupTextureWithImage:image];
    
    //3.渲染
    [self render];

}

//设置色温
- (void)setTemperature:(CGFloat)temperature {
    //1.更新色温
    _temperature = temperature;
    //2.重新渲染
    [self render];
}

//设置饱和度
- (void)setSaturation:(CGFloat)saturation {
    //1.更新饱和度
    _saturation = saturation;
    //2.重新渲染
    [self render];
}

//设置纹理从图片
- (void)setupTextureWithImage:(UIImage *)image {
    
    //1.获取图片宽\高
    size_t width = CGImageGetWidth(image.CGImage);
    size_t height = CGImageGetHeight(image.CGImage);
    
    
    //2.获取颜色组件
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    //3.计算图片数据大小->开辟空间
    void *imageData = malloc( height * width * 4 );
    //CG开头的方法都是来自于CoreGraphics这个框架
    //了解CoreGraphics 框架
    
    //创建位图context
    /*
     CGBitmapContextCreate(void * __nullable data,
     size_t width, size_t height, size_t bitsPerComponent, size_t bytesPerRow,
     CGColorSpaceRef cg_nullable space, uint32_t bitmapInfo)
     参数列表:
     1.data,指向要渲染的绘制内存的地址
     2.width,bitmap的宽度,单位为像素
     3.height,bitmap的高度,单位为像素
     4.bitsPerComponent, 内存中像素的每个组件的位数.例如，对于32位像素格式和RGB 颜色空间，你应该将这个值设为8.
     5.bytesPerRow, bitmap的每一行在内存所占的比特数
     6.colorspace, bitmap上下文使用的颜色空间
     7.bitmapInfo,指定bitmap是否包含alpha通道，像素中alpha通道的相对位置，像素组件是整形还是浮点型等信息的字符串。
     
     
     */
    
    CGContextRef context = CGBitmapContextCreate(imageData,
                                                 width,
                                                 height,
                                                 8,
                                                 4 * width,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    //创建完context,可以释放颜色空间colorSpace
    CGColorSpaceRelease( colorSpace );
    
    /*
     绘制透明矩形。如果所提供的上下文是窗口或位图上下文，则核心图形将清除矩形。对于其他上下文类型，核心图形以设备依赖的方式填充矩形。但是，不应在窗口或位图上下文以外的上下文中使用此函数
     CGContextClearRect(CGContextRef cg_nullable c, CGRect rect)
     参数:
     1.C,绘制矩形的图形上下文。
     2.rect,矩形，在用户空间坐标中。
     */
    CGContextClearRect( context, CGRectMake( 0, 0, width, height ) );
    //CTM--从用户空间和设备空间存在一个转换矩阵CTM
    /*
     CGContextTranslateCTM(CGContextRef cg_nullable c,
     CGFloat tx, CGFloat ty)
     参数1:上下文
     参数2:X轴上移动距离
     参数3:Y轴上移动距离
     */
    CGContextTranslateCTM(context, 0, height);
    //缩小
    CGContextScaleCTM (context, 1.0,-1.0);
    
    //绘制图片
    CGContextDrawImage( context, CGRectMake( 0, 0, width, height ), image.CGImage );
    
    //释放context
    CGContextRelease(context);
    //在绑定纹理之前,激活纹理单元 glActiveTexture
    glActiveTexture(GL_TEXTURE1);
    
    //生成纹理标记
    glGenTextures(1, &_texture);
    
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, _texture);
    
    //设置纹理参数
    //环绕方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    //放大\缩小过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    
    //将图片载入纹理
    /*
     glTexImage2D (GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const GLvoid *pixels)
     参数列表:
     1.target,目标纹理
     2.level,一般设置为0
     3.internalformat,纹理中颜色组件
     4.width,纹理图像的宽度
     5.height,纹理图像的高度
     6.border,边框的宽度
     7.format,像素数据的颜色格式
     8.type,像素数据数据类型
     9.pixels,内存中指向图像数据的指针
     */
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGBA,
                 (GLint)width,
                 (GLint)height,
                 0,
                 GL_RGBA,
                 GL_UNSIGNED_BYTE,
                 imageData);
    
    //释放imageData
    free(imageData);
    
}

@end
