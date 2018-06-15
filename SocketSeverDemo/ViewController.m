//
//  ViewController.m
//  SocketSeverDemo
//
//  Created by 意一yiyi on 2018/3/26.
//  Copyright © 2018年 意一yiyi. All rights reserved.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"

#define kServerIPAddress @"192.168.0.133"
#define kServerPort 8080

#define kHeartBeatCheckTime 60// 心跳检测间隔
#define kHeartBeatTime 60 * 3// 心跳间隔

@interface ViewController ()<GCDAsyncSocketDelegate>

@property (strong, nonatomic) GCDAsyncSocket *serverSocket;// 服务端socket

@property (strong, nonatomic) NSMutableArray *clientSockets;// 用来保存所有的客户端socket

@property (strong, nonatomic) NSTimer *checkTimer;// 心跳检测计时器
@property (strong, nonatomic) NSMutableDictionary *heartBeatDict;// 存储客户端信条信息的字典

@property (strong, nonatomic) NSDictionary *currentPacketHead;// 包头

@property (weak,   nonatomic) IBOutlet UITextField *tf;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.clientSockets = [NSMutableArray array];
    self.heartBeatDict = [NSMutableDictionary dictionary];
}


#pragma mark - public methods

// 监听
- (IBAction)listen:(id)sender {
    
    [self initServerSocket];
}

// 断开连接
- (IBAction)disconnect:(id)sender {
    
    [self.serverSocket disconnect];
    self.serverSocket.delegate = nil;
    self.serverSocket = nil;
    
    [self.checkTimer invalidate];
    self.checkTimer = nil;
}

// 发送数据
- (IBAction)send:(id)sender {
    
    if (self.clientSockets == nil) {
        
        return;
    }
    
    
    NSData *sendData = [@"江南忆" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *sendData1 = [@"最忆是杭州" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *sendData2 = [@"山寺月中寻桂子" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *sendData3 = [@"郡亭枕头看潮头" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *sendData4 = [@"何日更重游" dataUsingEncoding:NSUTF8StringEncoding];
    
    
//    NSData *data = [self.tf.text dataUsingEncoding:NSUTF8StringEncoding];
    [self.clientSockets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        [self sendData:sendData msgType:@"txt" obj:obj];
        [self sendData:sendData1 msgType:@"img" obj:obj];
        [self sendData:sendData2 msgType:@"txt" obj:obj];
        [self sendData:sendData3 msgType:@"img" obj:obj];
        [self sendData:sendData4 msgType:@"txt" obj:obj];
    }];
}

// 发送数据前给每条数据添加一个包头
- (void)sendData:(NSData *)data msgType:(NSString *)type obj:(id)obj {
    
    NSInteger dataSize = data.length;
    
    // 包头
    NSMutableDictionary *headDict = [@{} mutableCopy];
    [headDict setObject:type forKey:@"type"];// 消息的类型，比如说文本消息、图片消息、语音消息、视频消息等
    [headDict setObject:[NSString stringWithFormat:@"%ld", dataSize] forKey:@"size"];// 消息体的大小
    // 包头转化成jsonStr
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:headDict options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    // 包头转化为data
    NSData *tempData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableData *sendData = [NSMutableData dataWithData:tempData];
    // 分界，拼接“\r\n”两个字符在包头后面，用来标志包头的结束
    [sendData appendData:[GCDAsyncSocket CRLFData]];
    
    // 包头后面拼接上原数据
    [sendData appendData:data];
    
    [obj writeData:sendData withTimeout:-1 tag:0];// tag：消息标记
}


#pragma mark - GCDAsyncSocketDelegate

// 服务端socket连接客户端socket成功的回调
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(nonnull GCDAsyncSocket *)newSocket {
    
    NSLog(@"===========>连接客户端成功\n");
    
    // 连接成功后，立马读取来自客户端的数据
//    [newSocket readDataWithTimeout:-1 tag:0];// 修改为下面这个读取方法
    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    
    // 保存客户端socket
    [self.clientSockets addObject:newSocket];
    
    // 连接成功后添加定时器
    [self addTimer];
}

// 服务端socket读取客户端socket数据成功后的回调
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    
    // 先读取到当前数据包头部信息
    if (self.currentPacketHead == nil) {
        
        self.currentPacketHead = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        
        if (self.currentPacketHead == nil) {
            
            NSLog(@"===========>数据格式出错了：包头数据为空");
            return;
        }
        
        // 获取包头中真正数据的长度
        NSInteger packetLength = [self.currentPacketHead[@"size"] integerValue];
        // 读取指定长度的真正数据
        [sock readDataToLength:packetLength withTimeout:-1 tag:0];
        
        return;
    }
    
    // 正式的包处理
    NSInteger packetLength = [self.currentPacketHead[@"size"] integerValue];
    // 说明数据有问题
    if (packetLength <= 0 || data.length != packetLength) {
        
        NSLog(@"===========>数据格式出错了：数据包数据大小不正确");
        return;
    }
    
    NSString *type = self.currentPacketHead[@"type"];
    
    if ([type isEqualToString:@"img"]) {
        
        NSLog(@"===========>收到了图片消息");
    }else{
        
        NSLog(@"===========>收到了文字消息：%@", [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]);
    }
    
    self.currentPacketHead = nil;
    
    // 继续读取下一条数据
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

// 服务端socket与客户端socket断开连接的回调
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    
    NSLog(@"%@", [NSString stringWithFormat:@"===========>与客户端断开连接：%@\n", err]);
}


#pragma mark - 初始化服务端socket

// 初始化服务端socket
- (void)initServerSocket {
    
    [self createServerSocket];
    [self listenClientSocket];
}

// 创建服务端socket
- (void)createServerSocket {
    
    self.serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
}

// 服务端socket开始监听来自指定端口客户端socket的连接请求
- (void)listenClientSocket {
    
    NSError *error = nil;
    BOOL result = [self.serverSocket acceptOnPort:kServerPort error:&error];
    if (result && error == nil) {
        
        NSLog(@"===========>服务端开始监听");
    }else {
        
        NSLog(@"%@", [NSString stringWithFormat:@"==========>服务端监听失败：%@", error]);
    }
}


#pragma mark - 心跳检测

- (void)addTimer {
    
    if (self.checkTimer) {
        
        return;
    }
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:kHeartBeatCheckTime target:self selector:@selector(checkLongConnect) userInfo:nil repeats:YES];// 心跳检测需要小于心跳间隔，因为心跳间隔设置的为3分钟，那么此处设置为1分钟
    [[NSRunLoop currentRunLoop] addTimer:self.checkTimer forMode:NSRunLoopCommonModes];
}

// 心跳检测
- (void)checkLongConnect {
    
    [self.heartBeatDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        
        // 获取当前时间
        NSString *currentTimeStr = [self getCurrentTime];
        
        // 如果某个客户端socket发送心跳连接的时间和当前时间相差3分钟以上，说明客户端3分钟都没给服务端发心跳数据包了，说明客户端出问题了，服务端应主动断开连接
        if (([currentTimeStr doubleValue] - [obj doubleValue]) > kHeartBeatTime) {
            
            NSLog(@"===========>客户端\"%@\"出问题了，服务端移除了与它的连接", key);
            
            [self.heartBeatDict removeObjectForKey:key];
        }else {
            
            NSLog(@"===========>客户端\"%@\"与服务端正常连接中...", key);
        }
    }];
}

// 获取当前时间
- (NSString *)getCurrentTime {
    
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval currentTime = [date timeIntervalSince1970];
    NSString *currentTimeStr = [NSString stringWithFormat:@"%.0f", currentTime];
    return currentTimeStr;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
