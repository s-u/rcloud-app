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
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>

@implementation RCloudController

/* we use POSIX sockets because everything else is trying to be asynchronous
   which is the opposite of what we want */
static bool connect_port(int port, const char *cmd) {
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
    if (ok && cmd) {
        if (send(s, cmd, strlen(cmd), 0)) {}
    }
    close(s);
    return ok;
}

static bool check_port(int port) {
    return connect_port(port, 0);
}

- (void)awakeFromNib {
    started = NO;
    [label setStringValue:@"Note: use Console.app (in Utilities) for detailed system log\n\nChecking RCloud services...\n"];
    [self checkServices];
}

#if 0
// we have to wait until the window becomes key, otherwise nothing will be
// visible before that ...
- (void) windowDidBecomeKey:(NSNotification *)notification {
    NSLog(@"win-key");
    if (!started) {
        started = YES;
        [self performSelectorOnMainThread:@selector(startRCloud:) withObject:nil waitUntilDone:NO];
    }
}
#endif

- (void) checkServices {
    BOOL isUp;
    anyUp = NO;
    [stSKS setStringValue: (isUp = check_port(4301)) ? @"OK" : @"-"];
    anyUp |= isUp;
    [stSOLR setStringValue: (isUp = check_port(8983)) ? @"OK" : @"-"];
    anyUp |= isUp;
    [stRedis setStringValue: (isUp = check_port(6379)) ? @"OK" : @"-"];
    anyUp |= isUp;
    [stRserve setStringValue: (isUp = check_port(8080)) ? @"OK" : @"-"];
    anyUp |= isUp;
    [bShutdown setEnabled:anyUp];
}

