runtime消息机制步骤：
通过object_msgSend传入消息接受者及方法名。
通过汇编代码解析过程。

1.从isa与操作找到类，是否taggerPointer，这个是oc的优化，存储小数据，直接用32位地址取出最高位和最低位是类型，中间的就是存储的IMP的地址。
2.没有找到IMP，在缓存链表中查找，没有就会跳转lookupforForwork  c方法。
3.再从类的缓存链表中读取，因为oc是一门动态语言，可能动态添加进入缓存中。
4.从类方法链表中读取，如果有进行存入缓存链表中。
5.在for循环中一直在spuerClass中缓存链表和方法链表中获取
6.获取调用动态方法解析，如果resolveInstanceMethod没有实现就会去转发。
7.forwardingTargetForSelector，方法名注册或者转发为其他类。如果没有实现就会报错unrecognized selector sent to

注册类之前可以添加实例变量，之后不能，而添加方法之前之后都行。

api的应用：
1.model转数组，字典等，归档及解档。
2.方法交换，数组越界，方法统计等。
‣敬牡佮数䝮䕬੓