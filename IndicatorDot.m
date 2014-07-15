//
//  IndicatorDot.m
//  IndicatorDotTest
//
//  Created by Jeff Gregorio on 7/8/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "IndicatorDot.h"

@implementation IndicatorDot

@synthesize parentView;
@synthesize dotColor;
@synthesize position;
@synthesize visible;

- (id)initWithParent:(METScopeView *)parent size:(CGSize)size pos:(CGPoint)pos color:(UIColor *)color {
    
    /* Convert x and y (plot units) to pixel locations in the scope view */
    CGPoint origin = [parent plotScaleToPixel:pos.x y:pos.y];
    CGRect frame = CGRectMake(origin.x-size.width/2, origin.y-size.height/2, size.width, size.height);
    
    self = [super initWithFrame:frame];
    if (self) {
        
        parentView = parent;
        position = pos;
        dotColor = color;
        visible = true;
        
        [self setBackgroundColor:[UIColor clearColor]];
    }
    return self;
}


- (void)drawRect:(CGRect)rect {
    
    if (!visible)
        return;
    
    if (position.x < parentView.visiblePlotMin.x || position.x > parentView.visiblePlotMax.x)
        return;
    
    if (parentView.axisScale == kMETScopeViewAxesLinear &&
        (position.y < parentView.visiblePlotMin.y || position.y > parentView.visiblePlotMax.y))
        return;
    
    if (parentView.axisScale == kMETScopeViewAxesSemilogY &&
        (20*log10f(position.y) < parentView.visiblePlotMin.y || 20*log10f(position.y) > parentView.visiblePlotMax.y))
        return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextAddEllipseInRect(context, rect);
    CGContextSetFillColor(context, CGColorGetComponents([dotColor CGColor]));
    CGContextFillPath(context);
}

- (void)setPosition:(CGPoint)pos {
    
    position = pos;
    
    CGPoint origin = [parentView plotScaleToPixel:pos.x y:pos.y];
    
    CGSize size = self.frame.size;
    [self setFrame:CGRectMake(origin.x-size.width/2, origin.y-size.height/2, size.width, size.height)];
    
    [self setNeedsDisplay];
}

- (void)setVisible:(bool)isVisible {
    visible = isVisible;
    [self setNeedsDisplay];
}


@end
