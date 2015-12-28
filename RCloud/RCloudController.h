//
//  RCloudContoller.h
//  RCloud
//
//  Created by Simon Urbanek on 9/9/15.
//  Copyright (c) 2015 Simon Urbanek. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RCloudController : NSViewController <NSWindowDelegate>
{
    IBOutlet NSTextField *label;
    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSButton *bStart;
    IBOutlet NSButton *bShutdown;
    IBOutlet NSTextField *stSKS;
    IBOutlet NSTextField *stRedis;
    IBOutlet NSTextField *stSOLR;
    IBOutlet NSTextField *stRserve;
    BOOL started, anyUp;
}

- (IBAction) startRCloud: (id) dummy;
- (IBAction) shutdownRCloud: (id) dummy;

@end
