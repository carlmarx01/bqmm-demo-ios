//
//  MMLabel.m
//  StampMeSDK
//
//  Created by ceo on 11/9/15.
//  Copyright © 2015 siyanhui. All rights reserved.
//

#import "MMTextView.h"
#import <CoreText/CoreText.h>
#import <BQMM/BQMM.h>
#import "MMTextParser+ExtData.h"
#import "MMTextAttachment.h"

@interface MMDataDetector : NSDataDetector

@end

@implementation MMDataDetector

- (NSRegularExpressionOptions)options {
    NSRegularExpressionOptions options = [super options];
    options = options | NSRegularExpressionUseUnicodeWordBoundaries;
    return options;
}

@end

@interface MMTextView () {
    NSArray *_urlMatches;
    UITapGestureRecognizer *tapGestureRecognizer;
}

@property (nonatomic, strong) NSMutableArray *attachmentRanges;
@property (nonatomic, strong) NSMutableArray *attachments;
@property (nonatomic, strong) NSMutableArray *imageViews;

@end

@implementation MMTextView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _disableActionMenu = NO;
    }
    return self;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (self.disableActionMenu) {
        return NO;
    }
    [[UIMenuController sharedMenuController] setMenuItems:nil];
    return [super canPerformAction:action withSender:sender];
}

#pragma mark - setter/getter

- (void)setMmFont:(UIFont *)mmFont {
    _mmFont = mmFont;
    [self setFont:mmFont];
}

- (void)setMmTextColor:(UIColor *)mmTextColor {
    _mmTextColor = mmTextColor;
    [self setTextColor:mmTextColor];
}

- (void)setMmText:(NSString *)mmText {
    [self clearImageViewsCover];
    [super setMmText:mmText];
}

- (void)setPlaceholderTextWithData:(NSArray*)extData {
    NSMutableAttributedString *mAStr = [[NSMutableAttributedString alloc] init];
    for (NSArray *obj in extData) {
        NSString *str = obj[0];
        EmojiType type = [obj[1] intValue];
        switch (type) {
            case EmojiTypeInvalid:
            {
                [mAStr appendAttributedString:[[NSAttributedString alloc] initWithString:str]];
            }
                break;
                
            case EmojiTypeSmall:
            {
                NSTextAttachment *placeholderAttachment = [[NSTextAttachment alloc] init];
                placeholderAttachment.bounds = CGRectMake(0, 0, 20, 20);//固定20X20
                [mAStr appendAttributedString:[NSAttributedString attributedStringWithAttachment:placeholderAttachment]];
            }
                break;
                
            case EmojiTypeBig:
            {
                NSTextAttachment *placeholderAttachment = [[NSTextAttachment alloc] init];
                placeholderAttachment.bounds = CGRectMake(0, 0, 60, 60);//固定60X60
                [mAStr appendAttributedString:[NSAttributedString attributedStringWithAttachment:placeholderAttachment]];
            }
                break;
                
            default:
                break;
        }
    }
    if (self.mmFont) {
        [mAStr addAttribute:NSFontAttributeName value:self.mmFont range:NSMakeRange(0, mAStr.length)];
    }
    if (self.mmTextColor) {
        [mAStr addAttribute:NSForegroundColorAttributeName value:self.mmTextColor range:NSMakeRange(0, mAStr.length)];
    }
    self.attributedText = mAStr;
}

- (void)setMmTextData:(NSArray *)extData {
    [self setMmTextData:extData completionHandler:nil];
}

- (void)setMmTextData:(NSArray*)extData completionHandler:(void(^)(void))completionHandler {
    [self setPlaceholderTextWithData:extData];
    [self updateAttributeTextWithData:extData completionHandler:completionHandler];
    
    [self clearImageViewsCover];
    [self.attributedText enumerateAttribute:NSAttachmentAttributeName
                                    inRange:NSMakeRange(0, [self.attributedText length])
                                    options:0
                                 usingBlock:^(id value, NSRange range, BOOL * stop) {
                                     if ([value isKindOfClass:[MMTextAttachment class]]) {
                                         MMTextAttachment *attachment = (MMTextAttachment *)value;
                                         [self.attachmentRanges addObject:[NSValue valueWithRange:range]];
                                         [self.attachments addObject:value];
                                         UIImageView *imgView = [[UIImageView alloc] initWithImage:attachment.emoji.emojiImage];
                                         attachment.image = nil;
                                         [self.imageViews addObject:imgView];
                                     }
                                 }];
}


