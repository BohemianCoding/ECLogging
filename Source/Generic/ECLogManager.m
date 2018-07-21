// --------------------------------------------------------------------------
//  Copyright 2017 Elegant Chaos Limited. All rights reserved.
//  This source code is distributed under the terms of Elegant Chaos's
//  liberal license: http://www.elegantchaos.com/license/liberal
// --------------------------------------------------------------------------

#import "ECLogManager.h"

@interface ECLogManager ()

// --------------------------------------------------------------------------
// Private Properties
// --------------------------------------------------------------------------

@property (strong, nonatomic) NSArray* handlersSorted;
@property (strong, nonatomic) NSDictionary* defaultSettings;


@end


@implementation ECLogManager

// --------------------------------------------------------------------------
// Notifications
// --------------------------------------------------------------------------

NSString* const LogChannelsChanged = @"LogChannelsChanged";

// --------------------------------------------------------------------------
// Constants
// --------------------------------------------------------------------------

static NSString* const DebugLogSettingsFile = @"ECLoggingDebug";
static NSString* const LogSettingsFile = @"ECLogging";

static NSString* const ChannelsKey = @"Channels";
static NSString* const ForceDebugMenuKey = @"ECLoggingMenu";
static NSString* const HandlersKey = @"Handlers";
static NSString* const InstallDebugMenuKey = @"InstallMenu";
static NSString* const LogManagerSettingsKey = @"ECLogging";
static NSString* const OptionsKey = @"Options";
static NSString* const ResetSettingsKey = @"ECLoggingReset";
static NSString *const SuppressedAssertionsKey = @"SuppressedAssertions";
static NSString* const VersionKey = @"Version";

static NSUInteger kSettingsVersion = 4;

// --------------------------------------------------------------------------
// Properties
// --------------------------------------------------------------------------

static ECLogManager* gSharedInstance = nil;

/// --------------------------------------------------------------------------
/// Return the shared instance.
/// --------------------------------------------------------------------------

+ (ECLogManager*)sharedInstance
{
#if TEST_WARNING
	int x = 10;
#endif
#if TEST_ANALYZER
	NSString* string = @"blah";
	string = @"doodah";
#endif

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		gSharedInstance = [ECLogManager new];
	});

	return gSharedInstance;
}

// --------------------------------------------------------------------------
//! Initialise the log manager.
// --------------------------------------------------------------------------

- (instancetype)init
{
	self = [super init];
	if (self) {
		[self startup];
	}

	return self;
}

/**
 Start up the log manager, read settings, etc.
 */

- (void)startup {
	[self loadSettings];

	// The log manager is created on demand, the first time that a channel needs to register itself.
	// This allows channels to be declared and used in the simplest possible way, and to work in code
	// that runs early.
	// Since this can be before main() is called, and definitely before something nice and high level
	// like applicationWillFinishLaunching has been called, the client application won't have an opportunity
	// to set a delegate before startup is run.
	// As a workaround for this, we defer the final parts of the startup until the main runloop is in action.
	// This gives a window during which the client can set a delegate and adjust some other settings.

	dispatch_async(dispatch_get_main_queue(), ^{
		[self finishStartup];
	});
}

- (void)shutdown {
	id<ECLogManagerDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(logManagerWillShutdown:)])
		[delegate logManagerWillShutdown:self];

	self.settings = nil;

}

- (void)finishStartup {
	[self notifyDelegateOfStartup];
}

- (void)notifyDelegateOfStartup
{
	id<ECLogManagerDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(logManagerDidStartup:)])
	{
		[delegate logManagerDidStartup:self];
	}
}

// --------------------------------------------------------------------------
//! Return the default settings.
// --------------------------------------------------------------------------

- (NSDictionary*)defaultSettings
{
	if (!_defaultSettings) {
		_defaultSettings = @{
							 VersionKey : @(kSettingsVersion),
							 HandlersKey: @{ @"ECLogHandlerNSLog": @{ @"Default": @YES } },
							 ChannelsKey: @{}
							 };
	}

	return _defaultSettings;
}

- (NSUInteger)expectedSettingsVersionWithDefaultSettings:(NSDictionary*)defaultSettings
{
	NSUInteger expectedVersion = [defaultSettings[VersionKey] unsignedIntegerValue];
	if (expectedVersion == 0)
		expectedVersion = kSettingsVersion;

	return expectedVersion;
}

// --------------------------------------------------------------------------
//! Load saved channel details.
//! We make and register any channel found in the settings.
// --------------------------------------------------------------------------

- (void)loadSettings
{

	NSUserDefaults* userSettings = [NSUserDefaults standardUserDefaults];
	BOOL skipSavedSettings = [userSettings boolForKey:ResetSettingsKey];
	NSDictionary* savedSettings;
	if (skipSavedSettings)
	{
		[userSettings removeObjectForKey:LogManagerSettingsKey];
		savedSettings = nil;
	}
	else
	{
		savedSettings = [userSettings dictionaryForKey:LogManagerSettingsKey];
	}

	NSMutableDictionary* settings = [[self defaultSettings] mutableCopy];
	self.settings = settings;

	// the showMenu property is read/set here in generic code, but it's up to the
	// platform specific UI support to interpret it
	BOOL forceMenu = [userSettings boolForKey:ForceDebugMenuKey];
	if (forceMenu) {
	}
	self.showMenu = (forceMenu || [self.settings[InstallDebugMenuKey] boolValue]);
}


- (NSDictionary*)options
{
	return self.settings[OptionsKey];
}



// --------------------------------------------------------------------------
//! Revert all channels to default settings.
// --------------------------------------------------------------------------

- (void)resetAllSettings
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:LogManagerSettingsKey];
	[self loadSettings];
}


- (BOOL)debugChannelsAreEnabled {
#if EC_DEBUG
	return YES;
#else
	return NO;
#endif
}

- (BOOL)assertionsAreEnabled {
#if NS_BLOCK_ASSERTIONS
	return NO;
#else
	return YES;
#endif
}

- (void)showUI {
	id<ECLogManagerDelegate> delegate = self.delegate;
	if ([delegate respondsToSelector:@selector(showUIForLogManager:)]) {
		[delegate showUIForLogManager:self];
	 }
}

@end
