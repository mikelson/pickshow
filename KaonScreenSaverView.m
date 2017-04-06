//
//  KaonScreenSaverView.m
//  PickShowScreenSaver
//
//  Created by Peter on 11/8/10.
//  Copyright © 2017 Peter Mikelsons. All rights reserved.
//
// Debugging in Xcode 4. Do clean build, then view build log in Log navigator to find product bundle name.
// Product > Edit Scheme... > Run System Preferences > Arguments Passed on Launch > <.saver take from build log>
//
// Debugging in Xcode 8.3: View "Build" item in Report navigator to find product bundle name.
// Product > Scheme > Edit Scheme... >Run System Preferences > Arguments Passed on Launch > <.saver take from build report>
//
// As of Xcode 4.5, building with Apple LLVM Compiler 4.1 causes crash when instantiating NSOpenPanel for picking folders.
// Workaround: use LLVM GCC 4.2
//

//#define BUILD_NUMBER 27
#define ANIMATION_INTERVAL 12.0
#define MIN_ANIMATION_INTERVAL 1.0
#define HELP_HUD_INTERVAL 10.0

/**
 TODO:
 
 skip folders which picker won't let you select, like iPhoto Library.bundle
 Hotkeys:
 pause
 edit
 filter folder
 show 2 more from same folder
 
 configuration screen:
 help button to show help viewer
 Skip Directories Named... (remove hardcoded Originals)
 labels - count, folder, file name
 label font
 
 file update thread:
 save deck
 file listener to update deck
 show images as soon as deck is big enough
 see Concurrency Programming Guide. NSOperationQueue + NSInvocationOperation?
 */
#import "KaonScreenSaverView.h"
#import "NSAttributedString+Hyperlink.h"

@implementation KaonScreenSaverView

- (NSString*)getCurrentFilePath
{
	return [m_path stringByAppendingPathComponent:m_currentFilePath];
}

- (void)listFiles
{
	[m_files removeAllObjects];
	
	NSFileManager *localFileManager=[[NSFileManager alloc] init];
	NSDirectoryEnumerator *dirEnum = [localFileManager enumeratorAtPath:m_path];
	
	NSString *file;
	while (file = [dirEnum nextObject]) {
        NSDictionary* fileAttributes = [dirEnum fileAttributes];
        NSString* fileType = [fileAttributes valueForKey:NSFileType];
		NSString* fileName = [file lastPathComponent];
        
        // Skip Hidden files and directories.
        if ([fileName length] > 0 && [fileName characterAtIndex:0] == '.') {
            if ([NSFileTypeDirectory isEqualToString:fileType]) {
                [dirEnum skipDescendents];
            }
            continue;
        }
        
		NSString* filePath = [NSString pathWithComponents:[NSArray arrayWithObjects:m_path, file, nil]];
		
		// Skip directories in m_pathsToSkip.
		NSInteger count;
		for (count = [m_pathsToSkip count] - 1; count >= 0; count--)
		{
			NSString* pathToSkip = [m_pathsToSkip objectAtIndex:count];
			if ([filePath rangeOfString:pathToSkip].location == 0)
			{
				[dirEnum skipDescendents];
				continue;
			}
		}
		if (count >= 0) {
			// continued out of previous loop
			continue;
		}
		// Hack to skip Picasa backup directories:
		if ([fileName isEqualToString:@"Originals"]
			) {
			[dirEnum skipDescendents];
			continue;
		}
		// Just show images.
		NSString* universalTypeIdentifier = [[NSWorkspace sharedWorkspace] typeOfFile:filePath error:nil]; // Available starting v10.5
		// Hopefully NSImage can handle all kUTTypeImages.
		if (UTTypeConformsTo((CFStringRef)universalTypeIdentifier, kUTTypeImage)) {
			// process the document
            //			NSLog(@"%@", [m_path stringByAppendingPathComponent:file]) ;
			[m_files addObject:file];
		}
	}
	[localFileManager release];
}

- (void)shuffle
{
    int count = [m_files count];
	for (int i = 0; i < count; ++i) {
		int j = SSRandomIntBetween(i, count - 1);
		if (i == j)
			continue;
		NSString* ni = [m_files objectAtIndex:i];
		NSString* nj = [m_files objectAtIndex:j];
		[ni retain]; // Mutable array releases i when it is replaced.
		[m_files replaceObjectAtIndex:i withObject:nj];
		[m_files replaceObjectAtIndex:j withObject:ni];
		[ni release];
	}
	m_nextFileIndex = 0;
}

