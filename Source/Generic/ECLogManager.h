// --------------------------------------------------------------------------
//  Copyright 2017 Elegant Chaos Limited. All rights reserved.
//  This source code is distributed under the terms of Elegant Chaos's
//  liberal license: http://www.elegantchaos.com/license/liberal
// --------------------------------------------------------------------------

EC_ASSUME_NONNULL_BEGIN

@class ECLogChannel;
@class ECLogHandler;
@class ECLogManager;

@protocol ECLogManagerDelegate <NSObject>
@optional
- (void)logManagerDidStartup:(ECLogManager*)manager;
@end

/**
 * Singleton which keeps track of all the log channels and log handlers, and mediates the logging process.
 * 
 * The singleton is obtained using [ECLogManager sharedInstance], but you don't generally need to access it directly.
 *
 * See <Index> for more details.
 */

@interface ECLogManager : NSObject


/**
 * Return the shared log manager.
 */

+ (ECLogManager*)sharedInstance;

/**
 All the ECLogManager settings.
 */

@property (strong, nonatomic, ec_nullable) NSDictionary *settings;

/**
 Options, as specified in the settings files.
 These are used to build an Options menu, as a quick way of changing user default values.
 */

@property (strong, nonatomic, readonly) NSDictionary* options;

@property (weak, nonatomic) id<ECLogManagerDelegate> delegate;
@property (assign, nonatomic) BOOL showMenu;

/**
 Cleanup and shut down.
 
 This should typically be called from `applicationWillTerminate`.
 */

- (void)shutdown;



/**
 Display some UI which allows configuration of the log manager.
 This is implemented by the delegate, and can be an overlay, a separate window, or
 anything else appropriate.
 */

- (void)showUI;

@end

// --------------------------------------------------------------------------
// Notifications
// --------------------------------------------------------------------------

extern NSString* const LogChannelsChanged;

EC_ASSUME_NONNULL_END
