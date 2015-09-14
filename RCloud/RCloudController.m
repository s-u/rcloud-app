//
//  RCloudContoller.m
//  RCloud
//
//  Created by Simon Urbanek on 9/9/15.
//  Copyright (c) 2015 Simon Urbanek. All rights reserved.
//

#import "RCloudController.h"

// for socket stuff
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

@implementation RCloudController

/* we use POSIX sockets because everything else is trying to be asynchronous
   which is the opposite of what we want */
static bool check_port(int port) {
    bool ok = false;
    struct sockaddr_in sa;
    int s;
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_port = htons(port);
    sa.sin_addr.s_addr = htonl(0x7f000001); /* 127.0.0.1 */
    
    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s == -1) return false;
    ok = (connect(s, (struct sockaddr*)&sa, sizeof(sa)) == -1) ? false : true;
    close(s);
    return ok;
}

- (void)awakeFromNib {
    NSLog(@"awake");
    started = NO;
    [label setStringValue:@"Starting RCloud ..."];
}

// we have to wait until the window becomes key, otherwise nothing will be
// visible before that ...
- (void) windowDidBecomeKey:(NSNotification *)notification {
    NSLog(@"win-key");
    if (!started) {
        started = YES;
        [self performSelectorOnMainThread:@selector(startRCloud:) withObject:nil waitUntilDone:NO];
    }
}

- (void) startRCloud: (id) dummy {
    NSLog(@"start");
    NSString *root = @"/Applications/RCloud.app/Contents/Resources";
    [label setStringValue:@"Checking RCloud services ...\n"];
    if (!check_port(4301)) {
        int attempts = 0;
        [label setStringValue:[[label stringValue] stringByAppendingString:@" - SessionKeyServer ... not running, starting ...\n"]];
        NSTask *aTask = [[NSTask alloc] init];
        [aTask setCurrentDirectoryPath:[root stringByAppendingString:@"/rcloud/services/SessionKeyServer"]];
        [aTask setLaunchPath: [root stringByAppendingString:@"/rcloud/services/SessionKeyServer/run"]];
        [aTask launch];
        while (!check_port(4301)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            attempts++;
            if (attempts > 50) {
                [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: unable to start SessionKeyServer\n\nPlease make sure you have Java installed.\n"]];
                return;
            }
        }
        [label setStringValue:[[label stringValue] stringByAppendingString:@"   OK, launched successfully\n"]];
    } else [label setStringValue:[[label stringValue] stringByAppendingString:@" - SessionKeyServer ... OK\n"]];
    if (!check_port(8983)) {
        [label setStringValue:[[label stringValue] stringByAppendingString:@" - SOLR ... not running, starting ...\n"]];
        int attempts = 0;
        NSTask *aTask = [[NSTask alloc] init];
        [aTask setCurrentDirectoryPath:[root stringByAppendingString:@"/rcloud/services/solr/example"]];
        [aTask setLaunchPath: [root stringByAppendingString:@"/rcloud/services/solr/example/run"]];
        [aTask launch];
        while (!check_port(8983)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            attempts++;
            if (attempts > 50) {
                [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: unable to start SOLR\n\nPlease make sure you have Java installed.\n"]];
                return;
            }
        }
        [label setStringValue:[[label stringValue] stringByAppendingString:@"   OK, launched successfully\n"]];
    } else [label setStringValue:[[label stringValue] stringByAppendingString:@" - SOLR ... OK\n"]];
    if (!check_port(6379)) {
        [label setStringValue:[[label stringValue] stringByAppendingString:@" - Redis ... not running, starting ...\n"]];
        int attempts = 0;
        NSTask *aTask = [[NSTask alloc] init];
        [aTask setCurrentDirectoryPath:[root stringByAppendingString:@"/rcloud/services/redis"]];
        [aTask setLaunchPath: [root stringByAppendingString:@"/bin/redis-server"]];
        [aTask launch];
        while (!check_port(6379)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            attempts++;
            if (attempts > 40) {
                [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: unable to start Redis server.\n"]];
                return;
            }
        }
        [label setStringValue:[[label stringValue] stringByAppendingString:@"   OK, launched successfully\n"]];
    } else [label setStringValue:[[label stringValue] stringByAppendingString:@" - Redis ... OK\n"]];
    if (!check_port(8080)) {
        [label setStringValue:[[label stringValue] stringByAppendingString:@" - RCloud ... not running, starting ...\n"]];
        setenv("ROOT", [[root stringByAppendingString:@"/rcloud"] UTF8String], 1);
        setenv("LANG", "en_US.UTF-8", 1);
        int attempts = 0;
        NSTask *aTask = [[NSTask alloc] init];
        [aTask setCurrentDirectoryPath:[root stringByAppendingString:@"/rcloud"]];
        [aTask setLaunchPath: [root stringByAppendingString:@"/rcloud/conf/start"]];
        [aTask launch];
        while (!check_port(8080)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            attempts++;
            if (attempts > 100) {
                [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: unable to start RCloud server.\n"]];
                return;
            }
        }
        [label setStringValue:[[label stringValue] stringByAppendingString:@"   OK, launched successfully\n"]];
    } else [label setStringValue:[[label stringValue] stringByAppendingString:@" - RCloud ... OK\n"]];
    [label setStringValue:[[label stringValue] stringByAppendingString:@"Starting Chrome with RCloud URL ... "]];
    NSTask *chromium = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:[NSArray arrayWithObjects:@"-a", [root stringByAppendingString:@"/Applications/Chromium.app" ], @"http://127.0.0.1:8080/login.R", nil]];
    [chromium waitUntilExit];
    [label setStringValue:[[label stringValue] stringByAppendingString:@"DONE\n"]];
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:1.0];
}

@end