#pragma mark ScreenSaverView

- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
		m_files = [[NSMutableArray alloc] init];
		m_pathsToSkip = [[NSMutableArray alloc] init];
        m_nextFileIndex = 0;
		
		NSUserDefaults* ud = [ScreenSaverDefaults defaultsForModuleWithName:@"PickShowScreenSaver"];
		if (ud)
		{
			m_path = [ud stringForKey:@"path"];
			m_interval = [ud floatForKey:@"interval"];
			NSArray* array = [ud stringArrayForKey:@"pathsToSkip"];
			if (array)
			{
				[m_pathsToSkip addObjectsFromArray:array];
			}
		}
		if (m_interval < MIN_ANIMATION_INTERVAL) {
			m_interval = ANIMATION_INTERVAL;
		}
        [self setAnimationTimeInterval:m_interval];
		
		if (m_path == nil)
		{
			m_path = [[@"~/Pictures" stringByExpandingTildeInPath] retain];
		}

		[self listFiles];
		[self shuffle];
    }
    return self;
}

- (void)animateOneFrame
{
    NSString* s;
    NSPoint p;
	NSSize size;
	NSRect dst;
    NSRect screenRect = [self bounds];
    CGFloat fontSize = screenRect.size.height * 16 / 800;
	NSShadow* shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:0.75 * fontSize];
	[shadow setShadowColor:[NSColor blackColor]];
	NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSColor whiteColor], NSForegroundColorAttributeName,
								[NSFont fontWithName:@"Helvetica" size:fontSize], NSFontAttributeName,
								shadow, NSShadowAttributeName,
								nil];
	[shadow release];
	
    // Wipe the screen.
    [[NSColor blackColor] set];
    NSRectFill(screenRect);
    
    if ([m_files count]) {
    
        // Load next image.
        m_currentFilePath = [m_files objectAtIndex:m_nextFileIndex];
        m_nextFileIndex++;
        NSString* filePath = [self getCurrentFilePath];
        NSImageRep* image = [NSImageRep imageRepWithContentsOfFile:filePath];
        
        if (image) {
            CGFloat scale;
            
            // Draw one image pixel per screen pixel (i.e., ignore source dots per inch).
            dst.origin.x = dst.origin.y = 0.0f;
            dst.size.width = [image pixelsWide];
            dst.size.height = [image pixelsHigh];
            
            // Compute size of screen in pixels.
            NSSize screenPixelSize = screenRect.size;
            CALayer* layer = [self layer]; // v10.5+
            if ([layer respondsToSelector:@selector(contentsScale)]) {
                // v10.7+. Could be a Retina screen.
                scale = [layer contentsScale];
                screenPixelSize.height *= scale;
                screenPixelSize.width *= scale;
            }
            
            // Scale image to (just) fit in screen.
            // First scale width to match.
            // Don't scale up by more than some fixed amount, like 1 or 2, because it will look pixelated and icky.
            scale = fminf(2.0f, screenPixelSize.width / dst.size.width);
            // NSLog(@"scaling width %@ w=%f h=%f sw=%f sh=%f scale=%f", file, dst.size.width, dst.size.height, screenRect.size.width, screenRect.size.height, scale);
            dst.size.width *= scale;
            dst.size.height *= scale;
            if (dst.size.height > screenPixelSize.height) {
                // scaled image is taller than screen... scale down to fit height
                scale = screenPixelSize.height / dst.size.height;
                // NSLog(@"scaling height %@ w=%f h=%f sw=%f sh=%f f=%f", file, dst.size.width, dst.size.height, screenRect.size.width, screenRect.size.height, f);
                dst.size.width *= scale;
                dst.size.height *= scale;
            }
            // Center it (no animation)
            // NSLog(@"drawing %@ w=%f h=%f sw=%f sh=%f", file, dst.size.width, dst.size.height, screenRect.size.width, screenRect.size.height);
            dst = SSCenteredRectInRect(dst, screenRect);
            
            // Draw the whole thing (no cropping)
            [image drawInRect:dst];
        } else {
            dst = screenRect;
            p.x = screenRect.origin.x + screenRect.size.width * 0.5f;
            p.y = screenRect.origin.y + screenRect.size.height * 0.5f;
            [@"Sorry, no picture!" drawAtPoint:p withAttributes:attributes];
        }
        static const CGFloat MARGIN = 10.0f;
        // Draw file name at bottom of screen, left aligned with image (so that it moves at least once in a while).
        p.x = dst.origin.x + MARGIN;
        p.y = screenRect.origin.y;
        s = [NSString stringWithFormat:@"%@", m_currentFilePath];
        [s drawAtPoint:p withAttributes:attributes];
        
        // Draw file count at top of screen, right aligned with image (so that it moves at least once in a while).
        // Use m_nextFileIndex, even though it was already incremented to the next number, because users expect counting to start at 1.
        // Macro clause is to hide annoying warning because NSUInteger can be long or int.
#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
        //typedef unsigned long NSUInteger;
        s = [NSString stringWithFormat:@"%i/%li", m_nextFileIndex, [m_files count]];
#else
        //typedef unsigned int NSUInteger;
        s = [NSString stringWithFormat:@"%i/%i", m_nextFileIndex, [m_files count]];
#endif
        size = [s sizeWithAttributes:attributes];
        p.x += dst.size.width - size.width - 2.0f * MARGIN;
        p.y += screenRect.size.height - size.height;
        [s drawAtPoint:p withAttributes:attributes];
    } else {
        // No files found... Move error message around to prevent burn in.
        s = [NSString stringWithFormat:@"Sorry, no pictures found in %@", m_path];
        size = [s sizeWithAttributes:attributes];
        p = SSRandomPointForSizeWithinRect(size, screenRect);
        [s drawAtPoint:p withAttributes:attributes];
    }
