//
//  KaonScreenSaverView.m
//  KaonScreenSaver
//
//  Created by kaon on 11/8/10.
//  Copyright (c) 2010, __MyCompanyName__. All rights reserved.
//

#define BUILD_NUMBER 5
#define ANIMATION_INTERVAL 12.0
/**
 TODO:
 Hotkeys:
 /(?) -  help
 left - back
 p - pause
 delete
 e - edit
 f - filter folder
 m show 2 more from same folder
 
 configuration screen:
 interval
 folder filter
 labels - count, folder, file name
 label font
 
 file update thread:
 save deck
 file listener to update deck
 show images as soon as deck is big enough
 */
#import "KaonScreenSaverView.h"


@implementation KaonScreenSaverView

- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:ANIMATION_INTERVAL];

		m_files = [[NSMutableArray alloc] init];
		m_fileIndices = [[NSMutableArray alloc] init];
		m_path = @"/Users/kaon/Pictures";

		[self listFiles];
		[self shuffle];
    }
    return self;
}

- (void)startAnimation
{
    [super startAnimation];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
    [super drawRect:rect];
	
}

- (void)animateOneFrame
{
	[self setAnimationTimeInterval:ANIMATION_INTERVAL];
	NSSize size;
	NSShadow* shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:3];
	[shadow setShadowColor:[NSColor blackColor]];
	NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSColor whiteColor], NSForegroundColorAttributeName,
//								[NSColor blackColor], NSBackgroundColorAttributeName,
								[NSFont fontWithName:@"Helvetica" size:14], NSFontAttributeName,
								shadow, NSShadowAttributeName,
								nil];
	[shadow release];
	// Load a random image.
	NSNumber* index = [m_fileIndices objectAtIndex:m_currentFileIndex];
	NSString* m_file = [m_files objectAtIndex:[index integerValue]];
	m_currentFileIndex++;
	[m_image release];
	m_image = [[NSImage alloc] initWithContentsOfFile:[m_path stringByAppendingPathComponent:m_file]];
	
	NSRect dst, screenRect;
	NSSize orig;
	if ([m_image isValid]) {
		screenRect = [self bounds];
		
		// Wipe the screen.
		[[NSColor blackColor] set];
		NSRectFill(screenRect);
		
		dst.size = orig = [m_image size];
		
//		// Scale image to (just) fit in screen.
//		if (dst.size.width > screenRect.size.width) {
			CGFloat f = screenRect.size.width / dst.size.width;
			dst.size.width *= f;
			dst.size.height *= f;
//		}
		if (dst.size.height > screenRect.size.height) {
			f = screenRect.size.height / dst.size.height;
			dst.size.width *= f;
			dst.size.height *= f;
		}
		
		// Center it (no animation)
		dst = SSCenteredRectInRect(dst, screenRect);
		
		// Draw the whole thing (no cropping)
		[m_image drawInRect:dst fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
		
	}
	// Draw file name
	NSPoint p = dst.origin;
	p.x += 10;
	NSString* s = [NSString stringWithFormat:@"%@", m_file];
	[s drawAtPoint:p withAttributes:attributes];

	// Draw file count
	s = [NSString stringWithFormat:@"%i/%i", m_currentFileIndex, [m_fileIndices count]];
	size = [s sizeWithAttributes:attributes];
	p.x += dst.size.width - size.width - 20;
	p.y += dst.size.height - size.height;
	[s drawAtPoint:p withAttributes:attributes];
	
#if BUILD_NUMBER
	s = [NSString stringWithFormat:@"%i %i", BUILD_NUMBER, lastKeyCode];
	p.x = 1;
	// use same y as file count
	[s drawAtPoint:p withAttributes:attributes];
#endif
	
	// If out of files, get new set of files to show.
	if (m_currentFileIndex >= [m_fileIndices count]) {
		[self shuffle];
	}
    return;
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow*)configureSheet
{
    return nil;
}

- (void)listFiles
{
	[m_files removeAllObjects];
	
	NSFileManager *localFileManager=[[NSFileManager alloc] init];
	NSDirectoryEnumerator *dirEnum = [localFileManager enumeratorAtPath:m_path];
	
	NSString *file;
	while (file = [dirEnum nextObject]) {
		if ([file rangeOfString:@".picasaoriginals"].location != NSNotFound ||
			[file rangeOfString:@"080414_burned"].location != NSNotFound ||
			[file rangeOfString:@"040820_Alisha_Bachelorette"].location != NSNotFound ||
			[file rangeOfString:@"iPhoto Library"].location != NSNotFound) {
			[dirEnum skipDescendents];
			continue;
		}
		NSString* ext = [file pathExtension];
		if ([ext caseInsensitiveCompare:@"jpg"] == NSOrderedSame || 
			[ext caseInsensitiveCompare:@"png"] == NSOrderedSame ||
			[ext caseInsensitiveCompare:@"gif"] == NSOrderedSame ||
			[ext caseInsensitiveCompare:@"jpeg"] == NSOrderedSame
			) {
			// process the document
			NSLog(@"%@", [m_path stringByAppendingPathComponent:file]) ;
			[m_files addObject:file];
		}
	}
	[localFileManager release];
	
	[m_fileIndices removeAllObjects];
	for (int i = 0; i < [m_files count]; ++i) {
		[m_fileIndices addObject:[NSNumber numberWithInt:i]];
	}
}

- (void)shuffle
{
	for (int i = 0; i < [m_fileIndices count]; ++i) {
		int j = SSRandomIntBetween(i, [m_fileIndices count] - 1);
		if (i == j)
			continue;
		NSNumber* ni = [m_fileIndices objectAtIndex:i];
		NSNumber* nj = [m_fileIndices objectAtIndex:j];
		[m_fileIndices replaceObjectAtIndex:i withObject:nj];
		[m_fileIndices replaceObjectAtIndex:j withObject:ni];
	}
	m_currentFileIndex = 0;
}

- (void)keyDown:(NSEvent *)theEvent
{
	lastKeyCode = [theEvent keyCode];
	switch ([theEvent keyCode]) {
		case NSRightArrowFunctionKey:
			[self setAnimationTimeInterval:0.0];
			return;
		case ' ':
			return;
		default:
			break;
	}
//	[super keyDown:theEvent];
}
@end
