//
//  KxMenu.m
//  kxmenu project
//  https://github.com/kolyvan/kxmenu/
//
//  Created by Kolyvan on 17.05.13.
//

/*
 Copyright (c) 2013 Konstantin Bukreev. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 - Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
 Some ideas was taken from QBPopupMenu project by Katsuma Tanaka.
 https://github.com/questbeat/QBPopupMenu
*/

#import "KxMenu.h"
#import <QuartzCore/QuartzCore.h>
#import "UIHacks.h"
@import CoreGraphics;

const CGFloat kArrowSize = 12.f;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

@interface KxMenuView : UIView
-(void) dismissMenu:(BOOL) animated;
@property (nonatomic, assign) NSInteger selectedItem;
@property (nonatomic, strong) UIView  * contentView;

@end

@interface KxMenuOverlay : UIView
@end

@implementation KxMenuOverlay

// - (void) dealloc { NSLog(@"dealloc %@", self); }

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;

        UITapGestureRecognizer *gestureRecognizer;
        gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                    action:@selector(singleTap:)];
        [self addGestureRecognizer:gestureRecognizer];
    }
    return self;
}

// thank horaceho https://github.com/horaceho
// for his solution described in https://github.com/kolyvan/kxmenu/issues/9

- (void)singleTap:(UITapGestureRecognizer *)recognizer
{
    for (KxMenuView *v in self.subviews) {
        if ([v isKindOfClass:[KxMenuView class]] && [v respondsToSelector:@selector(dismissMenu:)]) {
            [v dismissMenu:YES];
        }
    }
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

@implementation KxMenuItem

+ (instancetype) menuItem:(NSString *) title
                    image:(UIImage *) image
                   target:(id)target
                   action:(SEL) action
{
    return [[KxMenuItem alloc] init:title
                              image:image
                             target:target
                             action:action
                                tag:0
                             subTag:0];
}

+ (instancetype) menuItem:(NSString *) title
                    image:(UIImage *) image
                   target:(id)target
                   action:(SEL) action
                      tag:(NSInteger) tag
{
  return [[KxMenuItem alloc] init:title
                            image:image
                           target:target
                           action:action
                              tag:tag
                           subTag:0];
}

+ (instancetype) menuItem:(NSString *) title
                    image:(UIImage *) image
                   target:(id)target
                   action:(SEL) action
                      tag:(NSInteger) tag
                   subTag:(NSInteger) subTag
{
  return [[KxMenuItem alloc] init:title
                            image:image
                           target:target
                           action:action
                              tag:tag
                           subTag:subTag];
}

- (id) init:(NSString *) title
      image:(UIImage *) image
     target:(id)target
     action:(SEL) action
        tag:(NSInteger) tag
     subTag:(NSInteger) subTag
{
    NSParameterAssert(title.length || image);

    self = [super init];
    if (self) {

        _title = title;
        _image = image;
        _target = target;
        _action = action;
        _tag = tag;
        _subTag = subTag;
    }
    return self;
}

- (BOOL) enabled
{
    return _target != nil && _action != NULL;
}

- (void) performAction
{
    __strong id target = self.target;

    if (target && [target respondsToSelector:_action]) {

        [target performSelectorOnMainThread:_action withObject:self waitUntilDone:YES];
    }
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@ #%p %@>", [self class], self, _title];
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

typedef enum {

    KxMenuViewArrowDirectionNone,
    KxMenuViewArrowDirectionUp,
    KxMenuViewArrowDirectionDown,
    KxMenuViewArrowDirectionLeft,
    KxMenuViewArrowDirectionRight,

} KxMenuViewArrowDirection;

@implementation KxMenuView {

    KxMenuViewArrowDirection    _arrowDirection;
    CGFloat                     _arrowPosition;
    NSArray                     *_menuItems;
    KxDismissBlock              _dismissBlock;
    BOOL _dismissRequested;
    UIView *_dimView;
}

- (id)init
{
    self = [super initWithFrame:CGRectZero];
    if(self) {

        self.backgroundColor = [UIColor clearColor];
        self.opaque = YES;
        self.alpha = 0;

        if ([KxMenu shadowed])
        {
            self.layer.shadowOpacity=0.7;
            self.layer.shadowRadius=100;
        }
    }

    return self;
}

// - (void) dealloc { NSLog(@"dealloc %@", self); }

- (void) setupFrameInView:(UIView *)view
                 fromRect:(CGRect)fromRect
{
    const CGSize contentSize = _contentView.frame.size;

    const CGFloat outerWidth = view.bounds.size.width;
    const CGFloat outerHeight = view.bounds.size.height;

    const CGFloat rectX0 = fromRect.origin.x;
    const CGFloat rectX1 = fromRect.origin.x + fromRect.size.width;
    const CGFloat rectXM = fromRect.origin.x + fromRect.size.width * 0.5f;
    const CGFloat rectY0 = fromRect.origin.y;
    const CGFloat rectY1 = fromRect.origin.y + fromRect.size.height;
    const CGFloat rectYM = fromRect.origin.y + fromRect.size.height * 0.5f;;

    const CGFloat arrowSize = [KxMenu displayArrow] ? kArrowSize : 0;
    const CGFloat widthPlusArrow = contentSize.width + arrowSize;
    const CGFloat heightPlusArrow = contentSize.height + arrowSize;
    //const CGFloat widthHalf = contentSize.width * 0.5f;
    const CGFloat heightHalf = contentSize.height * 0.5f;

    const CGFloat kMargin = 5.f;

    if (heightPlusArrow < (outerHeight - rectY1)) {

        _arrowDirection = KxMenuViewArrowDirectionUp;
        CGPoint point = (CGPoint){
            rectX0,
            rectY1
        };

        if (point.x < kMargin)
            point.x = kMargin;

        if ((point.x + contentSize.width + kMargin) > outerWidth)
            point.x = outerWidth - contentSize.width - kMargin;

        _arrowPosition = rectXM - point.x;
        //_arrowPosition = MAX(16, MIN(_arrowPosition, contentSize.width - 16));
        _contentView.frame = (CGRect){0, arrowSize, contentSize};

        self.frame = (CGRect) {

            point,
            contentSize.width,
            contentSize.height + arrowSize
        };

    } else if (heightPlusArrow < rectY0) {

        _arrowDirection = KxMenuViewArrowDirectionDown;
        CGPoint point = (CGPoint){
            rectX0,
            rectY0 - heightPlusArrow
        };

        if (point.x < kMargin)
            point.x = kMargin;

        if ((point.x + contentSize.width + kMargin) > outerWidth)
            point.x = outerWidth - contentSize.width - kMargin;

        _arrowPosition = rectXM - point.x;
        _contentView.frame = (CGRect){CGPointZero, contentSize};

        self.frame = (CGRect) {

            point,
            contentSize.width,
            contentSize.height + arrowSize
        };

    } else if (widthPlusArrow < (outerWidth - rectX1)) {

        _arrowDirection = KxMenuViewArrowDirectionLeft;
        CGPoint point = (CGPoint){
            rectX1,
            rectYM - heightHalf
        };

        if (point.y < kMargin)
            point.y = kMargin;

        if ((point.y + contentSize.height + kMargin) > outerHeight)
            point.y = outerHeight - contentSize.height - kMargin;

        _arrowPosition = rectYM - point.y;
        _contentView.frame = (CGRect){arrowSize, 0, contentSize};

        self.frame = (CGRect) {

            point,
            contentSize.width + arrowSize,
            contentSize.height
        };

    } else if (widthPlusArrow < rectX0) {

        _arrowDirection = KxMenuViewArrowDirectionRight;
        CGPoint point = (CGPoint){
            rectX0 - widthPlusArrow,
            rectYM - heightHalf
        };

        if (point.y < kMargin)
            point.y = kMargin;

        if ((point.y + contentSize.height + 5) > outerHeight)
            point.y = outerHeight - contentSize.height - kMargin;

        _arrowPosition = rectYM - point.y;
        _contentView.frame = (CGRect){CGPointZero, contentSize};

        self.frame = (CGRect) {

            point,
            contentSize.width  + arrowSize,
            contentSize.height
        };

    } else {

        _arrowDirection = KxMenuViewArrowDirectionNone;

        self.frame = (CGRect) {

            (outerWidth - contentSize.width)   * 0.5f,
            (outerHeight - contentSize.height) * 0.5f,
            contentSize,
        };
    }
}

- (void)showMenuInView:(UIView *)view
              fromRect:(CGRect)rect
             menuItems:(NSArray *)menuItems
              onDismiss:(void (^)(void))dismissBlock
{
  _menuItems = menuItems;
  _dismissBlock = dismissBlock;
  _contentView = [self mkContentView];
  [self addSubview:_contentView];

  [self setupFrameInView:view fromRect:rect];
  
  //show hide dimmed background view
  if(_dimView){
    [_dimView setHidden:NO];
  } else {
    _dimView = [[UIView alloc] initWithFrame:view.window.frame];
    _dimView.backgroundColor = [UIColor blackColor];
    _dimView.alpha = 0.0f;
    _dimView.userInteractionEnabled = NO;
    [view addSubview:_dimView];
  }
  
  [UIView animateWithDuration:0.1
                   animations:^(void) {
                     self->_dimView.alpha = 0.66;
                   } completion:^(BOOL completed) {
                   }];
  

  KxMenuOverlay *overlay = [[KxMenuOverlay alloc] initWithFrame:view.bounds];
  [overlay addSubview:self];
  [view addSubview:overlay];

  _contentView.hidden = YES;
  const CGRect toFrame = self.frame;
  self.frame = (CGRect){self.arrowPoint, 1, 1};
  [self becomeFirstResponder ];
  [UIView animateWithDuration:0.1
                     animations:^(void) {
                         self.alpha = 1.0f;
                         self.frame = toFrame;
                     } completion:^(BOOL completed) {
                         self->_contentView.hidden = NO;
  }];

}

- (void)dismissMenu:(BOOL) animated
{
  
  
  [UIView animateWithDuration:0.1
                   animations:^(void) {
                     self->_dimView.alpha = 0.0;
                   } completion:^(BOOL completed) {
                     [self->_dimView setHidden:YES];
                   }];
  
  
  _dismissRequested = YES;
    if (self.superview) {

        if (animated) {

            _contentView.hidden = YES;
            const CGRect toFrame = (CGRect){self.arrowPoint, 1, 1};

            [UIView animateWithDuration:0.1
                             animations:^(void) {

                                 self.alpha = 0;
                                 self.frame = toFrame;

                             } completion:^(BOOL finished) {

                                 if ([self.superview isKindOfClass:[KxMenuOverlay class]])
                                     [self.superview removeFromSuperview];
                                 [self removeFromSuperview];
                               
                             }];

        } else {

            if ([self.superview isKindOfClass:[KxMenuOverlay class]])
                [self.superview removeFromSuperview];
            [self removeFromSuperview];
        }
    }
    _selectedItem = -1;
    [self resignFirstResponder];
    if (_dismissBlock)
      _dismissBlock();
}

- (BOOL) canBecomeFirstResponder { return YES;}

- (NSArray <UIKeyCommand *> *) keyCommands {
    NSMutableArray <UIKeyCommand *> * commands = [NSMutableArray new];
    
    [commands addObject: [UIHacks parseCommand:@"prev_item_up"      forAction: @selector(moveUp:)]];
    [commands addObject: [UIHacks parseCommand:@"next_item_down"    forAction:  @selector(moveDown:)]];
    [commands addObject: [UIHacks parseCommand: @"cancel_cmd"  forAction:  @selector(dismissMenu)]];

    [commands addObject: [UIHacks parseCommand: @"select_cmd"  forAction:  @selector(select:)]];

    return [commands copy];
}

- (void) moveUp:(id) sender
{
    NSInteger nextItem = self.selectedItem -1;
    if (nextItem < 0) {
      self.selectedItem = _menuItems.count - 1;
    } else {
      self.selectedItem = nextItem;
    }
}

- (void) moveDown:(id) sender
{
    NSInteger nextItem = self.selectedItem + 1;
    if (nextItem >= _menuItems.count) {
      self.selectedItem = 0; //wrap around
    } else {
      self.selectedItem = nextItem;
    }
}

- (void) select:(id) sender
{
    UIButton * button = [self buttonAtIndex:_selectedItem];
    if (button) [self performAction:button];
}

- (void) setSelectedItem:(NSInteger)selectedItem {
    selectedItem = MIN(selectedItem, _menuItems.count-1);
    if (selectedItem == _selectedItem) return;
    UIButton * oldButton = [self buttonAtIndex:_selectedItem];
    [oldButton setHighlighted:NO];
    
    if (selectedItem < 0) return;
    UIButton * newButton = [self buttonAtIndex:selectedItem];
    [newButton setHighlighted:YES];
    _selectedItem = selectedItem;
}

- (void)performAction:(UIButton *) button
{
  if (_dismissRequested)
    return;

    [self dismissMenu:YES];
  
    KxMenuItem *menuItem = _menuItems[button.tag];
    [menuItem performAction];
}

-(UIButton *) buttonAtIndex: (NSInteger) index {
    if (index < 0 || index >= _contentView.subviews.count) return nil;
    UIView * itemView = _contentView.subviews[index];
    if (itemView.subviews.count == 0) return nil;
    UIButton * button = (UIButton *) itemView.subviews[0];
    NSAssert(button.tag == index, @"Invalid index for menu");
    return button;
}

- (UIView *) mkContentView
{
    for (UIView *v in self.subviews) {
        [v removeFromSuperview];
    }

    if (!_menuItems.count)
        return nil;

    const CGFloat kMinMenuItemHeight = 32.f;
    const CGFloat kMinMenuItemWidth = 32.f;
    const CGFloat kLineMarginX = [KxMenu lineMargin];
    const CGFloat kMarginX = [KxMenu menuMargin].width;
    const CGFloat kMarginY = [KxMenu menuMargin].height;

    UIFont *titleFont = [KxMenu titleFont];
    if (!titleFont) titleFont = [UIFont boldSystemFontOfSize:16];

    CGFloat maxImageWidth = 0;
    CGFloat maxItemHeight = 0;
    CGFloat maxItemWidth = 0;

    for (KxMenuItem *menuItem in _menuItems) {

        const CGSize imageSize = menuItem.image.size;
        if (imageSize.width > maxImageWidth)
            maxImageWidth = imageSize.width;
    }
    const CGFloat imageMargin = (maxImageWidth) ? kMarginX : 0;

    for (KxMenuItem *menuItem in _menuItems) {

        const CGSize titleSize = [menuItem.title sizeWithAttributes:@{NSFontAttributeName: titleFont}];
        const CGSize imageSize = menuItem.image.size;

        const CGFloat itemHeight = MAX(titleSize.height, imageSize.height) + kMarginY * 2;
        const CGFloat itemWidth = ((!menuItem.enabled && !menuItem.image) ? titleSize.width : maxImageWidth + imageMargin + titleSize.width) + kMarginX * 4;

        if (itemHeight > maxItemHeight)
            maxItemHeight = itemHeight;

        if (itemWidth > maxItemWidth)
            maxItemWidth = itemWidth;
    }

    maxItemWidth  = MAX(maxItemWidth, kMinMenuItemWidth);
    maxItemHeight = MAX(maxItemHeight + [KxMenu itemVerticalMargin], kMinMenuItemHeight);

    const CGFloat titleX = kMarginX * 2;
    const CGFloat titleWidth = maxItemWidth - titleX - maxImageWidth - imageMargin - kMarginX * 2;
    // from left to right:
    // maxItemWidth = kMarginX * 2 + titleWidth + imageMargin + maxImageWidth + kMarginX * 2;
    // titles are aligned within titleWidth depending on alignment property
    // images are centered within maxImageWidth;
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectZero];
    contentView.autoresizingMask = UIViewAutoresizingNone;
    contentView.backgroundColor = [UIColor clearColor];
    contentView.opaque = NO;

    CGFloat itemY = kMarginY * 2;
    NSUInteger itemNum = 0;

    for (KxMenuItem *menuItem in _menuItems) {

        const CGRect itemFrame = (CGRect){0, itemY, maxItemWidth, maxItemHeight};

        UIView *itemView = [[UIView alloc] initWithFrame:itemFrame];
        itemView.autoresizingMask = UIViewAutoresizingNone;
        itemView.backgroundColor = [UIColor clearColor];
        itemView.opaque = NO;

        [contentView addSubview:itemView];

        if (menuItem.enabled) {

            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.tag = itemNum;
            button.frame = itemView.bounds;
            button.enabled = menuItem.enabled;
            button.backgroundColor = [UIColor clearColor];
            button.opaque = NO;
            button.autoresizingMask = UIViewAutoresizingNone;

            [button addTarget:self
                       action:@selector(performAction:)
             forControlEvents:UIControlEventTouchUpInside];

            UIImage *selectedImage = [KxMenuView selectedImage:(CGSize){maxItemWidth, maxItemHeight + 2} menuItems:_menuItems itemTag:itemNum];
            [button setBackgroundImage:selectedImage forState:UIControlStateHighlighted];
            [itemView addSubview:button];
	
	  if (@available(iOS 13.4, *)) {
	      button.pointerInteractionEnabled = YES;
	  }
        }

        if (menuItem.title.length) {

            CGRect titleFrame;

            if (!menuItem.enabled && !menuItem.image) {

                titleFrame = (CGRect){
                    kMarginX * 2,
                    kMarginY,
                    maxItemWidth - kMarginX * 4,
                    maxItemHeight - kMarginY * 2
                };

            } else {

                titleFrame = (CGRect){
                    titleX,
                    kMarginY,
                    titleWidth,
                    maxItemHeight - kMarginY * 2
                };
            }

             UILabel * titleLabel = [[UILabel alloc] initWithFrame:titleFrame];
            titleLabel.text = menuItem.title;
            titleLabel.font = titleFont;
            titleLabel.textAlignment = menuItem.alignment;
            titleLabel.textColor = menuItem.foreColor ? menuItem.foreColor : [KxMenu defaultForegroundColor];
            titleLabel.backgroundColor = [UIColor clearColor];
            titleLabel.autoresizingMask = UIViewAutoresizingNone;
            //titleLabel.backgroundColor = [UIColor greenColor];
            [itemView addSubview:titleLabel];
        }

        if (menuItem.image) {
            //const CGRect imageFrame = {x, y, maxImageWidth, maxItemHeight - kMarginY * 2};
            const CGSize size = menuItem.image.size;

            CGFloat x = kMarginX*2 + titleWidth + imageMargin + (maxImageWidth - size.width) / 2;
            CGFloat y = kMarginY + (maxItemHeight - size.height) / 2;
            const CGRect imageFrame = {x, y, size.height, size.width};

            UIImageView *imageView = [[UIImageView alloc] init];
            imageView.clipsToBounds = YES;
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            //imageView.autoresizingMask = UIViewAutoresizingNone;
            imageView.image = menuItem.image;
            imageView.frame = imageFrame;
            [itemView addSubview:imageView];
        }

        if (itemNum < _menuItems.count - 1) {
          UIImage *gradientLine = [KxMenuView gradientLine: (CGSize){maxItemWidth - kLineMarginX * 4, 1} menuItems:_menuItems itemTag:itemNum];
          UIView * lineView = [[UIView alloc] initWithFrame:(CGRect){kLineMarginX * 2, maxItemHeight + 1, gradientLine.size}];
          [lineView setBackgroundColor:[KxMenu dividerLineForegroundColor]];
          [itemView addSubview:lineView];
          
            itemY += 2;
        }

        itemY += maxItemHeight;
        ++itemNum;
    }

    contentView.frame = (CGRect){0, 0, maxItemWidth, itemY + kMarginY * 2};
    _selectedItem = -1; //none selected before arrow keys used
    return contentView;
}

- (CGPoint) arrowPoint
{
    CGPoint point;

    if (_arrowDirection == KxMenuViewArrowDirectionUp) {

        point = (CGPoint){ CGRectGetMinX(self.frame) + _arrowPosition, CGRectGetMinY(self.frame) };

    } else if (_arrowDirection == KxMenuViewArrowDirectionDown) {

        point = (CGPoint){ CGRectGetMinX(self.frame) + _arrowPosition, CGRectGetMaxY(self.frame) };

    } else if (_arrowDirection == KxMenuViewArrowDirectionLeft) {

        point = (CGPoint){ CGRectGetMinX(self.frame), CGRectGetMinY(self.frame) + _arrowPosition  };

    } else if (_arrowDirection == KxMenuViewArrowDirectionRight) {

        point = (CGPoint){ CGRectGetMaxX(self.frame), CGRectGetMinY(self.frame) + _arrowPosition  };

    } else {

        point = self.center;
    }

    return point;
}

+ (UIImage *) selectedImage: (CGSize) size
                     menuItems:(NSArray *)menuItems
                     itemTag:(int)tag

{
    const CGFloat locations[] = {0,1};
    const CGFloat components[] = {
        0.216, 0.471, 0.871, 1,
        0.059, 0.353, 0.839, 1,
    };
  
    return [self gradientImageWithSize:size locations:locations components:components count:2 menuItems:menuItems itemTag:tag];
}

+ (UIImage *) gradientLine: (CGSize) size
                 menuItems:(NSArray *)menuItems
                   itemTag:(int)tag
{
    const CGFloat locations[5] = {0,0.2,0.5,0.8,1};

    const CGFloat R = 0.44f, G = 0.44f, B = 0.44f;

    if ([KxMenu enableLineGradient])
    {
      const CGFloat components[20] = {
        R,G,B,0.1,
        R,G,B,0.4,
        R,G,B,0.7,
        R,G,B,0.4,
        R,G,B,0.1
      };
      return [self gradientImageWithSize:size locations:locations components:components count:5 menuItems:menuItems itemTag:tag];
    } else {
      const CGFloat components[20] = {
        R,G,B,1.0,
        R,G,B,1.0,
        R,G,B,1.0,
        R,G,B,1.0,
        R,G,B,1.0
      };
      return [self gradientImageWithSize:size locations:locations components:components count:5 menuItems:menuItems itemTag:tag];
    }
}

+ (UIImage *) gradientImageWithSize:(CGSize) size
                          locations:(const CGFloat []) locations
                         components:(const CGFloat []) components
                              count:(NSUInteger)count
                          menuItems:(NSArray *)menuItems
                            itemTag:(int)tag
{
  UIGraphicsBeginImageContextWithOptions(size, NO, 0);
  
  // Drawing with a white stroke color
  CGContextRef context=UIGraphicsGetCurrentContext();
  //CGContextSetRGBStrokeColor(context, 1.0, 1.0, 1.0, 1.0);//draws outline stroke if needed
  CGContextSetFillColorWithColor(context, [KxMenu defaultForegroundColor].CGColor);
  CGContextSetAlpha(context, 0.9);
  
  CGRect rrect = CGRectMake(0, 0, size.width, size.height);
  CGFloat radius = [KxMenu cornerRadius];
  CGFloat minx = CGRectGetMinX(rrect), midx = CGRectGetMidX(rrect), maxx = CGRectGetMaxX(rrect);
  CGFloat miny = CGRectGetMinY(rrect), midy = CGRectGetMidY(rrect), maxy = CGRectGetMaxY(rrect);
  
  CGContextMoveToPoint(context, minx, midy);
  if(menuItems.count == 1){
    CGContextAddArcToPoint(context, minx, miny, midx, miny, radius);
    CGContextAddArcToPoint(context, maxx, miny, maxx, midy, radius);
    CGContextAddArcToPoint(context, maxx, maxy, midx, maxy, radius);
    CGContextAddArcToPoint(context, minx, maxy, minx, midy, radius);
  } else if(tag == 0){
    CGContextAddArcToPoint(context, minx, miny, midx, miny, radius);
    CGContextAddArcToPoint(context, maxx, miny, maxx, midy, radius);
    CGContextAddLineToPoint(context, maxx, maxy);
    CGContextAddLineToPoint(context, minx, maxy);
  } else if (tag == menuItems.count-1){
    CGContextAddLineToPoint(context, minx, miny);
    CGContextAddLineToPoint(context, maxx, miny);
    CGContextAddArcToPoint(context, maxx, maxy, midx, maxy, radius);
    CGContextAddArcToPoint(context, minx, maxy, minx, midy, radius);
  } else {
    CGContextAddLineToPoint(context, minx, miny);
    CGContextAddLineToPoint(context, maxx, miny);
    CGContextAddLineToPoint(context, maxx, maxy);
    CGContextAddLineToPoint(context, minx, maxy);
  }
  
  // Close the path
  CGContextClosePath(context);
  // Fill & stroke the path 
  CGContextDrawPath(context, kCGPathFillStroke);

  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return image;
}

- (void) drawRect:(CGRect)rect
{
    [self drawBackground:self.bounds
               inContext:UIGraphicsGetCurrentContext()];
}

- (void)drawBackground:(CGRect)frame
             inContext:(CGContextRef) context
{

    CGFloat R0 = 0.267, G0 = 0.303, B0 = 0.335;
    CGFloat R1 = 0.040, G1 = 0.040, B1 = 0.040;

    if ([KxMenu getBackgroundGradientStart])
    {
      CGFloat a;
      [[KxMenu getBackgroundGradientStart] getRed:&R0 green:&G0 blue:&B0 alpha:&a];
      [[KxMenu getBackgroundGradientEnd] getRed:&R1 green:&G1 blue:&B1 alpha:&a];
    }

    UIColor *tintColor = [KxMenu tintColor];
    if (tintColor) {

        CGFloat a;
        [tintColor getRed:&R0 green:&G0 blue:&B0 alpha:&a];
    }

    CGFloat X0 = frame.origin.x;
    CGFloat X1 = frame.origin.x + frame.size.width;
    CGFloat Y0 = frame.origin.y;
    CGFloat Y1 = frame.origin.y + frame.size.height;

    // render arrow
    if ([KxMenu displayArrow])
    {
      UIBezierPath *arrowPath = [UIBezierPath bezierPath];

      // fix the issue with gap of arrow's base if on the edge
      const CGFloat kEmbedFix = 3.f;

      if (_arrowDirection == KxMenuViewArrowDirectionUp) {

          const CGFloat arrowXM = _arrowPosition;
          const CGFloat arrowX0 = arrowXM - kArrowSize;
          const CGFloat arrowX1 = arrowXM + kArrowSize;
          const CGFloat arrowY0 = Y0;
          const CGFloat arrowY1 = Y0 + kArrowSize + kEmbedFix;

          [arrowPath moveToPoint:    (CGPoint){arrowXM, arrowY0}];
          [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
          [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowY1}];
          [arrowPath addLineToPoint: (CGPoint){arrowXM, arrowY0}];

          [[UIColor colorWithRed:R0 green:G0 blue:B0 alpha:1] set];

          Y0 += kArrowSize;

      } else if (_arrowDirection == KxMenuViewArrowDirectionDown) {

          const CGFloat arrowXM = _arrowPosition;
          const CGFloat arrowX0 = arrowXM - kArrowSize;
          const CGFloat arrowX1 = arrowXM + kArrowSize;
          const CGFloat arrowY0 = Y1 - kArrowSize - kEmbedFix;
          const CGFloat arrowY1 = Y1;

          [arrowPath moveToPoint:    (CGPoint){arrowXM, arrowY1}];
          [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
          [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowY0}];
          [arrowPath addLineToPoint: (CGPoint){arrowXM, arrowY1}];

          [[UIColor colorWithRed:R1 green:G1 blue:B1 alpha:1] set];

          Y1 -= kArrowSize;

      } else if (_arrowDirection == KxMenuViewArrowDirectionLeft) {

          const CGFloat arrowYM = _arrowPosition;
          const CGFloat arrowX0 = X0;
          const CGFloat arrowX1 = X0 + kArrowSize + kEmbedFix;
          const CGFloat arrowY0 = arrowYM - kArrowSize;;
          const CGFloat arrowY1 = arrowYM + kArrowSize;

          [arrowPath moveToPoint:    (CGPoint){arrowX0, arrowYM}];
          [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
          [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
          [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowYM}];

          [[UIColor colorWithRed:R0 green:G0 blue:B0 alpha:1] set];

          X0 += kArrowSize;

      } else if (_arrowDirection == KxMenuViewArrowDirectionRight) {

          const CGFloat arrowYM = _arrowPosition;
          const CGFloat arrowX0 = X1;
          const CGFloat arrowX1 = X1 - kArrowSize - kEmbedFix;
          const CGFloat arrowY0 = arrowYM - kArrowSize;;
          const CGFloat arrowY1 = arrowYM + kArrowSize;

          [arrowPath moveToPoint:    (CGPoint){arrowX0, arrowYM}];
          [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY0}];
          [arrowPath addLineToPoint: (CGPoint){arrowX1, arrowY1}];
          [arrowPath addLineToPoint: (CGPoint){arrowX0, arrowYM}];

          [[UIColor colorWithRed:R1 green:G1 blue:B1 alpha:1] set];

          X1 -= kArrowSize;
      }

      [arrowPath fill];
    } else {
      //add padding to popup
      float padding = [KxMenu distancePadding];
      if (_arrowDirection == KxMenuViewArrowDirectionUp) {
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y + padding, self.frame.size.width, self.frame.size.height);
      } else if (_arrowDirection == KxMenuViewArrowDirectionDown) {
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y - padding, self.frame.size.width, self.frame.size.height);
      } else if (_arrowDirection == KxMenuViewArrowDirectionLeft) {
        self.frame = CGRectMake(self.frame.origin.x + padding, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
      } else if (_arrowDirection == KxMenuViewArrowDirectionRight) {
        self.frame = CGRectMake(self.frame.origin.x - padding, self.frame.origin.y, self.frame.size.width, self.frame.size.height);
      }
      
    }

    // render body

    const CGRect bodyFrame = {X0, Y0, X1 - X0, Y1 - Y0};

    UIBezierPath *borderPath = [KxMenu roundedRect] ?
      [UIBezierPath bezierPathWithRoundedRect:bodyFrame cornerRadius:[KxMenu cornerRadius]] :
      [UIBezierPath bezierPathWithRect:bodyFrame];

    const CGFloat locations[] = {0, 1};
    const CGFloat components[] = {
        R0, G0, B0, 1,
        R1, G1, B1, 1,
    };

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace,
                                                                 components,
                                                                 locations,
                                                                 sizeof(locations)/sizeof(locations[0]));
    CGColorSpaceRelease(colorSpace);


    [borderPath addClip];

    CGPoint start, end;

    if (_arrowDirection == KxMenuViewArrowDirectionLeft ||
        _arrowDirection == KxMenuViewArrowDirectionRight) {

        start = (CGPoint){X0, Y0};
        end = (CGPoint){X1, Y0};

    } else {

        start = (CGPoint){X0, Y0};
        end = (CGPoint){X0, Y1};
    }

    CGContextDrawLinearGradient(context, gradient, start, end, 0);

    CGGradientRelease(gradient);
}

