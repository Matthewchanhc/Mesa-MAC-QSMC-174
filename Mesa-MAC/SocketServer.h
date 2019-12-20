//
//  SocketServer.h
//  FastSocketTest
//
//  Created by Antonio Yu on 19/7/2017.
//  Copyright © 2017 Metron Hong Kong Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FastSocket.h"
#import "FastServerSocket.h"

@interface SocketServer : NSObject

- (void)start:(int)port;
- (void)stop;

@property (nonatomic, readonly) FastServerSocket *server;
@property (nonatomic, readonly) bool server_running;

@end
