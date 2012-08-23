//
//  PCWebServiceLocationManager.m
//
//  Created by Phillip Caudell on 23/08/2012.
//  Copyright (c) 2012 phillipcaudell.co.uk. All rights reserved.
//

#import "PCSingleRequestLocationManager.h"

@interface PCSingleRequestLocationManager()
{
    BOOL _maxWaitTimeReached;
    BOOL _minWaitTimeReached;
    BOOL _locationSettledUpon;
    NSTimer *_maxWaitTimeTimer;
    NSTimer *_minWaitTimeTimer;
}

- (void)maxWaitTimeReached;
- (void)minWaitTimeReached;
- (void)settleUponCurrentLocation;
- (void)cleanUp;

@end;

@implementation PCSingleRequestLocationManager

- (void)dealloc
{
    [_locationManager release];
    [super dealloc];
}

/**
 Creates new instance of PCWebServiceLocationManager.
 */
- (id)init
{
    self = [super init];
    if (self){
        
        // Hold onto ourselves until we have a result
        [self retain];
        
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        _locationManager.delegate = self;
        
    }
    return self;
}

/**
 Begins requesting the users current location. Delegate response will be fired once all location criteria are satisified.
 */
- (void)requestCurrentLocation
{
    // Start location manager
    [_locationManager startUpdatingLocation];
    
    // Start timers 
    _maxWaitTimeTimer = [NSTimer scheduledTimerWithTimeInterval:kPCWebServiceLocationManagerMaxWaitTime target:self selector:@selector(maxWaitTimeReached) userInfo:nil repeats:NO];
    _minWaitTimeTimer = [NSTimer scheduledTimerWithTimeInterval:kPCWebServiceLocationManagerMinWaitTime target:self selector:@selector(minWaitTimeReached) userInfo:nil repeats:NO];
}

#pragma mark CLLocationManager delegate

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    // Debug info
    if (kPCWebServiceLocationManagerDebug) {
        PCLog(@"PCWebServiceLocationManager: New location: %@", newLocation);
        PCLog(@"PCWebServiceLocationManager: Horizontal accuracy: %f", newLocation.horizontalAccuracy);
        PCLog(@"PCWebServiceLocationManager: Vertical accuracy: %f", newLocation.verticalAccuracy);
    }

    // If accuracy greater than 100 meters, it's probably crap
    if(newLocation.horizontalAccuracy > 100 && newLocation.verticalAccuracy > 100){
        if (kPCWebServiceLocationManagerDebug) {
            NSLog(@"PCWebServiceLocationManager: Accuracy poor, aborting...");
        }
        return;
    }
    
    // If location is older than 10 seconds, it's probably crap
    NSInteger locationTimeIntervalSinceNow = abs([newLocation.timestamp timeIntervalSinceNow]);
    if (locationTimeIntervalSinceNow > 10) {
        if (kPCWebServiceLocationManagerDebug) {
            NSLog(@"PCWebServiceLocationManager: Location old, aborting...");
        }
        return;
    }
    
    // If we haven't exceeded our min wait time, it's probably crap
    if (!_minWaitTimeReached) {
        if (kPCWebServiceLocationManagerDebug) {
            NSLog(@"PCWebServiceLocationManager: Min wait time not yet reached, aborting...");
        }
        return;
    }
    
    [self settleUponCurrentLocation];
    
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if ([_delegate respondsToSelector:@selector(singleRequestLocationManager:didFailToGetLocationWithError:)]) {
        
        if (kPCWebServiceLocationManagerDebug) {
            NSLog(@"PCWebServiceLocationManager: Did fail with error: %@", error);
        }
        
        [_delegate singleRequestLocationManager:self didFailToGetLocationWithError:error];
        
    }
    [self cleanUp];
}

#pragma mark Private helper methods

- (void)maxWaitTimeReached
{
    _maxWaitTimeReached = YES;
    _maxWaitTimeTimer = nil;
    [self settleUponCurrentLocation];
}

- (void)minWaitTimeReached
{
    _minWaitTimeReached = YES;
    _minWaitTimeTimer = nil;
}

/**
 Once all location crtiera has been met
 */
- (void)settleUponCurrentLocation
{
    // If we've already settled upon a location, don't fire again
    if (_locationSettledUpon) {
        return;
    }
    
    if (kPCWebServiceLocationManagerDebug) {
        NSLog(@"PCWebServiceLocationManager: Settling on location: %@", self.locationManager.location);
    }
    
    // Location settled upon!
    _locationSettledUpon = YES;
    
    if ([_delegate respondsToSelector:@selector(singleRequestLocationManager:didGetLocation:)]) {
        [_delegate singleRequestLocationManager:self didGetLocation:_locationManager.location];
    }
    
    [self cleanUp];
    
}

- (void)cleanUp
{
    [_maxWaitTimeTimer invalidate];
    [_minWaitTimeTimer invalidate];
    [_locationManager stopUpdatingLocation];
    
    // Sent our result, we're outta here...
    [self release];
}

@end
