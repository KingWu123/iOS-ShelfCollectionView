//
//  BookshelfCollectionViewFlowLayout.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/16/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "BookshelfCollectionViewFlowLayout.h"
#import <objc/runtime.h>



#ifndef BOOKSHELF_SUPPPORT_H_
CG_INLINE CGPoint BS_CGPointAdd (CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
}
#endif


typedef NS_ENUM(NSInteger, BookShelfScrollingDirection) {
    BookShelfScrollingDirectionUnknown = 0,
    BookShelfScrollingDirectionUp,
    BookShelfScrollingDirectionDown,
    BookShelfScrollingDirectionLeft,
    BookShelfScrollingDirectionRight
};


/**
 *  CADisplayLink add an userInfo
 */
@interface CADisplayLink (BS_userInfo)
@property (nonatomic, copy) NSDictionary *BS_userInfo;
@end

@implementation CADisplayLink (BS_userInfo)
- (void) setBS_userInfo:(NSDictionary *) BS_userInfo {
    objc_setAssociatedObject(self, "BS_userInfo", BS_userInfo, OBJC_ASSOCIATION_COPY);
}

- (NSDictionary *) BS_userInfo {
    return objc_getAssociatedObject(self, "BS_userInfo");
}
@end



/**
 *  UICollectionViewCell snapShotView
 */
@interface UICollectionViewCell(BookshelfCollectionViewFlowLayout)
- (UIView *)BS_snapShotView;
@end

@implementation UICollectionViewCell (BookshelfCollectionViewFlowLayout)

- (UIView *)BS_snapShotView{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.isOpaque, 0.0f);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [[UIImageView alloc] initWithImage:image];
}

@end


static NSString * const kBSScrollingDirectionKey = @"ShelfBookScrollingDirection";
static NSString * const kBSCollectionViewKeyPath = @"collectionView";



#pragma mark - BookshelfCollectionViewFlowLayout

/**
 *  实现一个类似于能够对书籍进行排序， 分组功能的的书架功能，类似于iphone手机界面对应用图标进行排序，分组。
 */
@interface BookshelfCollectionViewFlowLayout()<UIGestureRecognizerDelegate>

@property (nonatomic, strong) NSIndexPath *selectedItemOrignIndexPath;//选中的item最初的indexPath
@property (nonatomic, strong) NSIndexPath *selectedItemCurrentIndexPath;//选中的item当前的IndexPath
@property (nonatomic, strong) UIView* selectedSnapShotView;//选中的item的snapShotView
@property (nonatomic, assign) CGPoint snapShotViewScrollingCenter;//标记最初的selectedSnapShotView.center + scrollview.offset的值
@property (nonatomic, assign) CGPoint snapShotViewPanTranslation;

@property (nonatomic, assign) CGFloat scrollingSpeed;//拖动item时滑动的速度
@property (nonatomic, assign) UIEdgeInsets scrollingTriggerEdgeInsets;//触发滑动的范围
@property (strong, nonatomic) CADisplayLink *displayLink;

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (strong, nonatomic) UIPanGestureRecognizer *panGestureRecognizer;


@property (assign, nonatomic, readonly) id<BookShelfCollectionViewDataSource> dataSource;
@property (assign, nonatomic, readonly) id<BookShelfCollectionViewDelegateFlowLayout> delegate;
@end


@implementation BookshelfCollectionViewFlowLayout

#pragma mark - init
- (instancetype)init{
    self = [super init];
    if (self){
        [self initCommon];
        
        [self registerKVO];
        [self registerNotification];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self){
        [self initCommon];
        
        [self registerKVO];
        [self registerNotification];
    }
    return self;
}

- (void)dealloc{
    [self invalidatesScrollTimer];
    
    [self removeGesture];
    
    [self unRegisterKVO];
    [self unRegisterNotification];
}

- (void)initCommon{
    self.scrollingSpeed = 300.f;
    self.scrollingTriggerEdgeInsets = _scrollingTriggerEdgeInsets = UIEdgeInsetsMake(20.0f, 20.0f, 20.0f, 20.0f);
}


