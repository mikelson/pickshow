//
//  NSAttributedString+Hyperlink.m
//  PickShowScreenSaver
//
//  From http://developer.apple.com/library/mac/#qa/qa1487/_index.html
//  Created by Peter Mikelsons on 9/19/12.
//
//

#import "NSAttributedString+Hyperlink.h"

@implementation NSAttributedString (Hyperlink)

+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL

{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];

    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    
    // next make the text appear with an underline
    [attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];
    
    // prevent changing font on first click, http://stackoverflow.com/questions/7058699/nstextfield-with-url-style-format
    [attrString addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:13.0] range:range];
    
    [attrString endEditing];
    
    return [attrString autorelease];
}

@end
