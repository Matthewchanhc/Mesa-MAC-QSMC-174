//
//  SocketServer.m
//  FastSocketTest
//
//  Created by Antonio Yu on 19/7/2017.
//  Copyright © 2017 Metron Hong Kong Limited. All rights reserved.
//

#import "SocketServer.h"

@implementation SocketServer

- (void)start:(int)port
{
    
    _server = [[FastServerSocket alloc] initWithPort:[NSString stringWithFormat:@"%d", port]];
    [NSThread detachNewThreadSelector:@selector(listenAndRepeat:) toTarget:self withObject:nil];
    NSLog(@"Finished startup!");
}

- (void)listenAndRepeat:(id)obj {
    
    @autoreleasepool {
        
        NSLog(@"started listening");
        _server_running = true;
        
        [_server listen];
        
        while(_server_running)
        {
            FastSocket *incomingConnection = [_server accept];
            
            if (!incomingConnection) {
                NSLog(@"Connection error: %@", [_server lastError]);
                return;
            }
            
            // Read some bytes then echo them back.
            int bufferSize = 2048;
            unsigned char recvBuf[bufferSize];
            long bytesReceived = 0;
            
            do {
                // Read bytes.
                bytesReceived = [incomingConnection receiveBytes:recvBuf limit:bufferSize];
                
                if(bytesReceived <= 0)
                {
                    NSLog(@"Connection lost.");
                }
                else
                {
                    // Write bytes.
                    long remaining = bytesReceived;
                    while (remaining > 0) {
                        bytesReceived = [incomingConnection sendBytes:recvBuf count:remaining];
                        remaining -= bytesReceived;
                    }
                }
                
                // Allow other threads to work.
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                
            } while (bytesReceived > 0);
        }
    }

    [_server close];
}

- (void)stop
{
    @synchronized (self) {
        _server_running = false;
        [_server close];
    }
}


@end