- (id<BookShelfCollectionViewDataSource>)dataSource {
    return (id<BookShelfCollectionViewDataSource>)self.collectionView.dataSource;
}

- (id<BookShelfCollectionViewDelegateFlowLayout>)delegate {
    return (id<BookShelfCollectionViewDelegateFlowLayout>)self.collectionView.delegate;
}


#pragma makr - adjust seletectItemCell
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    if ([layoutAttributes.indexPath isEqual:self.selectedItemCurrentIndexPath]) {
        layoutAttributes.hidden = YES;
    }
}

- (void)invalidateLayoutIfNecessary {
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:self.selectedSnapShotView.center];
    NSIndexPath *previousIndexPath = self.selectedItemCurrentIndexPath;
    
    if ((newIndexPath == nil) || [newIndexPath isEqual:previousIndexPath]) {
        return;
    }
    
    
    self.selectedItemCurrentIndexPath = newIndexPath;
    [self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:newIndexPath];
    
}

- (void)invalidatesScrollTimer {
    if (!self.displayLink.paused) {
        [self.displayLink invalidate];
    }
    self.displayLink = nil;
}

- (void)setupScrollTimerInDirection:(BookShelfScrollingDirection)direction {
    if (!self.displayLink.paused) {
        BookShelfScrollingDirection oldDirection = [self.displayLink.BS_userInfo[kBSScrollingDirectionKey] integerValue];
        
        if (direction == oldDirection) {
            return;
        }
    }
    
    [self invalidatesScrollTimer];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleScroll:)];
    self.displayLink.BS_userInfo = @{ kBSScrollingDirectionKey : @(direction) };
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}


#pragma mark - gesture

- (void)addGesture{
    
    if (self.longPressGestureRecognizer == nil){
        self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(handleLongPressGesture:)];
        self.longPressGestureRecognizer.delegate = self;
        
        //forbidden other long press gesture
        for (UIGestureRecognizer *gestureRecognizer in self.collectionView.gestureRecognizers) {
            if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
                [gestureRecognizer requireGestureRecognizerToFail:self.longPressGestureRecognizer];
            }
        }
        
        [self.collectionView addGestureRecognizer:self.longPressGestureRecognizer];
    }
    
    if (self.panGestureRecognizer == nil){
        self.panGestureRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(handlePanGesture:)];
        self.panGestureRecognizer.delegate = self;
        [self.collectionView addGestureRecognizer:self.panGestureRecognizer];
    
    }
    
}
- (void)removeGesture{
    if (self.longPressGestureRecognizer){
        UIView *view = self.longPressGestureRecognizer.view;
        if (view){
            [view removeGestureRecognizer:self.longPressGestureRecognizer];
        }
        self.longPressGestureRecognizer.delegate = nil;
        self.longPressGestureRecognizer = nil;
    }
    
    if (self.panGestureRecognizer){
        UIView *view = self.panGestureRecognizer.view;
        if (view){
            [view removeGestureRecognizer:self.panGestureRecognizer];
        }
        self.panGestureRecognizer.delegate = nil;
        self.panGestureRecognizer = nil;
    }
}



- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer{
    if (recognizer.state == UIGestureRecognizerStateBegan){
        
        CGPoint location = [recognizer locationInView:self.collectionView];
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
        
        self.selectedItemCurrentIndexPath = self.selectedItemOrignIndexPath = indexPath;
        
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        self.selectedSnapShotView = [[UIView alloc] initWithFrame:cell.frame];
        
        UIView *imageView = [cell BS_snapShotView];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.selectedSnapShotView addSubview:imageView];
        
        [self.collectionView addSubview:self.selectedSnapShotView];
        
        self.snapShotViewScrollingCenter = self.selectedSnapShotView.center;
        
        [self invalidateLayout];
        
    }else if (recognizer.state == UIGestureRecognizerStateCancelled
              || recognizer.state == UIGestureRecognizerStateEnded){
        
         NSIndexPath *currentIndexPath = self.selectedItemCurrentIndexPath;
        
        //indexPath changed, exchange data
        if (![self.selectedItemOrignIndexPath isEqual:self.selectedItemCurrentIndexPath]){
           //--todo--
        }
        
        self.selectedItemCurrentIndexPath = self.selectedItemOrignIndexPath = nil;
        self.snapShotViewScrollingCenter = CGPointZero;
        
        UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForItemAtIndexPath:currentIndexPath];
        
        self.longPressGestureRecognizer.enabled = NO;
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.selectedSnapShotView.center = layoutAttributes.center;
            
        } completion:^(BOOL finished) {
            self.longPressGestureRecognizer.enabled = YES;
            
            [self.selectedSnapShotView removeFromSuperview];
            self.selectedSnapShotView = nil;
            [self invalidateLayout];
            
        }];
        
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer{
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged: {
            self.snapShotViewPanTranslation = [gestureRecognizer translationInView:self.collectionView];
           
            CGPoint viewCenter = self.selectedSnapShotView.center = BS_CGPointAdd(self.snapShotViewScrollingCenter, self.snapShotViewPanTranslation);
            
            [self invalidateLayoutIfNecessary];
            
            CGFloat width = self.selectedSnapShotView.frame.size.width;
            CGFloat hegiht = self.selectedSnapShotView.frame.size.height;
            switch (self.scrollDirection) {
                case UICollectionViewScrollDirectionVertical: {
                    if (viewCenter.y - hegiht/2 < (CGRectGetMinY(self.collectionView.bounds) - self.scrollingTriggerEdgeInsets.top)) {
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionUp];
                    } else {
                        if (viewCenter.y + hegiht/2 > (CGRectGetMaxY(self.collectionView.bounds) + self.scrollingTriggerEdgeInsets.bottom)) {
                            [self setupScrollTimerInDirection:BookShelfScrollingDirectionDown];
                        } else {
                            [self invalidatesScrollTimer];
                        }
                    }
                } break;
                case UICollectionViewScrollDirectionHorizontal: {
                    if (viewCenter.x - width/2 < (CGRectGetMinX(self.collectionView.bounds) - self.scrollingTriggerEdgeInsets.left)) {
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionLeft];
                    } else {
                        if (viewCenter.x + width/2 > (CGRectGetMaxX(self.collectionView.bounds) + self.scrollingTriggerEdgeInsets.right)) {
                            [self setupScrollTimerInDirection:BookShelfScrollingDirectionRight];
                        } else {
                            [self invalidatesScrollTimer];
                        }
                    }
                } break;
            }
        } break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            [self invalidatesScrollTimer];
        } break;
        default: {
        } break;
    }
}

