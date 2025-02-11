// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 

#import "IconButton.h"
#import "UIImage+ImageUtilities.h"
#import "Wire-Swift.h"

@implementation IconDefinition

+ (instancetype)iconDefinitionForType:(WRStyleKitIcon)type size:(CGFloat)size renderingMode:(UIImageRenderingMode)renderingMode
{
    IconDefinition *result = self.class.new;
    
    result.iconType = type;
    result.iconSize = size;
    result.renderingMode = renderingMode;
    
    return result;
}

- (BOOL)isEqual:(id)object
{
    if (! [object isKindOfClass:self.class]) {
        return NO;
    }
    
    IconDefinition *objectIconDefinition = (IconDefinition *)object;
    
    if (objectIconDefinition.iconType == self.iconType &&
        objectIconDefinition.iconSize == self.iconSize &&
        objectIconDefinition.renderingMode == self.renderingMode) {
        return YES;
    }
    
    return NO;
}

- (NSUInteger)hash
{
    return (self.iconType * self.iconSize * self.renderingMode);
}

@end




@implementation IconButton

- (instancetype)initWithStyle:(IconButtonStyle)style
{
    return [self initWithStyle:style variant:ColorScheme.defaultColorScheme.variant];
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.hitAreaPadding = CGSizeMake(20, 20);
        _borderWidth = 0.5f;
        _iconColorsByState = [NSMutableDictionary dictionary];
        _borderColorByState = [NSMutableDictionary dictionary];
        _iconDefinitionsByState = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)setBorderWidth:(CGFloat)borderWidth
{
    _borderWidth = borderWidth;
    
    [self setCircular:self.circular];
}

- (void)setCircular:(BOOL)circular
{
    _circular = circular;
    
    if (circular) {
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = self.borderWidth;
        [self updateCircularCornerRadius];
    } else {
        self.layer.masksToBounds = NO;
        self.layer.borderWidth = 0.0f;
        self.layer.cornerRadius = 0;
    }
}

-(void)setRoundCorners:(BOOL)roundCorners
{
    _roundCorners = roundCorners;
    [self updateCustomCornerRadius];
}

- (void)setTitleImageSpacing:(CGFloat)titleImageSpacing
{
    [self setTitleImageSpacing:titleImageSpacing horizontalMargin:0];
}

