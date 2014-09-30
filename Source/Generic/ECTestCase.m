// --------------------------------------------------------------------------
///  Copyright 2014 Sam Deane, Elegant Chaos. All rights reserved.
///  This source code is distributed under the terms of Elegant Chaos's
///  liberal license: http://www.elegantchaos.com/license/liberal
// --------------------------------------------------------------------------

#import "ECTestCase.h"
#import "ECParameterisedTestCase.h"
#import "ECTestComparisons.h"
#import "NSString+ECLogging.h"

#if !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
#endif

@interface ECTestCase()

@property (assign, atomic) BOOL exitRunLoop;

@end

@implementation ECTestCase

@synthesize exitRunLoop = _exitRunLoop;

// --------------------------------------------------------------------------
/// Return the default test suite.
/// We don't want ECTestCase to show up in the unit test
/// output, since it is an abstract class and has no tests of
/// its own.
/// So we suppress generation of a suite for these classes.
// --------------------------------------------------------------------------

+ (id) defaultTestSuite
{
    id result = nil;
    if (self != [ECTestCase class])
    {
        result = [super defaultTestSuite];
    }
    
    return result;
}

- (void)setUp
{
	NSFileManager* fm = [NSFileManager defaultManager];
	NSURL* url = [self URLForTemporaryFolder];
	NSError* error;
	[fm removeItemAtURL:url error:&error];
}

- (NSURL*)URLForTemporaryFolder
{
	NSURL* url = nil;
	NSError* error;
	NSUInteger length = [self.name length];
	if (length > 2)
	{
		NSString* name = [self.name substringWithRange:NSMakeRange(2, length - 3)];
		url = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:name];
		NSFileManager* fm = [NSFileManager defaultManager];
		[fm createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:&error];
	}
	
	return url;
}

- (NSURL*)URLForTemporaryFileNamed:(NSString *)name
{
	NSURL* url = [[self URLForTemporaryFolder] URLByAppendingPathComponent:name];

	return url;
}

- (NSURL*)URLForTemporaryFileNamed:(NSString *)name withExtension:(NSString *)ext
{
	NSURL* url = [[[self URLForTemporaryFolder] URLByAppendingPathComponent:name] URLByAppendingPathExtension:ext];

	return url;
}

- (BOOL)assertString:(NSString*)string1 matchesString:(NSString*)string2
{
	return [self assertString:string1 matchesString:string2 mode:ECTestComparisonShowLinesIgnoreWhitespace];
}

- (BOOL)assertCharactersOfString:(NSString*)string1 matchesString:(NSString*)string2
{
	NSUInteger divergence;
	UniChar divergentChar;
	UniChar expectedChar;
	NSString* prefix;
    BOOL result = [string1 matchesString:string2 divergingAfter:&prefix atIndex:&divergence divergentChar:&divergentChar expectedChar:&expectedChar];
	if (!result)
    {
        ECTestFail(@"strings diverge at character %d ('%lc' instead of '%lc')\n\nwe expected:\n%@\n\nwe got:\n%@\n\nthe bit that matched:\n%@\n\nthe bit that didn't:\n%@", (int)divergence, divergentChar, expectedChar, string2, string1, prefix, [string1 substringFromIndex:divergence]);
    }

	return result;
}

- (BOOL)assertCollection:(id)collection1 matchesCollection:(id)collection2
{
	BOOL result = [collection1 matches:collection2 block:^(NSString *context, NSUInteger level, id i1, id i2) {
		if (i1 && i2)
			NSLog(@"%@: %@ didn't match %@\n", context, i1, i2);
		else
			NSLog(@"%@: %@\n", context, i1 ? i1 : i2);
	}];

	ECTestAssertTrueFormat(result, @"collections didn't match");
	return result;
}

- (BOOL)assertLinesOfString:(NSString *)string1 matchesString:(NSString *)string2
{
	NSString* after, *diverged, *expected;
	NSUInteger line;
	BOOL result = [string1 matchesString:string2 divergingAtLine:&line after:&after diverged:&diverged expected:&expected];
    if (!result)
	{
		ECTestFail(@"strings diverge around line %ld:\n%@\n\nwe expected:'%@'\n\nwe got:'%@'\n\nfull string was:\n%@", (long)line, after, expected, diverged, string1);
	}

	return result;
}