- (void) startRCloud: (id) dummy {
    NSLog(@"start");
    NSString *root = @"/Applications/RCloud.app/Contents/Resources";
    [progress startAnimation:self];
    [label setStringValue:@"Checking RCloud services ...\n"];
    if (!check_port(4301)) {
        int attempts = 0;
        [stSKS setStringValue:@"starting..."];
        [label setStringValue:[[label stringValue] stringByAppendingString:@" - SessionKeyServer ... not running, starting ...\n"]];
        NSTask *aTask = [[NSTask alloc] init];
        [aTask setCurrentDirectoryPath:[root stringByAppendingString:@"/rcloud/services/SessionKeyServer"]];
        [aTask setLaunchPath: [root stringByAppendingString:@"/rcloud/services/SessionKeyServer/run"]];
        [aTask launch];
        while (!check_port(4301)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            attempts++;
            if (attempts > 80) {
                [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: unable to start SessionKeyServer\n\nPlease make sure you have Java installed.\n"]];
                [stSKS setStringValue:@"FAILED"];
                [progress stopAnimation:self];
                return;
            }
        }
        [stSKS setStringValue:@"OK"];
        [label setStringValue:[[label stringValue] stringByAppendingString:@"   OK, launched successfully\n"]];
        [bShutdown setEnabled:YES];
    } else [label setStringValue:[[label stringValue] stringByAppendingString:@" - SessionKeyServer ... OK\n"]];
    if (!check_port(8983)) {
        [label setStringValue:[[label stringValue] stringByAppendingString:@" - SOLR ... not running, starting ...\n"]];
        [stSOLR setStringValue:@"starting..."];
        int attempts = 0;
        NSTask *aTask = [[NSTask alloc] init];
        [aTask setCurrentDirectoryPath:[root stringByAppendingString:@"/rcloud/services/solr/example"]];
        [aTask setLaunchPath: [root stringByAppendingString:@"/rcloud/services/solr/example/run"]];
        [aTask launch];
        while (!check_port(8983)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            attempts++;
            if (attempts > 100) {
                [stSOLR setStringValue:@"FAILED"];
                [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: unable to start SOLR\n\nPlease make sure you have Java installed.\n"]];
                [progress stopAnimation:self];
                return;
            }
        }
        [stSOLR setStringValue:@"OK"];
        [label setStringValue:[[label stringValue] stringByAppendingString:@"   OK, launched successfully\n"]];
    } else [label setStringValue:[[label stringValue] stringByAppendingString:@" - SOLR ... OK\n"]];
    if (!check_port(6379)) {
        [label setStringValue:[[label stringValue] stringByAppendingString:@" - Redis ... not running, starting ...\n"]];
        [stRedis setStringValue:@"starting..."];
        int attempts = 0;
        NSTask *aTask = [[NSTask alloc] init];
        [aTask setCurrentDirectoryPath:[root stringByAppendingString:@"/rcloud/services/redis"]];
        [aTask setLaunchPath: [root stringByAppendingString:@"/bin/redis-server"]];
        [aTask launch];
        while (!check_port(6379)) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            attempts++;
            if (attempts > 40) {
                [stRedis setStringValue:@"FAILED"];
                [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: unable to start Redis server.\n"]];
                [progress stopAnimation:self];
                return;
            }
        }
        [label setStringValue:[[label stringValue] stringByAppendingString:@"   OK, launched successfully\n"]];
        [stRedis setStringValue:@"OK"];
    } else [label setStringValue:[[label stringValue] stringByAppendingString:@" - Redis ... OK\n"]];
    if (!check_port(8080)) {
        [label setStringValue:[[label stringValue] stringByAppendingString:@" - RCloud ... not running, starting ...\n"]];
        [stRserve setStringValue:@"starting..."];
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
            if (attempts > 120) {
                [stRserve setStringValue:@"FAILED"];
                [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: unable to start RCloud server.\n"]];
                [progress stopAnimation:self];
                return;
            }
        }
        [stRserve setStringValue:@"OK"];
        [label setStringValue:[[label stringValue] stringByAppendingString:@"   OK, launched successfully\n"]];
    } else [label setStringValue:[[label stringValue] stringByAppendingString:@" - RCloud ... OK\n"]];
    [label setStringValue:[[label stringValue] stringByAppendingString:@"Starting Chrome with RCloud URL ... "]];
    NSTask *chromium = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:[NSArray arrayWithObjects:@"-a", [root stringByAppendingString:@"/Applications/Chromium.app" ], @"http://127.0.0.1:8080/login.R", nil]];
    [chromium waitUntilExit];
    [label setStringValue:[[label stringValue] stringByAppendingString:@"DONE\n"]];
    [progress stopAnimation:self];
    [bShutdown setEnabled:YES];
//    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:1.0];
}

- (void) shutdownRCloud: (id) dummy
{
    [progress startAnimation:self];
    NSString *root = @"/Applications/RCloud.app/Contents/Resources";
    if (check_port(8080)) {
        FILE *f = fopen([[root stringByAppendingString:@"/rcloud/run/rserve.pid"] UTF8String], "r");
        if (!f) {
            [label setStringValue:[[label stringValue] stringByAppendingString:@"\nERROR: cannot find PID file for Rserve, cannot shutdown RCloud"]];
        } else {
            char spid[64];
            if (fgets(spid, sizeof(spid), f)) {
                int pid = atoi(spid);
                [label setStringValue:[[label stringValue] stringByAppendingFormat:@"\nSending SIGINT to pid %d (RCloud Rserve)", pid]];
                kill(pid, SIGINT);
                int attempts = 0;
                while (check_port(8080) && attempts < 60) {
                    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
                    attempts++;
                }
            }
        }
    }
    if (check_port(6379)) { // REDIS shutdown
        connect_port(6379, "SHUTDOWN\n");
    }
    if (check_port(8983)) { // SOLR shutdown - this is a hacky way, but at least it will work even if another instance of the launcher started the service
        system("kill -INT `ps ax|grep java|grep start.jar | awk '{print $1}'`");
        int attempts = 0;
        while (check_port(8983) && attempts < 50) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
            attempts++;
        }
        if (check_port(8983)) {
            system("kill `ps ax|grep java|grep start.jar | awk '{print $1}'`");
            while (check_port(8983) && attempts < 100) {
                [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
                attempts++;
            }
        }
    }
    if (check_port(4301)) { // SKS shutdown
        system("kill -INT `ps ax|grep java|grep SessionKeyServer | awk '{print $1}'`");
        int attempts = 0;
        while (check_port(4301) && attempts < 50) {
            [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
            attempts++;
        }
    }
    [self checkServices];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    [self checkServices];
    [progress stopAnimation:self];
}


@end