- (void)setTitleImageSpacing:(CGFloat)titleImageSpacing horizontalMargin:(CGFloat)horizontalMargin
{
    _titleImageSpacing = titleImageSpacing;
    
    BOOL isLeftToRight = YES;
    if ([[UIView class] respondsToSelector:@selector(userInterfaceLayoutDirectionForSemanticContentAttribute:)]) {
        isLeftToRight = [UIView userInterfaceLayoutDirectionForSemanticContentAttribute: UISemanticContentAttributeUnspecified] == UIUserInterfaceLayoutDirectionLeftToRight;
    }
    
    CGFloat inset = titleImageSpacing / 2.0f ;
    CGFloat leftInset = isLeftToRight ? -inset : inset;
    CGFloat rightInset = isLeftToRight ? inset : -inset;
    
    self.imageEdgeInsets = UIEdgeInsetsMake(self.imageEdgeInsets.top, leftInset, self.imageEdgeInsets.bottom, rightInset);
    self.titleEdgeInsets = UIEdgeInsetsMake(self.titleEdgeInsets.top, rightInset, self.titleEdgeInsets.bottom, leftInset);

    CGFloat horizontal = inset + horizontalMargin;
    self.contentEdgeInsets = UIEdgeInsetsMake(self.contentEdgeInsets.top, horizontal, self.contentEdgeInsets.bottom, horizontal);
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state
{
    [super setTitleColor:color forState:state];
    
    if (self.adjustsTitleWhenHighlighted && (state & UIControlStateNormal) == UIControlStateNormal) {
        [super setTitleColor:[[self titleColorForState:UIControlStateHighlighted] mix:UIColor.blackColor amount:0.4] forState:UIControlStateHighlighted];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    [self updateCircularCornerRadius];
}

- (void)setBackgroundImageColor:(UIColor *)color forState:(UIControlState)state
{
    [self setBackgroundImage:[UIImage singlePixelImageWithColor:color] forState:state];
    if (self.adjustBackgroundImageWhenHighlighted && (state & UIControlStateNormal) == UIControlStateNormal) {
        [self setBackgroundImage:[UIImage singlePixelImageWithColor:[color mix:UIColor.blackColor amount:0.4]] forState:UIControlStateHighlighted];
    }
}

- (void)setIcon:(WRStyleKitIcon)icon withSize:(CGFloat)iconSize forState:(UIControlState)state
{
    [self setIcon:icon withSize:iconSize forState:state renderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)setIcon:(WRStyleKitIcon)iconType withSize:(CGFloat)iconSize forState:(UIControlState)state renderingMode:(UIImageRenderingMode)renderingMode
{
    [self setIcon:iconType withSize:iconSize forState:state renderingMode:renderingMode force:NO];
}

- (void)setIcon:(WRStyleKitIcon)iconType withSize:(CGFloat)iconSize forState:(UIControlState)state renderingMode:(UIImageRenderingMode)renderingMode force:(BOOL)force
{
    IconDefinition *newIcon = [IconDefinition iconDefinitionForType:iconType size:iconSize renderingMode:renderingMode];
    
    IconDefinition *currentIcon = self.iconDefinitionsByState[@(state)];
    
    if (! force && [currentIcon isEqual:newIcon]) {
        return;
    }
    
    self.iconDefinitionsByState[@(state)] = newIcon;
    
    UIColor *color = (renderingMode == UIImageRenderingModeAlwaysOriginal) ? [self iconColorForState:UIControlStateNormal] : UIColor.blackColor;
    
    UIImage *image = [UIImage imageForIcon:iconType
                                      size:iconSize
                                     color:color];
    
    [self setImage:[image imageWithRenderingMode:renderingMode] forState:state];
}

- (void)removeIconForState:(UIControlState)state
{
    self.iconDefinitionsByState[@(state)] = nil;
    [self setImage:nil forState:state];
}

- (void)setIconColor:(UIColor *)color forState:(UIControlState)state
{
    if (nil != color) {
        [self.iconColorsByState setObject:[color copy] forKey:@(state)];
    }
    else {
        [self.iconColorsByState removeObjectForKey:@(state)];
    }
    
    IconDefinition *currentIcon = self.iconDefinitionsByState[@(state)];
    
    if (currentIcon && currentIcon.renderingMode == UIImageRenderingModeAlwaysOriginal) {
        [self setIcon:currentIcon.iconType withSize:currentIcon.iconSize forState:state renderingMode:currentIcon.renderingMode force:YES];
    }
    
    [self updateTintColor];
}

- (IconDefinition *)iconDefinitionForState:(UIControlState)state
{
    return self.iconDefinitionsByState[@(state)];
}

- (UIColor *)iconColorForState:(UIControlState)state
{
    UIColor *iconColor = self.iconColorsByState[@(state)];
    
    if (iconColor == nil) {
        iconColor = self.iconColorsByState[@(UIControlStateNormal)];
    }
    
    return iconColor;
}

- (UIColor *)borderColorForState:(UIControlState)state
{
    UIColor *borderColor = self.self.borderColorByState[@(state)];

    if (borderColor == nil) {
        borderColor = self.borderColorByState[@(UIControlStateNormal)];
    }

    return borderColor;
}

- (void)updateBorderColor
{
    self.layer.borderColor = [self borderColorForState:self.state].CGColor;
}

- (void)updateTintColor
{
    self.tintColor = [self iconColorForState:self.state];
}

- (void)updateCircularCornerRadius
{
    if (self.circular) {

        /// Create a circular mask. It would also mask subviews.

        CGFloat radius = self.bounds.size.height / 2;
        UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       byRoundingCorners:UIRectCornerAllCorners
                                                             cornerRadii:CGSizeMake(radius, radius)];

        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        maskLayer.frame = self.bounds;
        maskLayer.path = maskPath.CGPath;

        self.layer.mask = maskLayer;

        /// When the button has border, set self.layer.cornerRadius to prevent border is covered by icon
        if (self.borderWidth > 0) {
            self.layer.cornerRadius = radius;
        }
        else {
            self.layer.cornerRadius = 0;
        }
    }
}

- (void)updateCustomCornerRadius
{
    if(self.roundCorners) {
        self.layer.cornerRadius = 6.0;
    } else {
        self.layer.cornerRadius = 0.0;
    }
}

#pragma mark - Observing state

- (void)setHighlighted:(BOOL)highlighted
{
    _priorState = self.state;
    [super setHighlighted:highlighted];
    [self updateForNewStateIfNeeded];
}

- (void)setSelected:(BOOL)selected
{
    _priorState = self.state;
    [super setSelected:selected];
    [self updateForNewStateIfNeeded];
}

- (void)setEnabled:(BOOL)enabled
{
    _priorState = self.state;
    [super setEnabled:enabled];
    [self updateForNewStateIfNeeded];
}

- (void)updateForNewStateIfNeeded
{
    if(self.state != _priorState)
    {
        _priorState = self.state;
        // Update for new state (selected, highlighted, disabled) here if needed
        [self updateTintColor];
        [self updateBorderColor];
    }
}

@end
