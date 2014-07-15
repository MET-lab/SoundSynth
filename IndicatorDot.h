//
//  IndicatorDot.h
//  IndicatorDotTest
//
//  Created by Jeff Gregorio on 7/8/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "METScopeView.h"

@interface IndicatorDot : UIView

@property METScopeView *parentView;
@property (readonly) CGPoint position;
@property UIColor *dotColor;
@property bool visible;

- (id)initWithParent:(METScopeView *)parent size:(CGSize)size pos:(CGPoint)pos color:(UIColor *)color;

- (void)setPosition:(CGPoint)pos;

@end
