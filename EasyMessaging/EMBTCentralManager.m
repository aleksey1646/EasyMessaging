//
//  EMBTCentralManager.m
//  EasyMessaging
//
//  Created by Alexei Zhutenkov on 25/08/14.
//  Copyright (c) 2014 ZhutenkovAlexei. All rights reserved.
//

#import "EMBTCentralManager.h"

static EMBTCentralManager *_sharedManager = nil;

@implementation EMBTCentralManager

+ (instancetype)sharedManager
{
    
    @synchronized(self)
    {
    if(!_sharedManager)
        _sharedManager = [[EMBTCentralManager alloc] init];
    }
    
    return _sharedManager;
}

@end