- (BOOL)assertCollection:(id)collection1 matchesCollection:(id)collection2 mode:(ECTestComparisonMode)mode
{
	BOOL collectionsMatch;
	if (mode == ECTestComparisonDefault)
	{
		collectionsMatch = [self assertCollection:collection1 matchesCollection:collection2];
	}
	else
	{
		// NB if the collections dont match, we convert them to strings and try again - so [collection1 isEqual:collection2] may
		//       return NO, but as long as the string descriptions match, we don't assert
		collectionsMatch = [collection1 isEqual:collection2];
		NSString* string1;
		NSString* string2;
		if (!collectionsMatch)
		{
			string1 = [collection1 description];
			string2 = [collection2 description];
			collectionsMatch = [string1 isEqualToString:string2];
		}
		
		
		if (!collectionsMatch)
		{
			if ((mode == ECTestComparisonDiff) || (mode == ECTestComparisonDiffNoJSON))
			{
				NSURL* temp1 = [self URLForTemporaryFileNamed:@"collection1"];
				NSURL* temp2 = [self URLForTemporaryFileNamed:@"collection2"];
				
				if (mode == ECTestComparisonDiffNoJSON)
				{
					[self diffAsTextString1:string1 string2:string2 temp1:temp1 temp2:temp2];
				}
				else
				{
					// try to write as JSON - might not work but it'll produce nicer output
					@try {
						[self diffAsJSONCollection:collection1 collection2:collection2 temp1:temp1 temp2:temp2];
					}
					@catch (NSException *exception) {
						[self diffAsTextString1:string1 string2:string2 temp1:temp1 temp2:temp2];
					}
				}
				
				ECTestFail(@"collections failed to match");
			}
			else
			{
				collectionsMatch = [self assertString:string1 matchesString:string2 mode:mode];
			}
		}
	}

	return collectionsMatch;
}

- (void)diffAsJSONCollection:(id)collection1 collection2:(id)collection2 temp1:(NSURL*)temp1 temp2:(NSURL*)temp2
{
	NSError* error = nil;
	NSData* data1 = [NSJSONSerialization dataWithJSONObject:collection1 options:NSJSONWritingPrettyPrinted error:&error];
	NSData* data2 = [NSJSONSerialization dataWithJSONObject:collection2 options:NSJSONWritingPrettyPrinted error:&error];
	[data1 writeToURL:temp1 atomically:YES];
	[data2 writeToURL:temp2 atomically:YES];
	[self diffURL:temp1 againstURL:temp2];
}

- (void)diffAsTextString1:(id)string1 string2:(id)string2 temp1:(NSURL*)temp1 temp2:(NSURL*)temp2
{
	NSError* error = nil;
	[string1 writeToURL:temp1 atomically:YES encoding:NSUTF8StringEncoding error:&error];
	[string2 writeToURL:temp2 atomically:YES encoding:NSUTF8StringEncoding error:&error];
	[self diffURL:temp1 againstURL:temp2];
}

- (BOOL)assertLinesIgnoringWhitespaceOfString:(NSString *)string1 matchesString:(NSString *)string2
{
	NSString* diverged;
	NSString* expected;
	NSUInteger line1, line2;
	BOOL result = [string1 matchesString:string2 divergingAtLine1:&line1 andLine2:&line2 diverged:&diverged expected:&expected];
    if (!result)
	{
		ECTestFail(@"strings diverge at lines %ld/%ld:\nwe expected:'%@'\n\nwe got:'%@'\n\n", (long)line1, (long)line2, expected, diverged);
		if ([string1 length] < 1000)
			NSLog(@"full string was %@", string1);
	}

	return result;
}

- (BOOL)assertString:(NSString*)string1 matchesString:(NSString*)string2 mode:(ECTestComparisonMode)mode
{
	BOOL result = YES;
	ECTestAssertNotNil(string1);
	ECTestAssertNotNil(string2);
	if (string1 && string2)
	{
		switch (mode)
		{
			case ECTestComparisonShowChars:
				result = [self assertCharactersOfString:string1 matchesString:string2];
				break;

			case ECTestComparisonShowLines:
				result = [self assertLinesOfString:string1 matchesString:string2];
				break;

			case ECTestComparisonShowLinesIgnoreWhitespace:
			default:
				result = [self assertLinesIgnoringWhitespaceOfString:string1 matchesString:string2];
				break;
		}
	}
	
	return result;
}

