#ifdef SHOULD_COMPILE_LOOKIN_SERVER 

//
//  UIView+LookinMobile.m
//  WeRead
//
//  Created by Li Kai on 2018/11/30.
//  Copyright © 2018 tencent. All rights reserved.
//

#import "CALayer+LookinServer.h"
#import "LKS_HierarchyDisplayItemsMaker.h"
#import "LookinDisplayItem.h"
#import "LKS_LocalInspectManager.h"
#import <objc/runtime.h>
#import "LKS_ConnectionManager.h"
#import "LookinIvarTrace.h"
#import "LookinServerDefines.h"
#import "UIColor+LookinServer.h"

@implementation CALayer (LookinServer)

- (void)setLks_isLookinPrivateLayer:(BOOL)lks_isLookinPrivateLayer {
    [self lookin_bindBOOL:lks_isLookinPrivateLayer forKey:@"lks_isLookinPrivateLayer"];
}

- (BOOL)lks_isLookinPrivateLayer {
    return [self lookin_getBindBOOLForKey:@"lks_isLookinPrivateLayer"];
}

- (UIWindow *)lks_window {
    CALayer *layer = self;
    while (layer) {
        UIView *hostView = layer.lks_hostView;
        if (hostView.window) {
            return hostView.window;
        } else if ([hostView isKindOfClass:[UIWindow class]]) {
            return (UIWindow *)hostView;
        }
        layer = layer.superlayer;
    }
    return nil;
}

- (BOOL)lks_inLookinPrivateHierarchy {
    BOOL boolValue = NO;
    CALayer *layer = self;
    while (layer) {
        if (layer.lks_isLookinPrivateLayer) {
            boolValue = YES;
            break;
        }
        layer = layer.superlayer;
    }
    return boolValue;
}

- (CGRect)lks_frameInWindow:(UIWindow *)window {
    UIWindow *selfWindow = [self lks_window];
    if (!selfWindow) {
        return CGRectZero;
    }
    
    CGRect rectInSelfWindow = [selfWindow.layer convertRect:self.frame fromLayer:self.superlayer];
    CGRect rectInWindow = [window convertRect:rectInSelfWindow fromWindow:selfWindow];
    return rectInWindow;
}

- (void)setLks_avoidCapturing:(BOOL)lks_avoidCapturing {
    [self lookin_bindBOOL:lks_avoidCapturing forKey:@"lks_avoidCapturing"];
}

- (BOOL)lks_avoidCapturing {
    return [self lookin_getBindBOOLForKey:@"lks_avoidCapturing"];
}

#pragma mark - Host View

- (UIView *)lks_hostView {
    if (self.delegate && [self.delegate isKindOfClass:UIView.class]) {
        UIView *view = (UIView *)self.delegate;
        if (view.layer == self) {
            return view;
        }
    }
    return nil;
}

#pragma mark - Screenshot

- (UIImage *)lks_groupScreenshotWithLowQuality:(BOOL)lowQuality {
    
    CGFloat screenScale = [UIScreen mainScreen].scale;
    CGFloat pixelWidth = self.bounds.size.width * screenScale;
    CGFloat pixelHeight = self.bounds.size.height * screenScale;
    if (pixelWidth <= 0 || pixelHeight <= 0) {
        return nil;
    }
    
    CGFloat renderScale = lowQuality ? 1 : 0;
    CGFloat maxLength = MAX(pixelWidth, pixelHeight);
    if (maxLength > LookinNodeImageMaxLengthInPx) {
        // 确保最终绘制出的图片长和宽都不能超过 LookinNodeImageMaxLengthInPx
        // 如果算出的 renderScale 大于 1 则取 1，因为似乎用 1 渲染的速度要比一个别的奇怪的带小数点的数字要更快
        renderScale = MIN(screenScale * LookinNodeImageMaxLengthInPx / maxLength, 1);
    }
    
    CGSize size = (self.frame.size.width == 0 || self.frame.size.height == 0) ? CGSizeMake(1, 1) : self.frame.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, renderScale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (self.lks_hostView && !self.lks_hostView.lks_isChildrenViewOfTabBar) {
        [self.lks_hostView drawViewHierarchyInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) afterScreenUpdates:YES];
    } else {
        [self renderInContext:context];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)lks_soloScreenshotWithLowQuality:(BOOL)lowQuality {
    if (!self.sublayers.count) {
        return nil;
    }
    
    CGFloat screenScale = [UIScreen mainScreen].scale;
    CGFloat pixelWidth = self.bounds.size.width * screenScale;
    CGFloat pixelHeight = self.bounds.size.height * screenScale;
    if (pixelWidth <= 0 || pixelHeight <= 0) {
        return nil;
    }
    
    CGFloat renderScale = lowQuality ? 1 : 0;
    CGFloat maxLength = MAX(pixelWidth, pixelHeight);
    if (maxLength > LookinNodeImageMaxLengthInPx) {
        // 确保最终绘制出的图片长和宽都不能超过 LookinNodeImageMaxLengthInPx
        // 如果算出的 renderScale 大于 1 则取 1，因为似乎用 1 渲染的速度要比一个别的奇怪的带小数点的数字要更快
        renderScale = MIN(screenScale * LookinNodeImageMaxLengthInPx / maxLength, 1);
    }
    
    if (self.sublayers.count) {
        NSArray<CALayer *> *sublayers = [self.sublayers copy];
        NSMutableArray<CALayer *> *visibleSublayers = [NSMutableArray arrayWithCapacity:sublayers.count];
        [sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull sublayer, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!sublayer.hidden) {
                sublayer.hidden = YES;
                [visibleSublayers addObject:sublayer];
            }
        }];
        
        CGSize size = (self.frame.size.width == 0 || self.frame.size.height == 0) ? CGSizeMake(1, 1) : self.frame.size;
        UIGraphicsBeginImageContextWithOptions(size, NO, renderScale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (self.lks_hostView && !self.lks_hostView.lks_isChildrenViewOfTabBar) {
            [self.lks_hostView drawViewHierarchyInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) afterScreenUpdates:YES];
        } else {
            [self renderInContext:context];
        }
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [visibleSublayers enumerateObjectsUsingBlock:^(CALayer * _Nonnull sublayer, NSUInteger idx, BOOL * _Nonnull stop) {
            sublayer.hidden = NO;
        }];
        
        return image;
    }
    return nil;
}