/****************************MMTextView处理URL相关事件*******************************/
- (void)setURLAttributes {
    //检测设置URL相关的attribute
    NSError *error = nil;
    MMDataDetector *dataDetector = [[MMDataDetector alloc] initWithTypes:NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber error:&error];
    _urlMatches = [dataDetector matchesInString:self.attributedText.string options:0 range:NSMakeRange(0, self.attributedText.string.length)];
    
    NSMutableAttributedString * attributedString = [self.attributedText mutableCopy];
    NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:0];
    [attributedString addAttribute:NSParagraphStyleAttributeName
                             value:paragraphStyle
                             range:NSMakeRange(0, self.attributedText.string.length)];
    [self setAttributedText:attributedString];
    
    [self highlightLinksWithIndex:NSNotFound];
    //添加点击手势
    self.userInteractionEnabled = true;
    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [tapGestureRecognizer setDelegate:self];
    [self addGestureRecognizer:tapGestureRecognizer];
}

- (void)highlightLinksWithIndex:(CFIndex)index {
    
    NSMutableAttributedString* attributedString = [self.attributedText mutableCopy];
    //重置颜色
    [attributedString addAttribute:NSForegroundColorAttributeName value:self.textColor range:NSMakeRange(0, attributedString.string.length)];
    for (NSTextCheckingResult *match in _urlMatches) {
        
        if ([match resultType] == NSTextCheckingTypeLink || [match resultType] == NSTextCheckingTypePhoneNumber) {
            
            NSRange matchRange = [match range];
            
            if ([self isIndex:index inRange:matchRange]) {
                [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:matchRange];
            }
            else {
                [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:matchRange];
            }
            
            [attributedString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:matchRange];
        }
    }
    
    self.attributedText = attributedString;
}

- (BOOL)isIndex:(CFIndex)index inRange:(NSRange)range
{
    return index > range.location && index < range.location+range.length;
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer state] != UIGestureRecognizerStateEnded) {
        return;
    }
    NSTextCheckingResult *result = [self linkAtPoint:[gestureRecognizer locationInView:self]];
    if (!result) {
        if (self.delegate!=nil) {
            if ([self.clickActionDelegate respondsToSelector:@selector(mmTextView:didTapTextView:)]) {
                [self.clickActionDelegate mmTextView:self didTapTextView:self.text];
            }
        }
        return;
    }
    
    switch (result.resultType) {
        case NSTextCheckingTypeLink:
            NSLog(@"link");
            if ([self.clickActionDelegate respondsToSelector:@selector(mmTextView:didSelectLinkWithURL:)]) {
                [self.clickActionDelegate mmTextView:self didSelectLinkWithURL:result.URL];
            }
            break;
        case NSTextCheckingTypePhoneNumber:
            if ([self.clickActionDelegate respondsToSelector:@selector(mmTextView:didSelectLinkWithPhoneNumber:)]) {
                [self.clickActionDelegate mmTextView:self didSelectLinkWithPhoneNumber:result.phoneNumber];
            }
            NSLog(@"tele");
            break;
        default:
            break;
    }
}

- (NSTextCheckingResult *)linkAtPoint:(CGPoint)p {
    CFIndex idx = [self characterIndexAtPoint:p];
    return [self linkAtCharacterIndex:idx];
}

- (NSTextCheckingResult *)linkAtCharacterIndex:(CFIndex)idx {
    for (NSTextCheckingResult *result in _urlMatches) {
        NSRange range = result.range;
        if ((CFIndex)range.location <= idx && idx <= (CFIndex)(range.location + range.length - 1)) {
            return result;
        }
    }
    
    return nil;
}