#if BUILD_NUMBER
	s = [NSString stringWithFormat:@"%i %i", BUILD_NUMBER, lastKeyCode];
    size = [s sizeWithAttributes:attributes];
	p.x = screenRect.origin.x + 1;
    p.y = screenRect.origin.y + screenRect.size.height - size.height;
	[s drawAtPoint:p withAttributes:attributes];
#endif
    // Help
//    if (m_lastHelpKeyPress) {
//        NSLog(@"help time=%f", [m_lastHelpKeyPress timeIntervalSinceNow]);
//    }
    if (m_lastHelpKeyPress && [m_lastHelpKeyPress timeIntervalSinceNow] > -HELP_HUD_INTERVAL) {
        static const NSString* HUD_HELP = @"PickShow Screen Saver\n\n"
            @"/, h - show this help screen\n"
            @"\u2192 (right arrow) - next picture\n"
            @"\u2190 (left arrow) - previous picture\n"
            @"f - show current picture in Finder\n"
            @"d, back, delete, \u232B - move current picture to Trash\n"
            @"anything else - exit screen saver";
        attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSColor whiteColor], NSForegroundColorAttributeName,
                          [NSFont fontWithName:@"Helvetica" size:1.25 * fontSize], NSFontAttributeName,
                          shadow, NSShadowAttributeName,
                          nil];
        size = [HUD_HELP sizeWithAttributes:attributes];
        p.x = screenRect.origin.x + 0.5 * (screenRect.size.width - size.width);
        p.y = screenRect.origin.y + 0.5 * (screenRect.size.height - size.height);
        [HUD_HELP drawAtPoint:p withAttributes:attributes];
    }
    // Make a time stamp when something is shown.
    if (m_lastFrameDate) {
        [m_lastFrameDate release];
    }
    m_lastFrameDate = [[NSDate alloc] init];
	
	// If out of files, get new set of files to show.
	if (m_nextFileIndex >= [m_files count]) {
		[self shuffle];
	}
    return;
}

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (NSWindow*)configureSheet
{
	if (!configSheet)
	{
        versionTextField = nil;
        pathTextField = nil;
        pathsToSkipView = nil;
        pathToSkipControl = nil;
        intervalTextField = nil;
        webPageTextField = nil;
		if ([NSBundle loadNibNamed:@"ConfigureSheet" owner:self])
        {
            // Initialize version display.
            NSString* version = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
            NSString* title = [NSString stringWithFormat:@"%@%@", self->versionTextField.stringValue, version];
            [self->versionTextField setStringValue:title];
            
            // Make "online" title into a hyperlink, per http://developer.apple.com/library/mac/#qa/qa1487/_index.html
            NSTextField* inTextField = self->webPageTextField;
            
            // both are needed, otherwise hyperlink won't accept mousedown
            [inTextField setAllowsEditingTextAttributes: YES];
            [inTextField setSelectable: YES];
            
            NSURL* url = [NSURL URLWithString:@"http://frombits.com/pickshow"];
            
            NSMutableAttributedString* string = [[NSMutableAttributedString alloc] init];
            [string appendAttributedString:[NSAttributedString hyperlinkFromString:[inTextField stringValue] withURL:url]];
            
            // set the attributed string to the NSTextField
            [inTextField setAttributedStringValue: string];
            
            [string release];
        } else {
			NSLog( @"PickShow failed to load configure sheet." );
			NSBeep();
		}
	}
	if (configSheet)
	{
		if (pathTextField) {
			[pathTextField setStringValue:m_path];
		}
		if (intervalTextField) {
			[intervalTextField setFloatValue:m_interval];
		}
	}
	return configSheet;
}

