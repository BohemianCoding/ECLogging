// --------------------------------------------------------------------------
//  Copyright 2016 Elegant Chaos Limited. All rights reserved.
//  This source code is distributed under the terms of Elegant Chaos's
//  liberal license: http://www.elegantchaos.com/license/liberal
// --------------------------------------------------------------------------

#include "ECAssertion.h"
#include "ECLogChannel.h"
#include "ECLoggingMacros.h"

ECDefineDebugChannel(AssertionChannel);

@implementation ECAssertion

+ (void)failAssertion:(const char*)expression
{
	[NSException raise:@"ECAssertion failed" format:@"Expression:%s", expression];
}

+ (id)assertObject:(id)object isOfClass:(Class)c
{
	ECAssert((object == nil) || [object isKindOfClass:c]);

	return object;
}

@end
