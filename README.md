1.通过core Graphics 将图片image的数据读到imageData，激活纹理单元，生成纹理标记，绑定纹理，设置纹理参数（环绕方式，放大/缩小过滤），将imageData载入纹理。
2.设置图层，上下文，设置renderBuffer及frameBuffer，检查FrameBuffer。
3.链接shader，通过GLSL编写路径进行链接属性，uniform。
4.设置VBO，顶点坐标，纹理坐标，将数据拷贝到缓存对象。vbo只是建立cpu和gpu之间的逻辑连接，从而实现cpu数据上传至gpu。
5.设置纹理，绑定纹理，将图片载入纹理，设置纹理参数，绑定frameBuffer，FBO直接绘制到纹理中。
6.渲染，绑定fameBuffer，清理屏幕，设置纹理，饱和度，顶点数据，纹理数据，绘制，要求本地窗口系统显示OpenGL ES渲染缓存绑定到RenderBuffer上