#pragma mark NSResponder

- (void)keyDown:(NSEvent *)theEvent
{
    NSString* s;
    NSURL* u;
	lastKeyCode = [theEvent keyCode];
    // NSLog(@"keycode=%i", lastKeyCode);
	switch (lastKeyCode) {
            //		case 1: // s - same/show more from same folder
            //		case 14: // e - edit
            //		case 35: // p - pause
            //            return;
        case 4: // h
		case 44: // '/' ('?' with shift) - help
            // Make a time stamp when help key is pressed.
            if (m_lastHelpKeyPress) {
                [m_lastHelpKeyPress release];
            }
            m_lastHelpKeyPress = [[NSDate alloc] init];
            // Redraw to show help immediately
			m_nextFileIndex -= 1;
			if (m_nextFileIndex < 0)
				m_nextFileIndex = 0;
            [self setAnimationTimeInterval:m_interval];
			return;
	    case 123: // left arrow... back to last image
			m_nextFileIndex -= 2;
			if (m_nextFileIndex < 0)
				m_nextFileIndex += [m_files count];
		case 124: // right arrow... next image
			// Setting interval triggers an immediate draw.
			[self setAnimationTimeInterval:m_interval];
			return;
		case 51: // "delete" on MacBook, "BACK" on Logitech keyboard
        case 117: // "DEL" key on Logitech keyboard
		case 2: // d
		{
            if ([m_lastFrameDate timeIntervalSinceNow] > -0.5) {
                // Photo has not been visible long enough for user to decide to delete.
                // The risk of it being a spurious keystroke from the previous photo is too high,
                // so do the safe thing and ignore it.
                return;
            }
            if (m_currentFilePath == nil) {
                // How did this happen?
                NSLog(@"PickShow hasn't shown anything yet, can't delete!");
                return;
            }
			NSArray* pathComps = [[self getCurrentFilePath] pathComponents];
			// It would be nice to confirm deleting file with a NSAlert, but they don't seem to show during screen saver.
            // NSLog(@"deleting %@", [pathComps componentsJoinedByString:@""]);
            // Move file to trash folder.
            NSRange path;
            path.location = 0;
            path.length = [pathComps count] - 1;
            NSRange file;
            file.location = path.length;
            file.length = 1;
            //NSLog(@"%@ %@ %@", [[self getCurrentFilePath] pathComponents], [[pathComps subarrayWithRange:path] componentsJoinedByString:@"/"], [[pathComps subarrayWithRange:file] objectAtIndex:0]);
            NSString* source = [[pathComps subarrayWithRange:path] componentsJoinedByString:@"/"];
            NSArray* arrayWithJustTheFile = [pathComps subarrayWithRange:file];
            [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                         source:source
                                                    destination:@""
                                                          files:arrayWithJustTheFile
                                                            tag:nil];
            // Update screen saver files list
            if (m_nextFileIndex > 0) {
                // Just rewind index to the one to delete. After it is removed (below), the next one will be shown.
                m_nextFileIndex--;
                [m_files removeObjectAtIndex:m_nextFileIndex];
            } else {
                // Should only be 0, not negative.
                // Just reshuffled... don't know index of current file any more, search for it.
                [m_files removeObject:m_currentFilePath];
            }
            
            // Draw new current image.
            [self setAnimationTimeInterval:m_interval];
		}
			return;
		case 3: // f - filter folder
			if ([NSWorkspace instancesRespondToSelector:@selector(activateFileViewerSelectingURLs:)]) {
                s = [NSString stringWithFormat:@"file://%@", [self getCurrentFilePath]];
                // NSLog(@"s=%@", s);
                u = [NSURL fileURLWithPath:s];
				[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:
                 [NSArray arrayWithObject: u]];
			}
			else
            {
				// else... pre-10.6
                s = [self getCurrentFilePath];
                // NSLog(@"s=%@ path=%@", s, m_path);
				[[NSWorkspace sharedWorkspace] selectFile:s inFileViewerRootedAtPath:m_path];
			}
		default:
			break;
	}
	[super keyDown:theEvent];
}

