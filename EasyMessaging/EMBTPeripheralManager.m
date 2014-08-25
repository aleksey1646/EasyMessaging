//
//  EMBTPeripheralManager.m
//  EasyMessaging
//
//  Created by Alexei Zhutenkov on 25/08/14.
//  Copyright (c) 2014 ZhutenkovAlexei. All rights reserved.
//

#import "EMBTPeripheralManager.h"

static EMBTPeripheralManager *_sharedManager = nil;

@implementation EMBTPeripheralManager

+ (instancetype)sharedManager
{
    
    @synchronized(self)
    {
        if(!_sharedManager)
            _sharedManager = [[EMBTPeripheralManager alloc] init];
    }
    
    return _sharedManager;
}

@end