- (BOOL)assertCollection:(id)collection matchesContentsOfURL:(NSURL*)url mode:(ECTestComparisonMode)mode
{
	BOOL result = YES;
	NSError* error;
	NSString* kind = [url pathExtension];
	if ([kind isEqualToString:@"json"])
	{
		id expected = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:url] options:0 error:&error];
		if (![collection isEqual:expected])
		{
			NSData* data = [NSJSONSerialization dataWithJSONObject:collection options:NSJSONWritingPrettyPrinted error:&error];

			NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			ECTestAssertNotNil(string);
			result = [self assertString:string matchesContentsOfURL:url mode:mode];
		}
	}
	else if ([kind isEqualToString:@"plist"])
	{
		NSData* data = [NSData dataWithContentsOfURL:url];
		ECTestAssertNotNil(data);
		id expected = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
		result = [self assertCollection:collection matchesCollection:expected mode:mode];
	}

	return result;
}

- (BOOL)assertString:(NSString*)string matchesContentsOfURL:(NSURL*)url mode:(ECTestComparisonMode)mode
{
	BOOL result = YES;
	NSError* error;
	NSString* expected = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
	if (expected)
	{
		#if !TARGET_OS_IPHONE
		if (mode == ECTestComparisonDiff)
		{
			if (![string isEqualToString:expected])
			{
				NSString* name = [url lastPathComponent];
				NSURL* temp = [self URLForTemporaryFileNamed:[@"Actual-" stringByAppendingString:name]];
				BOOL writtenTemp = [string writeToURL:temp atomically:YES encoding:NSUTF8StringEncoding error:&error];
				ECTestAssertTrueFormat(writtenTemp, @"failed to write temporary text file %@", error);
				if (writtenTemp) {
					[self diffURL:temp againstURL:url];
					ECTestFail(@"String failed to match contents of %@", name);
				}
				result = NO;
			}
		}
		else
		#endif
		{
			result = [self assertString:string matchesString:expected mode:mode];
		}
	}
	else
	{
		ECTestFail(@"Couldn't load string from %@", url);
		result = NO;
	}

	return result;
}

// --------------------------------------------------------------------------
/// Return a count for any item that supports the count or length methods.
/// Used in various test assert macros.
// --------------------------------------------------------------------------

+ (NSUInteger)genericCount:(id)item
{
	NSUInteger result;
	
	if ([item respondsToSelector:@selector(length)])
	{
		result = [(NSString*)item length]; // NB doesn't have to be a string, the cast is just there to stop xcode complaining about multiple method signatures
	}
	else if ([item respondsToSelector:@selector(count)])
	{
		result = [(NSArray*)item count]; // NB doesn't have to be an array, the cast is kust there to stop xcode complaining about multiple method signatures
	}
	else
	{
		result = 0;
	}
	
	return result;
}


// --------------------------------------------------------------------------
/// Does this string begin with another string?
/// Returns NO when passed the empty string.
// --------------------------------------------------------------------------

+ (BOOL)string:(NSString*)string1 beginsWithString:(NSString *)string2
{
	NSRange range = [string1 rangeOfString:string2];
	
	return range.location == 0;
}

// --------------------------------------------------------------------------
/// Does this string end with another string.
/// Returns NO when passed the empty string.
// --------------------------------------------------------------------------

+ (BOOL)string:(NSString*)string1 endsWithString:(NSString *)string2
{
	NSUInteger length = [string2 length];
	BOOL result = length > 0;
	if (result)
	{
		NSUInteger ourLength = [string1 length];
		result = (length <= ourLength);
		if (result)
		{
			NSString* substring = [string1 substringFromIndex:ourLength - length];
			result = [string2 isEqualToString:substring];
		}
	}
	
	return result;
}

// --------------------------------------------------------------------------
/// Does this string contain another string?
/// Returns NO when passed the empty string.
// --------------------------------------------------------------------------

+ (BOOL)string:(NSString*)string1 containsString:(NSString *)string2
{
	NSRange range = [string1 rangeOfString:string2];
	
	return range.location != NSNotFound;
}