- (NSArray<NSArray<NSString *> *> *)lks_relatedClassChainList {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:2];
    if (self.lks_hostView) {
        [array addObject:[CALayer lks_getClassListOfObject:self.lks_hostView endingClass:@"UIView"]];
        UIViewController* vc = [self.lks_hostView lks_findHostViewController];
        if (vc) {
            [array addObject:[CALayer lks_getClassListOfObject:vc endingClass:@"UIViewController"]];
        }
    } else {
        [array addObject:[CALayer lks_getClassListOfObject:self endingClass:@"CALayer"]];
    }
    return array.copy;
}

+ (NSArray<NSString *> *)lks_getClassListOfObject:(id)object endingClass:(NSString *)endingClass {
    NSArray<NSString *> *completedList = [object lks_classChainListWithSwiftPrefix:NO];
    NSUInteger endingIdx = [completedList indexOfObject:endingClass];
    if (endingIdx != NSNotFound) {
        completedList = [completedList subarrayWithRange:NSMakeRange(0, endingIdx + 1)];
    }
    return completedList;
}

- (NSArray<NSString *> *)lks_selfRelation {
    NSMutableArray *array = [NSMutableArray array];
    NSMutableArray<LookinIvarTrace *> *ivarTraces = [NSMutableArray array];
    if (self.lks_hostView) {
        UIViewController* vc = [self.lks_hostView lks_findHostViewController];
        if (vc) {
            [array addObject:[NSString stringWithFormat:@"(%@ *).view", NSStringFromClass(vc.class)]];
            
            [ivarTraces addObjectsFromArray:vc.lks_ivarTraces];
        }
        [ivarTraces addObjectsFromArray:self.lks_hostView.lks_ivarTraces];
    } else {
        [ivarTraces addObjectsFromArray:self.lks_ivarTraces];
    }
    if (ivarTraces.count) {
        [array addObjectsFromArray:[ivarTraces lookin_map:^id(NSUInteger idx, LookinIvarTrace *value) {
            return [NSString stringWithFormat:@"(%@ *) -> %@", value.hostClassName, value.ivarName];
        }]];
    }
    return array.count ? array.copy : nil;
}

- (UIColor *)lks_backgroundColor {
    return [UIColor lks_colorWithCGColor:self.backgroundColor];
}
- (void)setLks_backgroundColor:(UIColor *)lks_backgroundColor {
    self.backgroundColor = lks_backgroundColor.CGColor;
}

- (UIColor *)lks_borderColor {
    return [UIColor lks_colorWithCGColor:self.borderColor];
}
- (void)setLks_borderColor:(UIColor *)lks_borderColor {
    self.borderColor = lks_borderColor.CGColor;
}

- (UIColor *)lks_shadowColor {
    return [UIColor lks_colorWithCGColor:self.shadowColor];
}
- (void)setLks_shadowColor:(UIColor *)lks_shadowColor {
    self.shadowColor = lks_shadowColor.CGColor;
}

- (CGFloat)lks_shadowOffsetWidth {
    return self.shadowOffset.width;
}
- (void)setLks_shadowOffsetWidth:(CGFloat)lks_shadowOffsetWidth {
    self.shadowOffset = CGSizeMake(lks_shadowOffsetWidth, self.shadowOffset.height);
}

- (CGFloat)lks_shadowOffsetHeight {
    return self.shadowOffset.height;
}
- (void)setLks_shadowOffsetHeight:(CGFloat)lks_shadowOffsetHeight {
    self.shadowOffset = CGSizeMake(self.shadowOffset.width, lks_shadowOffsetHeight);
}

@end

#endif /* SHOULD_COMPILE_LOOKIN_SERVER */