- (CFIndex)characterIndexAtPoint:(CGPoint)point {
    
    NSMutableAttributedString *optimizedAttributedText = [self.attributedText mutableCopy];
    
    // use label's font and lineBreakMode properties in case the attributedText does not contain such attributes
    [self.attributedText
     enumerateAttributesInRange:NSMakeRange(0, [self.attributedText length])
     options:0
     usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
         
         if (!attrs[(NSString *)kCTFontAttributeName]) {
             
             [optimizedAttributedText addAttribute:(NSString *)kCTFontAttributeName
                                             value:self.font
                                             range:NSMakeRange(0, [self.attributedText length])];
         }
     }];
    
    // modify kCTLineBreakByTruncatingTail lineBreakMode to kCTLineBreakByWordWrapping
    [optimizedAttributedText
     enumerateAttribute:(NSString *)kCTParagraphStyleAttributeName
     inRange:NSMakeRange(0, [optimizedAttributedText length])
     options:0
     usingBlock:^(id value, NSRange range, BOOL *stop) {
         
         NSMutableParagraphStyle *paragraphStyle = [value mutableCopy];
         
         if ([paragraphStyle lineBreakMode] == kCTLineBreakByTruncatingTail) {
             [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
         }
         
         [optimizedAttributedText removeAttribute:(NSString *)kCTParagraphStyleAttributeName range:range];
         [optimizedAttributedText addAttribute:(NSString *)kCTParagraphStyleAttributeName
                                         value:paragraphStyle
                                         range:range];
     }];
    
    ////////
    
    if (!CGRectContainsPoint(self.bounds, point)) {
        return NSNotFound;
    }
    
    CGRect textRect = [self frame];
    
    if (!CGRectContainsPoint(textRect, point)) {
        return NSNotFound;
    }
    
    // Offset tap coordinates by textRect origin to make them relative to the origin of frame
    point = CGPointMake(point.x - textRect.origin.x, point.y - textRect.origin.y);
    // Convert tap coordinates (start at top left) to CT coordinates (start at bottom left)
    point = CGPointMake(point.x, textRect.size.height - point.y);
    
    //////
    
    CTFramesetterRef framesetter =
    CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)optimizedAttributedText);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, textRect);
    
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, [self.attributedText length]), path, NULL);
    
    if (frame == NULL) {
        CFRelease(path);
        return NSNotFound;
    }
    
    CFArrayRef lines = CTFrameGetLines(frame);
    
    NSInteger numberOfLines = CFArrayGetCount(lines);
    
    // DebugLog(@"num lines: %d", numberOfLines);
    
    if (numberOfLines == 0) {
        CFRelease(frame);
        CFRelease(path);
        return NSNotFound;
    }
    
    NSUInteger idx = NSNotFound;
    
    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, numberOfLines), lineOrigins);
    
    for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
        
        CGPoint lineOrigin = lineOrigins[lineIndex];
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);
        
        // Get bounding information of line
        CGFloat ascent, descent, leading, width;
        width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        CGFloat yMin = floor(lineOrigin.y - descent);
        CGFloat yMax = ceil(lineOrigin.y + ascent);
        
        // Check if we've already passed the line
        if (point.y > yMax) {
            break;
        }
        
        // Check if the point is within this line vertically
        if (point.y >= yMin) {
            
            // Check if the point is within this line horizontally
            if (point.x >= lineOrigin.x && point.x <= lineOrigin.x + width) {
                
                // Convert CT coordinates to line-relative coordinates
                CGPoint relativePoint = CGPointMake(point.x - lineOrigin.x, point.y - lineOrigin.y);
                idx = CTLineGetStringIndexForPosition(line, relativePoint);
                
                break;
            }
        }
    }
    
    CFRelease(frame);
    CFRelease(path);
    
    return idx;
}
/****************************MMTextView处理URL相关事件*******************************/