- (void)handleScroll:(CADisplayLink *)displayLink{
    BookShelfScrollingDirection direction = (BookShelfScrollingDirection)[displayLink.BS_userInfo[kBSScrollingDirectionKey] integerValue];
    if (direction == BookShelfScrollingDirectionUnknown) {
        return;
    }
    
    CGSize frameSize = self.collectionView.bounds.size;
    CGSize contentSize = self.collectionView.contentSize;
    CGPoint contentOffset = self.collectionView.contentOffset;
    UIEdgeInsets contentInset = self.collectionView.contentInset;
    // Important to have an integer `distance` as the `contentOffset` property automatically gets rounded
    // and it would diverge from the view's center resulting in a "cell is slipping away under finger"-bug.
    CGFloat distance = rint(self.scrollingSpeed * displayLink.duration);
    CGPoint translation = CGPointZero;
    
    switch(direction) {
        case BookShelfScrollingDirectionUp: {
            distance = -distance;
            CGFloat minY = 0.0f - contentInset.top;
            
            if ((contentOffset.y + distance) <= minY) {
                distance = -contentOffset.y - contentInset.top;
            }
            
            translation = CGPointMake(0.0f, distance);
        } break;
        case BookShelfScrollingDirectionDown: {
            CGFloat maxY = MAX(contentSize.height, frameSize.height) - frameSize.height + contentInset.bottom;
            
            if ((contentOffset.y + distance) >= maxY) {
                distance = maxY - contentOffset.y;
            }
            
            translation = CGPointMake(0.0f, distance);
        } break;
        case BookShelfScrollingDirectionLeft: {
            distance = -distance;
            CGFloat minX = 0.0f - contentInset.left;
            
            if ((contentOffset.x + distance) <= minX) {
                distance = -contentOffset.x - contentInset.left;
            }
            
            translation = CGPointMake(distance, 0.0f);
        } break;
        case BookShelfScrollingDirectionRight: {
            CGFloat maxX = MAX(contentSize.width, frameSize.width) - frameSize.width + contentInset.right;
            
            if ((contentOffset.x + distance) >= maxX) {
                distance = maxX - contentOffset.x;
            }
            
            translation = CGPointMake(distance, 0.0f);
        } break;
        default: {
            // Do nothing...
        } break;
    }
    
    self.snapShotViewScrollingCenter = BS_CGPointAdd(self.snapShotViewScrollingCenter, translation);
    self.selectedSnapShotView.center = BS_CGPointAdd(self.snapShotViewScrollingCenter, self.snapShotViewPanTranslation);
    self.collectionView.contentOffset = BS_CGPointAdd(contentOffset, translation);
    
    [self invalidateLayoutIfNecessary];
}


#pragma mark - UICollectionViewLayout overridden methods

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    
    NSArray *layoutAttributesForElementsInRect = [super layoutAttributesForElementsInRect:rect];
    for (UICollectionViewLayoutAttributes *layoutAttributes in layoutAttributesForElementsInRect) {
        switch (layoutAttributes.representedElementCategory) {
            case UICollectionElementCategoryCell: {
                [self applyLayoutAttributes:layoutAttributes];
            } break;
            default: {
                // Do nothing...
            } break;
        }
    }
    
    return layoutAttributesForElementsInRect;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewLayoutAttributes *layoutAttributes = [super layoutAttributesForItemAtIndexPath:indexPath];
    
    switch (layoutAttributes.representedElementCategory) {
        case UICollectionElementCategoryCell: {
            [self applyLayoutAttributes:layoutAttributes];
        } break;
        default: {
            // Do nothing...
        } break;
    }
    
    return layoutAttributes;
}

#pragma mark - UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([self.panGestureRecognizer isEqual:gestureRecognizer]) {
        return (self.selectedItemOrignIndexPath != nil);
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([self.longPressGestureRecognizer isEqual:gestureRecognizer]) {
        return [self.panGestureRecognizer isEqual:otherGestureRecognizer];
    }
    
    if ([self.panGestureRecognizer isEqual:gestureRecognizer]) {
        return [self.longPressGestureRecognizer isEqual:otherGestureRecognizer];
    }
    
    return NO;
}

#pragma mark - kvo
- (void)registerKVO{
    [self addObserver:self forKeyPath:kBSCollectionViewKeyPath options:NSKeyValueObservingOptionNew context:nil];
}

- (void)unRegisterKVO{
    [self removeObserver:self forKeyPath:kBSCollectionViewKeyPath];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kBSCollectionViewKeyPath]) {
        if (self.collectionView != nil) {
            [self addGesture];
        } else {
            [self invalidatesScrollTimer];
            [self removeGesture];
        }
    }
}
#pragma mark - notification
- (void)registerNotification{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillResignActive:) name: UIApplicationWillResignActiveNotification object:nil];
}
- (void)unRegisterNotification{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    
}

- (void)handleApplicationWillResignActive:(NSNotification *)notification {
    if (self.panGestureRecognizer){
        self.panGestureRecognizer.enabled = NO;
        self.panGestureRecognizer.enabled = YES;
    }
}



@end