@end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

static KxMenu *gMenu;
static UIColor *gTintColor;
static UIFont *gTitleFont;
static BOOL gDisplayArrow;
static BOOL gRoundedRect;
static BOOL gShadowed;
static UIColor* gBackgroundStart;
static UIColor* gBackgroundEnd;
static CGFloat gItemVerticalMargin = 0.0;
static CGFloat gLineMargin = 10.0;
static CGFloat gCornerRadius = 8.0;
static CGFloat gDistancePadding = 20.0;
static CGSize gMenuMargin = {10.0, 5.0};
static BOOL gEnableLineGradient = TRUE;
static UIColor* gDefaultForegroundColor;
static UIColor * gDividerForegroundColor;

@implementation KxMenu {

    KxMenuView *_menuView;
    BOOL        _observing;
}

+ (instancetype) sharedMenu
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        gMenu = [[KxMenu alloc] init];
    });
    return gMenu;
}

+(UIView *) mainView {
  return gMenu->_menuView.contentView;
}

- (id) init
{
    NSAssert(!gMenu, @"singleton object");

    self = [super init];
    if (self) {
    }
    return self;
}

- (void) dealloc
{
    if (_observing) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void) showMenuInView:(UIView *)view
               fromRect:(CGRect)rect
              menuItems:(NSArray *)menuItems
              onDismiss:(void (^)(void))dismissBlock
{
    NSParameterAssert(view);
    NSParameterAssert(menuItems.count);

    if (_menuView) {

        [_menuView dismissMenu:NO];
        _menuView = nil;
    }

    if (!_observing) {

        _observing = YES;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(orientationWillChange:)
                                                     name:UIApplicationWillChangeStatusBarOrientationNotification
                                                   object:nil];
    }


    _menuView = [[KxMenuView alloc] init];
    [_menuView showMenuInView:view fromRect:rect menuItems:menuItems onDismiss:dismissBlock];
}

