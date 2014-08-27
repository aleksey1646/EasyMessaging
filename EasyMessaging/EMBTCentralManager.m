//
//  EMBTCentralManager.m
//  EasyMessaging
//
//  Created by Alexei Zhutenkov on 25/08/14.
//  Copyright (c) 2014 ZhutenkovAlexei. All rights reserved.
//

#import "EMBTCentralManager.h"
#import "EMConstants.h"
#import <CoreBluetooth/CoreBluetooth.h>

static EMBTCentralManager *_sharedManager = nil;

@interface EMBTCentralManager () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong) CBCentralManager *centralManager;
@property (strong) NSMutableDictionary *dataPeripherals;

@end


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

- (id)init
{
    self = [super init];
    if (self) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
        self.dataPeripherals = [NSMutableDictionary dictionary];
    }
    return self;
}


/** Scan for peripherals - specifically for our service's 128bit CBUUID
 */
- (void)scan
{
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kTransferServiceUUID]]
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
    
}

#pragma mark -- CBCentralManagerDelegate

/** centralManagerDidUpdateState is a required protocol method.
 *  Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc.
 *  In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates
 *  the Central is ready to be used.
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        // In a real app, you'd deal with all the states correctly
        return;
    }
    
    [self scan];
}


/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    NSArray *connectedPeripherals = [central retrieveConnectedPeripheralsWithServices:@[[CBUUID UUIDWithString:kTransferServiceUUID]]];
    
    
    for (CBPeripheral *nextPeripheral in connectedPeripherals)
    {
        // Have we already seen it? Yes, then return
        if(nextPeripheral == peripheral)
            return;
    }
    
    // And connect
    [central connectPeripheral:peripheral options:nil];
}

/** If the connection fails for whatever reason, we need to deal with it.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
}

/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected");
    
//    // Clear the data that we may already have
//    [self.data setLength:0];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kTransferServiceUUID]]];
}

/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
}

#pragma mark -- CBPeripheralDelegate

/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        return;
    }
    
    // Discover the characteristic we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:kTransferCharacteristicUUID]] forService:service];
    }
}

/** The Transfer characteristic was discovered.
 *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kTransferCharacteristicUUID]]) {
            
            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    
    // Once this is complete, we just need to wait for the data to come in.
}

/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    // Have we got everything we need?
    if ([stringFromData isEqualToString:@"EOM"]) {
        
        // We have, so show the data,
//        [self.textview setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];
        
//        // Cancel our subscription to the characteristic
//        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
//        
//        // and disconnect from the peripehral
//        [self.centralManager cancelPeripheralConnection:peripheral];
        
        [_dataPeripherals removeObjectForKey:[NSString stringWithFormat:@"%@", peripheral]];
    }
    
    // Otherwise, just add the data on to what we already have
    NSMutableData *data = [_dataPeripherals objectForKey:[NSString stringWithFormat:@"%@", peripheral]];
    if(!data)
    {
        [_dataPeripherals setValue:data forKey:[NSString stringWithFormat:@"%@", peripheral]];
    }
    
    [data appendData:characteristic.value];
    
    // Log it
    NSLog(@"Received: %@", stringFromData);
}

/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    // Exit if it's not the transfer characteristic
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:kTransferCharacteristicUUID]]) {
        return;
    }
    
    // Notification has started
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    }
    
    // Notification has stopped
    else {
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}





@end
