//
//  KxMenu.h
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


#import <Foundation/Foundation.h>

@interface KxMenuItem : NSObject

@property (readwrite, nonatomic, strong) UIImage *image;
@property (readwrite, nonatomic, strong) NSString *title;
@property (readwrite, nonatomic, weak) id target;
@property (readwrite, nonatomic) SEL action;
@property (readwrite, nonatomic, strong) UIColor *foreColor;
@property (readwrite, nonatomic) NSTextAlignment alignment;
@property (readwrite, nonatomic) NSInteger tag;
@property (readwrite, nonatomic) NSInteger subTag;

+ (instancetype) menuItem:(NSString *) title
                    image:(UIImage *) image
                   target:(id)target
                   action:(SEL) action;

+ (instancetype) menuItem:(NSString *) title
                    image:(UIImage *) image
                   target:(id)target
                   action:(SEL) action
                      tag:(NSInteger) tag;

+ (instancetype) menuItem:(NSString *) title
                    image:(UIImage *) image
                   target:(id)target
                   action:(SEL) action
                      tag:(NSInteger) tag
                      subTag:(NSInteger) subTag;
@end

@interface KxMenu : NSObject

typedef void (^KxDismissBlock)(void);
+ (UIView *) mainView;

+ (void) showMenuInView:(UIView *)view
               fromRect:(CGRect)rect
              menuItems:(NSArray *)menuItems
              onDismiss:(KxDismissBlock) dismissBlock;

+ (void) showMenuFromView:(UIView *)view
              menuItems:(NSArray *)menuItems
              onDismiss:(KxDismissBlock) dismissBlock;

+ (void) dismissMenu;

+ (UIColor *) tintColor;
+ (void) setTintColor: (UIColor *) tintColor;

+ (UIFont *) titleFont;
+ (void) setTitleFont: (UIFont *) titleFont;

+ (void) setDisplayArrow:(BOOL) display;
+ (BOOL) displayArrow;

+ (void) setRoundedRect:(BOOL) rounded;
+ (BOOL) roundedRect;

+ (void) setShadowed:(BOOL) shadow;
+ (BOOL) shadowed;

+ (void) setBackgroundGradientStart:(UIColor*) startColor andEnd:(UIColor*) endColor;
+ (UIColor*) getBackgroundGradientStart;
+ (UIColor*) getBackgroundGradientEnd;

+ (void) setItemVerticalMargin:(CGFloat) margin;
+ (CGFloat) itemVerticalMargin;

+ (void) setLineMargin:(CGFloat) margin;
+ (CGFloat) lineMargin;

+ (void) setMenuMargin:(CGSize) margin;
+ (CGSize) menuMargin;

+ (void) setEnableLineGradient:(BOOL) enable;
+ (BOOL) enableLineGradient;

+ (void) setDefaultForegroundColor:(UIColor*)color;
+ (UIColor*) defaultForegroundColor;

/**
 * Divider line color between menu sections
 * @param color value
 * @return UIColor value
 */
+ (void) setDividerLineForegroundColor:(UIColor*)color;
+ (UIColor*) dividerLineForegroundColor;

/**
 * Sets corner radius for popup view
 * @param radius value
 * @return CGFloat radius value
 */
+ (void) setCornerRadius:(CGFloat) radius;
+ (CGFloat) cornerRadius;

/**
 * Distance between popup and target view
 * @param distance padding value
 * @return CGFloat distance value
 */
+ (void) setDistancePadding:(CGFloat)distance;
+ (CGFloat) distancePadding;

@end