+ (void) showMenuFromView:(UIView *)view
                menuItems:(NSArray *)menuItems
                onDismiss:(KxDismissBlock) dismissBlock;
{
 
  UIView* topView = view;
  while (![topView.superview isKindOfClass:[UIWindow class]])
    topView = topView.superview;
  CGRect r = [topView convertRect:view.frame fromView:view.superview];
  [KxMenu showMenuInView:topView fromRect:r menuItems:menuItems onDismiss:dismissBlock];
}


- (void) dismissMenu
{
    if (_menuView) {

        [_menuView dismissMenu:NO];
        _menuView = nil;
    }

    if (_observing) {

        _observing = NO;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void) orientationWillChange: (NSNotification *) n
{
    [self dismissMenu];
}

+ (void) showMenuInView:(UIView *)view
               fromRect:(CGRect)rect
              menuItems:(NSArray *)menuItems
              onDismiss:(KxDismissBlock)dismissBlock
{
    [[self sharedMenu] showMenuInView:view fromRect:rect menuItems:menuItems onDismiss:dismissBlock];
}

+ (void) dismissMenu
{
    [[self sharedMenu] dismissMenu];
}

+ (UIColor *) tintColor
{
    return gTintColor;
}

+ (void) setTintColor: (UIColor *) tintColor
{
    if (tintColor != gTintColor) {
        gTintColor = tintColor;
    }
}

+ (UIFont *) titleFont
{
    return gTitleFont;
}

+ (void) setTitleFont: (UIFont *) titleFont
{
    if (titleFont != gTitleFont) {
        gTitleFont = titleFont;
    }
}

+ (void) setDisplayArrow:(BOOL) display
{
  gDisplayArrow = display;
}

+ (BOOL) displayArrow;
{
  return gDisplayArrow;
}

+ (void) setRoundedRect:(BOOL) rounded;
{
  gRoundedRect = rounded;
}

+ (BOOL) roundedRect
{
  return gRoundedRect;
}

+ (void) setShadowed:(BOOL) shadow
{
  gShadowed = shadow;
}

+ (BOOL) shadowed
{
  return gShadowed;
}

+ (void) setBackgroundGradientStart:(UIColor*) startColor andEnd:(UIColor*) endColor
{
  gBackgroundStart = startColor;
  gBackgroundEnd = endColor;
}

+ (UIColor*) getBackgroundGradientStart
{
  return gBackgroundStart;
}

+ (UIColor*) getBackgroundGradientEnd
{
  return gBackgroundEnd;
}

+ (void) setItemVerticalMargin:(CGFloat) margin
{
  gItemVerticalMargin = margin;
}

+ (CGFloat) itemVerticalMargin
{
  return gItemVerticalMargin;
}

+ (void) setLineMargin:(CGFloat) margin;
{
  gLineMargin = margin;
}

+ (CGFloat) lineMargin;
{
  return gLineMargin;
}

+ (void) setMenuMargin:(CGSize) margin
{
  gMenuMargin = margin;
}

+ (CGSize) menuMargin
{
  return gMenuMargin;
}

+ (void) setEnableLineGradient:(BOOL) enable
{
  gEnableLineGradient = enable;
}

+ (BOOL) enableLineGradient
{
  return gEnableLineGradient;
}

+ (void) setDefaultForegroundColor:(UIColor*)color {
  gDefaultForegroundColor = color;
}

+ (UIColor*) defaultForegroundColor {
  return gDefaultForegroundColor ? gDefaultForegroundColor : [UIColor whiteColor];
}

+ (void) setDividerLineForegroundColor:(UIColor*)color{
  gDividerForegroundColor = color;
}
+ (UIColor*) dividerLineForegroundColor{
  return gDividerForegroundColor ? gDividerForegroundColor : [UIColor blackColor];
}

+ (void) setCornerRadius:(CGFloat)radius
{
  gCornerRadius = radius;
}

+ (CGFloat) cornerRadius{
  return gCornerRadius;
}

+ (void) setDistancePadding:(CGFloat)distance
{
  gDistancePadding = distance;
}

+ (CGFloat) distancePadding{
  return gDistancePadding;
}

@end