- (NSURL *)URLForTestResource:(NSString *)name withExtension:(NSString *)ext
{
	NSBundle* bundle = [NSBundle bundleForClass:[self class]];
	return [bundle URLForResource:name withExtension:ext];
}

- (NSURL *)URLForTestResource:(NSString *)name withExtension:(NSString *)ext subdirectory:(NSString *)subpath
{
	NSBundle* bundle = [NSBundle bundleForClass:[self class]];
	return [bundle URLForResource:name withExtension:ext subdirectory:subpath];
}

// --------------------------------------------------------------------------
/// Return file path for a bundle which can be used for file tests.
// --------------------------------------------------------------------------

- (NSString*)exampleBundlePath
{
	// find test bundle in our resources
	NSBundle* ourBundle = [NSBundle bundleForClass:[self class]];
	NSString* path = [ourBundle pathForResource:@"Test" ofType:@"bundle"];
	
	return path;
}

// --------------------------------------------------------------------------
/// Return file URL for a bundle which can be used for file tests.
// --------------------------------------------------------------------------

- (NSURL*)exampleBundleURL
{
	NSURL* url = [NSURL fileURLWithPath:[self exampleBundlePath]];
	
	return url;
}

// --------------------------------------------------------------------------
/// Return a bundle which can be used for file tests.
// --------------------------------------------------------------------------

- (NSBundle*)exampleBundle
{
	NSBundle* bundle = [NSBundle bundleWithPath:[self exampleBundlePath]];
	
	return bundle;
}

// --------------------------------------------------------------------------
/// Some tests need the run loop to run for a while, for example
/// to perform an asynchronous network request.
/// This method runs until something external (such as a
/// delegate method) sets the exitRunLoop flag.
// --------------------------------------------------------------------------

- (void)runUntilTimeToExit
{
    self.exitRunLoop = NO;
    while (!self.exitRunLoop)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
    }
}

- (void)timeToExitRunLoop
{
    self.exitRunLoop = YES;
}

- (void)diffAsPlistObject:(id)object1 againstObject:(id)object2
{
	NSURL* temp1 = [self URLForTemporaryFileNamed:@"object1"];
	NSURL* temp2 = [self URLForTemporaryFileNamed:@"object2"];

	NSMutableData* data1 = [NSMutableData data];
	NSKeyedArchiver* archiver1 = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data1];
	[archiver1 setOutputFormat:NSPropertyListXMLFormat_v1_0];
	[archiver1 encodeObject:object1 forKey:@"root"];
	[archiver1 finishEncoding];

	NSMutableData* data2 = [NSMutableData data];
	NSKeyedArchiver* archiver2 = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data2];
	[archiver2 setOutputFormat:NSPropertyListXMLFormat_v1_0];
	[archiver2 encodeObject:object2 forKey:@"root"];
	[archiver2 finishEncoding];

	[data1 writeToURL:temp1 atomically:YES];
	[data2 writeToURL:temp2 atomically:YES];
	[self diffURL:temp1 againstURL:temp2];

}
- (void)diffURL:(NSURL*)url1 againstURL:(NSURL*)url2
{
#if !TARGET_OS_IPHONE // this doesn't make a lot of sense on iOS
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	// To use a different diff tool, do, eg:
    //         defaults write xctest DiffTool "/usr/local/bin/ksdiff"
	//
	// or uncomment below:
//	[defaults setObject:@"/usr/local/bin/ksdiff" forKey:@"DiffTool"];
//	[defaults synchronize];

	NSString* diff = [defaults stringForKey:@"DiffTool"];
    if (!diff)
        diff = @"/usr/bin/diff";

	if ([diff isEqualToString:@"off"])
	{
		NSLog(@"diffing of %@ and %@ disabled", [url1 lastPathComponent], [url2 lastPathComponent]);
	}
	else
	{
		NSTask *task;
		task = [[NSTask alloc] init];
		[task setLaunchPath: diff];
		[task setArguments: @[[url1 path], [url2 path]]];
		[task launch];
	}
#endif
}

#if !TARGET_OS_IPHONE

