//
//  NSAttributedString+Hyperlink.h
//  PickShowScreenSaver
//  From http://developer.apple.com/library/mac/#qa/qa1487/_index.html
//  Created by Peter Mikelsons on 9/19/12.
//
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (Hyperlink)

    +(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL;

@end
