// --------------------------------------------------------------------------
//  Copyright 2017 Elegant Chaos Limited. All rights reserved.
//  This source code is distributed under the terms of Elegant Chaos's
//  liberal license: http://www.elegantchaos.com/license/liberal
// --------------------------------------------------------------------------

#define TEST_CRASH 0 // enable this to deliberately crash a test
#define TEST_FAILURE 0 // enable this to deliberately fail a test

@interface StringTests : BCTestCase
{
}

@end

@implementation StringTests

#pragma mark - Tests

#if TEST_FAILURE
- (void)testFailure
{
	BCTestFail("deliberate failure");
}
#endif

#if TEST_CRASH
- (void)testError
{
	*((char*)123) = 10;
}
#endif

- (void)testLastLines
{
	NSString* threeLines = [@[@"line1", @"line2", @"line3"] componentsJoinedByString:@"\n"];
	NSString* lastTwoLines = [@[@"line2", @"line3"] componentsJoinedByString:@"\n"];
	
	BCTestAssertStringIsEqual([threeLines lastLines:0], @"");
	BCTestAssertStringIsEqual([threeLines lastLines:1], @"line3");
	BCTestAssertStringIsEqual([threeLines lastLines:2], lastTwoLines);
	BCTestAssertStringIsEqual([threeLines lastLines:3], threeLines);
	BCTestAssertStringIsEqual([threeLines lastLines:4], threeLines);
}

- (void)testFirstLines
{
	NSString* threeLines = [@[@"line1", @"line2", @"line3"] componentsJoinedByString:@"\n"];
	NSString* firstTwoLines = [@[@"line1", @"line2"] componentsJoinedByString:@"\n"];
	
	BCTestAssertStringIsEqual([threeLines firstLines:0], @"");
	BCTestAssertStringIsEqual([threeLines firstLines:1], @"line1");
	BCTestAssertStringIsEqual([threeLines firstLines:2], firstTwoLines);
	BCTestAssertStringIsEqual([threeLines firstLines:3], threeLines);
	BCTestAssertStringIsEqual([threeLines firstLines:4], threeLines);
}

- (void)testMatchesString1
{
	NSString* test1 = @"This is a test string";
	NSString* test2 = @"This is a different string";
	
	NSString* after;
	NSUInteger index;
	UniChar divergent, expected;
	BOOL result = [test1 matchesString:test2 divergingAfter:&after atIndex:&index divergentChar:&divergent expectedChar:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(index, 10);
	BCTestAssertIntegerIsEqual(divergent, 't');
	BCTestAssertIntegerIsEqual(expected, 'd');
	
	result = [test1 matchesString:test1 divergingAfter:&after atIndex:&index divergentChar:&divergent expectedChar:&expected];
	BCTestAssertTrue(result);
	
	result = [@"" matchesString:@"" divergingAfter:&after atIndex:&index divergentChar:&divergent expectedChar:&expected];
	BCTestAssertTrue(result);
	
	result = [test1 matchesString:@"" divergingAfter:&after atIndex:&index divergentChar:&divergent expectedChar:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(index, 0);
	
	result = [@"" matchesString:test1 divergingAfter:&after atIndex:&index divergentChar:&divergent expectedChar:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(index, 0);
	
	result = [@"" matchesString:nil divergingAfter:&after atIndex:&index divergentChar:&divergent expectedChar:&expected];
	BCTestAssertTrue(result);
	BCTestAssertIntegerIsEqual(index, 0);
	
	result = [@"AAA" matchesString:@"BBB" divergingAfter:&after atIndex:&index divergentChar:&divergent expectedChar:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(index, 0);
	BCTestAssertIntegerIsEqual(divergent, 'A');
	BCTestAssertIntegerIsEqual(expected, 'B');
}

- (void)testMatchesString2
{
	NSString* test1 = @"This is a\ntest string";
	NSString* test2 = @"This is a\ndifferent string";
	
	NSString *diverged, *expected;
	NSUInteger line1, line2;
	BOOL result = [test1 matchesString:test2 divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected window:0];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line1, 1);
	BCTestAssertIntegerIsEqual(line2, 1);
	BCTestAssertStringIsEqual(diverged, @"test string");
	BCTestAssertStringIsEqual(expected, @"different string");
	
	result = [test1 matchesString:test1 divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected];
	BCTestAssertTrue(result);
	
	result = [@"" matchesString:@"" divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected];
	BCTestAssertTrue(result);
	
	result = [test1 matchesString:@"" divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line1, 0);
	BCTestAssertIntegerIsEqual(line2, 0);
	
	result = [@"" matchesString:test1 divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line1, 0);
	BCTestAssertIntegerIsEqual(line2, 0);
	
	result = [@"" matchesString:nil divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line1, 0);
	BCTestAssertIntegerIsEqual(line2, 0);
	
	result = [@"AAA" matchesString:@"BBB" divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line1, 0);
	BCTestAssertIntegerIsEqual(line2, 0);
	BCTestAssertStringIsEqual(diverged, @"AAA");
	BCTestAssertStringIsEqual(expected, @"BBB");
}

- (void)testMatchesString3
{
	NSString* test1 = @"This is a\ntest string";
	NSString* test2 = @"This is a\ndifferent string";
	
	NSString *after, *diverged, *expected;
	NSUInteger line;
	BOOL result = [test1 matchesString:test2 divergingAtLine:&line after:&after diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line, 1);
	BCTestAssertStringIsEqual(after, @"This is a\n");
	BCTestAssertStringIsEqual(diverged, @"test string");
	BCTestAssertStringIsEqual(expected, @"different string");
	
	result = [test1 matchesString:test1 divergingAtLine:&line after:&after diverged:&diverged expected:&expected];
	BCTestAssertTrue(result);
	
	result = [@"" matchesString:@"" divergingAtLine:&line after:&after diverged:&diverged expected:&expected];
	BCTestAssertTrue(result);
	
	result = [test1 matchesString:@"" divergingAtLine:&line after:&after diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line, 0);
	
	result = [@"" matchesString:test1 divergingAtLine:&line after:&after diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line, 0);
	
	result = [@"" matchesString:nil divergingAtLine:&line after:&after diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line, 0);
	
	result = [@"AAA" matchesString:@"BBB" divergingAtLine:&line after:&after diverged:&diverged expected:&expected];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line, 0);
}

- (void)testMatchesStringWindow
{
	NSString* test1 = @"l1\nl2\nl3\ntest string\nl5\nl6";
	NSString* test2 = @"l1\nl2\nl3\ndifferent string\nl5\nl6";
	
	NSString *diverged, *expected;
	NSUInteger line1, line2;
	
	BOOL result = [test1 matchesString:test2 divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected window:1];
	BCTestAssertFalse(result);
	BCTestAssertIntegerIsEqual(line1, 3);
	BCTestAssertIntegerIsEqual(line2, 3);
	BCTestAssertStringIsEqual(diverged, @"l3\ntest string\nl5\n");
	BCTestAssertStringIsEqual(expected, @"l3\ndifferent string\nl5\n");
}

- (void)testComponentsSeparatedByMixedCaps
{
	NSString* test = @"thisIsATestString";
	NSArray* components = [test componentsSeparatedByMixedCaps];
	NSString* combined = [components componentsJoinedByString:@"*"];
	BCTestAssertStringIsEqual(combined, @"this*Is*ATest*String");
	
	BCTestAssertLength([@"" componentsSeparatedByMixedCaps], 0);
}

@end
