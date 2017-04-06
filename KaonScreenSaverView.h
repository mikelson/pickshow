//
//  KaonScreenSaverView.h
//  KaonScreenSaver
//
//  Created by Peter on 11/8/10.
//  Copyright © 2017 Peter Mikelsons. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>


@interface KaonScreenSaverView : ScreenSaverView <NSTableViewDataSource>
{
	NSString* m_path;
	NSMutableArray* m_pathsToSkip;
	NSMutableArray* m_files;
    NSString* m_currentFilePath;
	int m_nextFileIndex;
    
    NSDate* m_lastFrameDate;
    NSDate* m_lastHelpKeyPress;

	unsigned short lastKeyCode;
	
	IBOutlet id configSheet;
    IBOutlet NSTextField *versionTextField;
	IBOutlet NSTextField* pathTextField;
	IBOutlet NSTableView* pathsToSkipView;
	IBOutlet NSSegmentedControl* pathToSkipControl;
	IBOutlet NSTextField* intervalTextField;
    IBOutlet NSTextField *webPageTextField;

@private
	float m_interval;
}

- (IBAction)cancelClick:(id)sender;
- (IBAction)okClick:(id)sender;
- (IBAction)helpClick:(id)sender;
- (IBAction)choosePathClick:(id)sender;
- (IBAction)changePathToSkip:(id)sender;
- (IBAction)tableViewSelected:(id)sender;

@end