- (void)updateAttributeTextWithData:(NSArray*)extData completionHandler:(void(^)(void))completionHandler {
    NSMutableArray *codes = [NSMutableArray array];
    __block NSMutableArray *textImgArray = [NSMutableArray array];
    for (NSArray *obj in extData) {
        NSString *str = obj[0];
        BOOL isEmoji = [obj[1] integerValue] == 0 ? NO : YES;
        if (isEmoji) {
            if (![codes containsObject:str]) {
                [codes addObject:str];
            }
        }
        [textImgArray addObject:str];
    }
    
    //
    [[MMEmotionCentre defaultCentre] fetchEmojisByType:MMFetchTypeAll codes:codes completionHandler:^(NSArray *emojis) {
        NSMutableAttributedString *mAStr = [[NSMutableAttributedString alloc] init];
        for (MMEmoji *emoji in emojis) {
            NSInteger objIndex = [textImgArray indexOfObject:emoji.emojiCode];
            while (objIndex != NSNotFound) {
                [textImgArray replaceObjectAtIndex:objIndex withObject:emoji];
                objIndex = [textImgArray indexOfObject:emoji.emojiCode];
            }
        }
        for (id obj in textImgArray) {
            if ([obj isKindOfClass:[MMEmoji class]]) {
                MMTextAttachment *attachment = [[MMTextAttachment alloc] init];
                attachment.emoji = obj;
                if ([attachment.image.images count] > 1) {
                    attachment.image = [attachment placeHolderImage];
                }
                [mAStr appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
            } else {
                [mAStr appendAttributedString:[[NSAttributedString alloc] initWithString:obj]];
            }
        }
        if (self.mmFont) {
            [mAStr addAttribute:NSFontAttributeName value:self.mmFont range:NSMakeRange(0, mAStr.length)];
        }
        if (self.mmTextColor) {
            [mAStr addAttribute:NSForegroundColorAttributeName value:self.mmTextColor range:NSMakeRange(0, mAStr.length)];
        }
        self.attributedText = mAStr;
        if (completionHandler) {
            completionHandler();
        }
    }];
}

- (NSMutableArray *)attachments {
    if (_attachments == nil) {
        _attachments = [[NSMutableArray alloc] init];
    }
    return _attachments;
}

- (NSMutableArray *)attachmentRanges {
    if (_attachmentRanges == nil) {
        _attachmentRanges = [[NSMutableArray alloc] init];
    }
    return _attachmentRanges;
}

- (NSMutableArray *)imageViews {
    if (_imageViews == nil) {
        _imageViews = [[NSMutableArray alloc] init];
    }
    return _imageViews;
}

#pragma mark - private

- (void)clearImageViewsCover {
    [self.attachmentRanges removeAllObjects];
    [self.attachments removeAllObjects];
    
    for (UIImageView *imgView in self.imageViews) {
        [imgView removeFromSuperview];
    }
    [self.imageViews removeAllObjects];
}


#pragma mark - Layout

- (void)layoutAttachments {
    NSInteger attachmentCount = [self.attachments count];
    for (NSInteger i = 0; i < attachmentCount; i++) {
        NSRange range = [self.attachmentRanges[i] rangeValue];
        MMTextAttachment *attachment = self.attachments[i];
        UIImageView *imgView = self.imageViews[i];
        
        NSRange glyphRange = [self.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:nil];
        CGRect rect = [self.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textContainer];
        rect.origin.x += self.textContainerInset.left;
        rect.origin.y += self.textContainerInset.top;
        
        CGFloat originalY = CGRectGetMaxY(rect) - attachment.bounds.size.height;
        if(attachment.bounds.size.width == 20) {
            CGFloat lineHeight = self.mmFont.lineHeight;
            originalY = CGRectGetMaxY(rect) - lineHeight / 2 - attachment.bounds.size.height / 2;
        }
        imgView.frame = CGRectMake(rect.origin.x, originalY, attachment.bounds.size.width, attachment.bounds.size.height);
        if ([imgView superview] == nil) {
            [self addSubview:imgView];
        }
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layoutAttachments];
}

- (void)copy:(id)sender {
    [UIPasteboard generalPasteboard].string = [self mmTextWithRange:self.selectedRange];
}


@end