- (BOOL)imageAsPNG:(NSBitmapImageRep*)image exactlyMatchesReferenceImageAsPNG:(NSBitmapImageRep*)reference {
	NSData* imageData = [image representationUsingType:NSPNGFileType properties:@{NSImageInterlaced: @(YES)}];
	NSData* referenceData = [reference representationUsingType:NSPNGFileType properties:@{NSImageInterlaced: @(YES)}];
	return [imageData isEqual:referenceData];
}

- (NSBitmapImageRep*)bitmapAs32BitRGBA:(NSBitmapImageRep*)bitmap {
	NSInteger width = (NSInteger) [bitmap size].width;
	NSInteger height = (NSInteger) [bitmap size].height;
	
	if (width < 1 || height < 1)
		return nil;
	
	NSBitmapImageRep* sRGB = [bitmap bitmapImageRepByConvertingToColorSpace:[NSColorSpace sRGBColorSpace] renderingIntent:0];
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																	pixelsWide:width
																	pixelsHigh:height
																 bitsPerSample:8
															   samplesPerPixel:4
																	  hasAlpha:YES
																	  isPlanar:NO
																colorSpaceName:[sRGB colorSpaceName]
																   bytesPerRow:width * 4
																  bitsPerPixel:32];
	
	NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:ctx];
	
	NSRect rect = NSMakeRect(0, 0, width, height);
	[bitmap drawInRect:rect fromRect:rect operation:NSCompositeCopy fraction:1.0 respectFlipped:NO hints:nil];
	[ctx flushGraphics];
	[NSGraphicsContext restoreGraphicsState];
	
	return rep;
}

- (BOOL)image:(NSBitmapImageRep*)image matchesReferenceImage:(NSBitmapImageRep*)reference withinThreshold:(CGFloat)threshold pixelThreshold:(CGFloat)pixelThreshold {
	NSSize imageSize = image.size;
	NSSize referenceSize = reference.size;
	
	// TODO: need to deal with greyscale images differently? currently we convert them to RGBA, we could just conver them to 8-bit grey.
	NSBitmapImageRep* reference32 = [self bitmapAs32BitRGBA:reference];
	NSBitmapImageRep* image32 = [self bitmapAs32BitRGBA:image];
	if (!reference32 || !image32) {
		NSLog(@"couldn't convert images to 32-bit RGBA for comparison");
		return NO;
	}
	
	reference = reference32;
	image = image32;
	
	struct Pixel { uint8_t r, g, b, a; };
	struct Pixel *referencePixels = (struct Pixel *)[reference bitmapData];
	struct Pixel *imagePixels = (struct Pixel *)[image bitmapData];
	
	BOOL result = NSEqualSizes(imageSize, referenceSize);
	if (result) {
		CGFloat overallDiff = 0;
		CGFloat maxPixelDiff = 0;
		
		struct Pixel *referenceLoc = referencePixels;
		struct Pixel *imageLoc = imagePixels;
		for (NSInteger y = 0; y < imageSize.height; ++y) { //having X as our inner loop is much faster for locality-of-reference
			for (NSInteger x = 0; x < imageSize.width; ++x) {
				CGFloat pixelDiff = fabs(imageLoc->r - referenceLoc->r)/255;
				pixelDiff += fabs(imageLoc->g - referenceLoc->g)/255.0;
				pixelDiff += fabs(imageLoc->b - referenceLoc->b)/255.0;
				pixelDiff += fabs(imageLoc->a - referenceLoc->a)/255.0;
				if (pixelDiff) {
					if (pixelDiff > maxPixelDiff)
						maxPixelDiff = pixelDiff;
					overallDiff += pixelDiff;
				}
				
				referenceLoc++;
				imageLoc++;
			}
		}
		
		CGFloat averageDiff = overallDiff / (imageSize.width * imageSize.height);
		NSLog(@"Image differences: average %lf max %lf", averageDiff, maxPixelDiff);
		
		result = (averageDiff <= threshold);
		if (!result) {
			NSLog(@"Average difference in pixels %lf was over the threshold %lf", averageDiff, threshold);
		}
		else {
			result = (maxPixelDiff <= pixelThreshold);
			if (!result) {
				NSLog(@"One or more pixel differences %lf was over the threshold %lf", maxPixelDiff, pixelThreshold);
			}
		}
	}
	
	return result;
	
}

#endif

@end