#pragma mark Config Sheet IBActions

- (IBAction)cancelClick:(id)sender
{
	[[NSApplication sharedApplication] endSheet:configSheet];
}

- (IBAction)okClick:(id)sender
{
	m_path = [pathTextField stringValue];
	m_interval = [intervalTextField floatValue];
	if (m_interval < MIN_ANIMATION_INTERVAL) {
		m_interval = ANIMATION_INTERVAL;
	}
	NSUserDefaults* ud = [ScreenSaverDefaults defaultsForModuleWithName:@"PickShowScreenSaver"];
	if (ud)
	{
		[ud setObject:m_path forKey:@"path"];
		[ud setFloat:m_interval forKey:@"interval"];
		[ud setObject:m_pathsToSkip forKey:@"pathsToSkip"];
        //BOOL result =
        [ud synchronize];
        //NSLog(@"Synchronize ScreenSaverDefaults = %i", result);
	}
	[[NSApplication sharedApplication] endSheet:configSheet];
	// TODO: only listFiles if m_pathsToSkip changed
	[self listFiles];
}

- (IBAction)helpClick:(id)sender
{
    //    [[NSApplication sharedApplication] showHelp:self];
    if ([NSBundle instancesRespondToSelector:@selector(URLForResource:withExtension:)]) {
        // v10.6+
        NSURL* url = [[NSBundle bundleForClass:[self class]] URLForResource:@"help" withExtension:@"htm"];
        [[NSWorkspace sharedWorkspace] openURL:url];
    } else {
        NSString* resourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
        NSString* path = [NSString stringWithFormat:@"%@/English.lproj/help.htm", resourcePath];
        [[NSWorkspace sharedWorkspace] openFile:path];
    }
}

- (IBAction)choosePathClick:(id)sender
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setAllowsMultipleSelection:NO];
	if ([panel runModal] == NSFileHandlingPanelOKButton)
	{
        NSURL* url = [[panel URLs] objectAtIndex:0];
		[pathTextField setStringValue:[url path]];
	}
}

- (IBAction)tableViewSelected:(id)sender
{
    NSInteger row = [sender selectedRow];
	[pathToSkipControl setEnabled:(row >= 0) forSegment:1];
}

- (IBAction)changePathToSkip:(id)sender
{
	NSOpenPanel* panel;
	NSInteger row;
	switch ([pathToSkipControl selectedSegment] ) {
		case 0:
			panel = [NSOpenPanel openPanel];
			[panel setCanChooseFiles:YES];
			[panel setCanChooseDirectories:YES];
			[panel setAllowsMultipleSelection:YES];
			if ([panel runModal] == NSFileHandlingPanelOKButton)
			{
                // Convert URLs to Strings. TODO: easier to just use URLs for m_pathsToSkip?
				NSArray* chosenURLs = [panel URLs];
                NSMutableArray* chosen = [[NSMutableArray alloc] init];
                for (NSURL* url in chosenURLs) {
                    [chosen addObject:[url path]];
                }
                // Update m_pathsToSkip.
				[m_pathsToSkip removeObjectsInArray:chosen];
				[m_pathsToSkip addObjectsFromArray:chosen];
				[m_pathsToSkip sortUsingSelector:@selector(compare:)];
				[pathsToSkipView reloadData];
                [chosen release];
			}
			// Add a path
			break;
		case 1:
			// Remove selected path
			row = [pathsToSkipView selectedRow];
			if (row >= 0) {
				[m_pathsToSkip removeObjectAtIndex:row];
				[pathsToSkipView reloadData];
			}
			break;
	}
}

#pragma mark Config Sheet NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [m_pathsToSkip count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return [m_pathsToSkip objectAtIndex:rowIndex];
}

@end
