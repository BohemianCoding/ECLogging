//
//  ComparisonTests.m
//  ECLogging
//
//  Created by Sam Deane on 21/11/2013.
//  Copyright (c) 2015 Sam Deane, Elegant Chaos. All rights reserved.
//

@interface ComparisonTests : BCTestCase
@property (strong, nonatomic) NSString* output;
@end

@implementation ComparisonTests

- (BOOL)item:(id)item1 matches:(id)item2
{
	NSMutableString* string = [NSMutableString new];
	BOOL result = [item1 matches:item2 options:BCTestComparisonNone block:^(NSString* context, NSUInteger level, id i1, id i2) {
		if (i1 && i2)
			[string appendFormat:@"%@: %@ didn't match %@\n", context, i1, i2];
		else
			[string appendFormat:@"%@: %@\n", context, i1 ? i1 : i2];
	}];

	self.output = string;
	NSLog(@"Output:\n%@", string);
	
	return result;
}

- (BOOL)item:(id)item1 fuzzyMatches:(id)item2
{
	NSMutableString* string = [NSMutableString new];
	BOOL result = [item1 matches:item2 options:BCTestComparisonDoubleFuzzy block:^(NSString* context, NSUInteger level, id i1, id i2) {
		if (i1 && i2)
			[string appendFormat:@"%@: %@ didn't match %@\n", context, i1, i2];
		else
			[string appendFormat:@"%@: %@\n", context, i1 ? i1 : i2];
	}];
	
	self.output = string;
	NSLog(@"Output:\n%@", string);
	
	return result;
}

- (void)testStringsEqual
{
	BCTestAssertTrue([self item:@"abc" matches:@"abc"]);
	BCTestAssertIsEqual(self.output, @"");
}

- (void)testStringsDifferent
{
	BCTestAssertFalse([self item:@"abc" matches:@"def"]);
	BCTestAssertIsEqual(self.output, @"string: abc didn't match def\n");
}

- (void)testArraysEqual
{
	NSArray* a1 = @[@"abc", @"def"];
	NSArray* a2 = @[@"abc", @"def"];
	BCTestAssertTrue([self item:a1 matches:a2]);
	BCTestAssertIsEqual(self.output, @"");
}

- (void)testArraysDifferent
{
	NSArray* a1 = @[@"abc", @"def"];
	NSArray* a2 = @[@"def", @"abc"];
	BCTestAssertFalse([self item:a1 matches:a2]);
	BCTestAssertIsEqual(self.output, @"array[0]: abc didn't match def\narray[1]: def didn't match abc\n");
}

- (void)testArraysShorter
{
	NSArray* a1 = @[@"abc", @"def"];
	NSArray* a2 = @[@"abc"];
	BCTestAssertFalse([self item:a1 matches:a2]);
	BCTestAssertIsEqual(self.output, @"array[1] missing item: def\n");
}

- (void)testArraysLonger
{
	NSArray* a1 = @[@"abc"];
	NSArray* a2 = @[@"abc", @"def"];
	BCTestAssertFalse([self item:a1 matches:a2]);
	BCTestAssertIsEqual(self.output, @"array[1] extra item: def\n");
}

- (void)testArraysDifferentAndLonger
{
	NSArray* a1 = @[@"abc"];
	NSArray* a2 = @[@"def", @"abc"];
	BCTestAssertFalse([self item:a1 matches:a2]);
	BCTestAssertIsEqual(self.output, @"array[0]: abc didn't match def\narray[1] extra item: abc\n");
}

- (void)testDictionariesEqual
{
	NSDictionary* d1 = @{ @"k1": @"abc",
		@"k2": @"def" };
	NSDictionary* d2 = @{ @"k1": @"abc",
		@"k2": @"def" };
	BCTestAssertTrue([self item:d1 matches:d2]);
	BCTestAssertIsEqual(self.output, @"");
}

- (void)testDictionariesDifferent
{
	NSDictionary* d1 = @{ @"k1": @"abc",
		@"k2": @"def" };
	NSDictionary* d2 = @{ @"k1": @"def",
		@"k2": @"abc" };
	BCTestAssertFalse([self item:d1 matches:d2]);
	BCTestAssertIsEqual(self.output, @"dictionary[@\"k2\"]: def didn't match abc\ndictionary[@\"k1\"]: abc didn't match def\n");
}

- (void)testDictionariesShorter
{
	NSDictionary* d1 = @{ @"k1": @"abc",
		@"k2": @"def" };
	NSDictionary* d2 = @{ @"k1": @"abc" };
	BCTestAssertFalse([self item:d1 matches:d2]);
	BCTestAssertIsEqual(self.output, @"dictionary[@\"k2\"] missing key k2: def\n");
}

- (void)testDictionariesLonger
{
	NSDictionary* d1 = @{ @"k1": @"abc" };
	NSDictionary* d2 = @{ @"k1": @"abc",
		@"k2": @"def" };
	BCTestAssertFalse([self item:d1 matches:d2]);
	BCTestAssertIsEqual(self.output, @"dictionary[@\"k2\"] extra key k2: def\n");
}

- (void)testDictionariesDifferentAndLonger
{
	NSDictionary* d1 = @{ @"k1": @"abc" };
	NSDictionary* d2 = @{ @"k1": @"def",
		@"k2": @"abc" };
	BCTestAssertFalse([self item:d1 matches:d2]);
	BCTestAssertIsEqual(self.output, @"dictionary[@\"k1\"]: abc didn't match def\ndictionary[@\"k2\"] extra key k2: abc\n");
}

- (void)testCompound
{
	id item1 = @{ @"k1": @[@"abc", @{ @"k2": @"def" }] };
	id item2 = @{ @"k1": @[@"def", @{ @"k3": @"def" }] };
	BCTestAssertFalse([self item:item1 matches:item2]);
	BCTestAssertIsEqual(self.output, @"dictionary[@\"k1\"][0]: abc didn't match def\ndictionary[@\"k1\"][1][@\"k2\"] missing key k2: def\ndictionary[@\"k1\"][1][@\"k3\"] extra key k3: def\n");
}

- (void)testChalkAndCheese
{
	id item1 = @[@"abc"];
	id item2 = @{ @"k1": @"abc" };
	BCTestAssertFalse([self item:item1 matches:item2]);
	BCTestAssertIsEqual(self.output, @"array vs dictionary array compared with dictionary: (\n    abc\n) didn't match {\n    k1 = abc;\n}\n");

	BCTestAssertFalse([self item:item2 matches:item1]);
	BCTestAssertIsEqual(self.output, @"dictionary vs array dictionary compared with array: {\n    k1 = abc;\n} didn't match (\n    abc\n)\n");

	BCTestAssertFalse([self item:@(1) matches:@"abc"]);
	BCTestAssertIsEqual(self.output, @"number vs string: 1 didn't match abc\n");
}

- (void)testFuzzyNSNumber
{
	id item1 = @[@(1.0000000001), @(0.9999999999)];
	id item2 = @[@(1.0), @(1.0)];
	BCTestAssertFalse([self item:item1 fuzzyMatches:item2]);
	BCTestAssertIsEqual(self.output, @"array[0]: 1.0000000001 didn't match 1\narray[1]: 0.9999999999 didn't match 1\n");
}

@end
