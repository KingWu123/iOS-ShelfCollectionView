//
//  BookShelfGroupViewFlowLayout.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/18/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "BookShelfGroupViewFlowLayout.h"
#import <objc/runtime.h>


#ifndef BOOKSHELF_GROUP_SUPPPORT_H_

CG_INLINE CGPoint BG_CGPointAdd (CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
}
#endif


typedef NS_ENUM(NSInteger, BookGroupScrollingDirection) {
    BookGroupScrollingDirectionUnknown = 0,
    BookGroupScrollingDirectionUp,
    BookGroupScrollingDirectionDown,
    BookGroupScrollingDirectionLeft,
    BookGroupScrollingDirectionRight
};


/**
 *  CADisplayLink add an userInfo
 */
@interface CADisplayLink (BG_userInfo)
@property (nonatomic, copy) NSDictionary *BG_userInfo;
@end

@implementation CADisplayLink (BG_userInfo)
- (void) setBG_userInfo:(NSDictionary *) BG_userInfo {
    objc_setAssociatedObject(self, "BG_userInfo", BG_userInfo, OBJC_ASSOCIATION_COPY);
}

- (NSDictionary *) BG_userInfo {
    return objc_getAssociatedObject(self, "BG_userInfo");
}
@end



/**
 *  UICollectionViewCell snapShotView
 */
@interface UICollectionViewCell(BookshelfCollectionViewFlowLayout)
- (UIView *)BG_snapShotView;
@end

@implementation UICollectionViewCell (BookshelfCollectionViewFlowLayout)

- (UIView *)BG_snapShotView{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.isOpaque, 0.0f);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [[UIImageView alloc] initWithImage:image];
}

@end


static NSString * const kBSScrollingDirectionKey = @"ShelfBookScrollingDirection";
static NSString * const kBSCollectionViewKeyPath = @"collectionView";


#pragma mark - BookShelfGroupViewFlowLayout

/**
 *  分组界面只有reorder的功能
 */
@interface BookShelfGroupViewFlowLayout()<UIGestureRecognizerDelegate>

@property (nonatomic, weak) UIView *selectedSnapShotViewParentView; //选中的item的父view
@property (nonatomic, strong) NSIndexPath *selectedItemCurrentIndexPath;//选中的item当前的IndexPath
@property (nonatomic, strong) UIView* selectedSnapShotView;//选中的item的snapShotView
@property (nonatomic, assign) CGPoint snapShotViewScrollingCenter;//标记最初的selectedSnapShotView.center + scrollview.offset的值
@property (nonatomic, assign) CGPoint snapShotViewPanTranslation;//pan手势滑动的距离

@property (nonatomic, assign) CGFloat scrollingSpeed;//拖动item时滑动的速度
@property (nonatomic, assign) UIEdgeInsets scrollingTriggerEdgeInsets;//触发滑动的范围
@property (strong, nonatomic) CADisplayLink *displayLink;


@property (strong, nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (strong, nonatomic) UIPanGestureRecognizer *panGestureRecognizer;


@property (assign, nonatomic, readonly) id<BookShelfGroupViewDataSource> dataSource;
@property (assign, nonatomic, readonly) id<BookShelfGroupViewDelegateFlowLayout> delegate;

@property (assign, nonatomic)BOOL isCanExit;//标记是否可以退出

@end


@implementation BookShelfGroupViewFlowLayout

#pragma mark - init
- (instancetype)init{
    self = [super init];
    if (self){
        [self initCommon];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self){
        [self initCommon];
        
    }
    return self;
}

- (void)dealloc{
    [self invalidatesScrollTimer];
    
}

- (void)initCommon{

    self.isCanExit = YES;
    
    self.scrollingSpeed = 200.f;
    self.scrollingTriggerEdgeInsets = _scrollingTriggerEdgeInsets = UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f);
}

- (id<BookShelfGroupViewDataSource>)dataSource {
    return (id<BookShelfGroupViewDataSource>)self.collectionView.dataSource;
}

- (id<BookShelfGroupViewDelegateFlowLayout>)delegate {
    return (id<BookShelfGroupViewDelegateFlowLayout>)self.collectionView.delegate;
}

//进入分组界面时， 手势是从底下的书架界面传上来的，因此不会从longPress手势对选中的item进行snapView的初始化，需要自己初始化
- (void)initSelectSnapShotViewIfNeeded:(UIView *)snapShotView selectedIndexPath:(NSIndexPath *)selectedIndexPath{

    self.selectedItemCurrentIndexPath = selectedIndexPath;
    self.selectedSnapShotView = snapShotView;
    self.snapShotViewScrollingCenter = self.selectedSnapShotView.center;
    
    self.selectedSnapShotView.transform = CGAffineTransformIdentity;
    __weak typeof(self) weakSelf = self;
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf){
                strongSelf.selectedSnapShotView.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
            }
        } completion:^(BOOL finished) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
            }
        }];
    
    
    //如果一进来，snapshotView的位置就处于collectionView的外部， 则标记一下，不要退出，当进入CollectionView，在移动出来时，才退出
    if ([self isOutSideScrollViewFrame]){
        self.isCanExit = NO;
    }
    
}
    
    
#pragma mark - adjust seletectItemCell
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    if ([layoutAttributes.indexPath isEqual:self.selectedItemCurrentIndexPath]) {
        layoutAttributes.hidden = YES;
    }
}

- (void)invalidatesScrollTimer {
    if (!self.displayLink.paused) {
        [self.displayLink invalidate];
    }
    self.displayLink = nil;
}

//滚动的更新
- (void)setupScrollTimerInDirection:(BookGroupScrollingDirection)direction {
    if (!self.displayLink.paused) {
        BookGroupScrollingDirection oldDirection = [self.displayLink.BG_userInfo[kBSScrollingDirectionKey] integerValue];
        
        if (direction == oldDirection) {
            return;
        }
    }
    
    [self invalidatesScrollTimer];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleScroll:)];
    self.displayLink.BG_userInfo = @{ kBSScrollingDirectionKey : @(direction) };
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
}

//判断选中的item是否要换到新的位置或进行分组
- (void)ajustItemIndexpathIfNecessary {
    
    //CGPoint currentPostion = [self.panGestureRecognizer locationInView:self.collectionView];
    CGPoint currentPostion = [self convertScreenPositionToScrollPostion:self.selectedSnapShotView.center inScrollView:self.collectionView inScreenView:self.selectedSnapShotViewParentView];
    
    
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:currentPostion];
    NSIndexPath *previousIndexPath = self.selectedItemCurrentIndexPath;
    
    
    if (newIndexPath != nil && ![newIndexPath isEqual:previousIndexPath]) {
       
        //交换数据
        if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(collectionView:moveItemAtIndexPath:toIndexPath:)]){
            [self.dataSource collectionView:self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:newIndexPath];
        }
        
        self.selectedItemCurrentIndexPath = newIndexPath;
        [self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:newIndexPath];
        
        
    }else if (newIndexPath == nil){
        
        //判断是否到最下边、或最右边，如果是，放在最后一个
        CGPoint snapShotViewCenterInScorllView = [self convertScreenPositionToScrollPostion:self.selectedSnapShotView.center inScrollView:self.collectionView inScreenView:self.selectedSnapShotViewParentView];
        
        if ( (self.scrollDirection == UICollectionViewScrollDirectionVertical && (snapShotViewCenterInScorllView.y> self.collectionView.contentSize.height - self.selectedSnapShotView.frame.size.height))
            
            || (self.scrollDirection == UICollectionViewScrollDirectionHorizontal && (snapShotViewCenterInScorllView.x > self.collectionView.contentSize.width - self.selectedSnapShotView.frame.size.width)))
        {
            
            NSInteger lastSection = [self.collectionView numberOfSections] - 1;
            NSInteger lastRow = [self.collectionView numberOfItemsInSection:lastSection] - 1;
            NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:lastRow inSection:lastSection];
            
            
            if (![self.selectedItemCurrentIndexPath isEqual:lastIndexPath]){
                
                //交换数据
                if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(collectionView:moveItemAtIndexPath:toIndexPath:)]){
                    [self.dataSource collectionView:self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:lastIndexPath];
                }
                
                self.selectedItemCurrentIndexPath = lastIndexPath;
                [self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:lastIndexPath];

            }
        }
    }
    
}

//判断位置是否在分组的item frame 范围内
- (BOOL)checkPostion:(CGPoint )postion inGroupIndexItemFrame:(CGRect)itemframe{
    if( postion.x > itemframe.origin.x + itemframe.size.width * 0.3
       && postion.x < itemframe.origin.x + itemframe.size.width * 0.7
       && postion.y > itemframe.origin.y + itemframe.size.height * 0.2
       && postion.y < itemframe.origin.y + itemframe.size.height * 0.8){
        return YES;
    }else{
        return NO;
    }
}


#pragma mark - gesture
- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer{
    
    if (self.selectedSnapShotViewParentView == nil){
        self.selectedSnapShotViewParentView = self.collectionView.window.rootViewController.view;
    }
    if (self.longPressGestureRecognizer == nil){
        self.longPressGestureRecognizer = recognizer;
    }
    
    if (recognizer.state == UIGestureRecognizerStateBegan){
        
        CGPoint location = [recognizer locationInView:self.collectionView];
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
        if (indexPath == nil){
            return;
        }
        
        self.selectedItemCurrentIndexPath = indexPath;
        
        //begin movement
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(collectionView:layout:beginMovementForItemAtIndexPath:)]){
            [self.delegate collectionView:self.collectionView layout:self beginMovementForItemAtIndexPath:indexPath];
        }
        
        //snapshot view
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        
        CGPoint orginPos = [self convertScrollPositionToScreenPostion:cell.frame.origin inScrollView:self.collectionView inScreenView:self.selectedSnapShotViewParentView];
        self.selectedSnapShotView = [[UIView alloc] initWithFrame:CGRectMake(orginPos.x, orginPos.y, cell.frame.size.width, cell.frame.size.height)];
        UIView *imageView = [cell BG_snapShotView];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.selectedSnapShotView addSubview:imageView];
        [self.selectedSnapShotViewParentView addSubview:self.selectedSnapShotView];
        
        self.snapShotViewScrollingCenter = self.selectedSnapShotView.center;
        
        __weak typeof(self) weakSelf = self;
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf){
                strongSelf.selectedSnapShotView.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
            }
        } completion:^(BOOL finished) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
            }
        }];
        
        [self invalidateLayout];
        
    }else if (recognizer.state == UIGestureRecognizerStateCancelled
              || recognizer.state == UIGestureRecognizerStateEnded){
        
        if (self.selectedItemCurrentIndexPath == nil){
            return;
        }
        
        
        NSIndexPath *currentIndexPath = self.selectedItemCurrentIndexPath;
        self.selectedItemCurrentIndexPath  = nil;
        self.snapShotViewScrollingCenter = CGPointZero;
        
        UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForItemAtIndexPath:currentIndexPath];
        
        self.longPressGestureRecognizer.enabled = NO;
        
        __weak typeof(self) weakSelf = self;
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf){
                
                strongSelf.selectedSnapShotView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
                CGPoint destCenter = [self convertScrollPositionToScreenPostion:layoutAttributes.center inScrollView:self.collectionView inScreenView:self.selectedSnapShotViewParentView];
                strongSelf.selectedSnapShotView.center = destCenter;
            }
            
        } completion:^(BOOL finished) {
            self.longPressGestureRecognizer.enabled = YES;
            
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf){
                [strongSelf.selectedSnapShotView removeFromSuperview];
                strongSelf.selectedSnapShotView = nil;
                [strongSelf invalidateLayout];
                
                //end movement
                if (strongSelf.delegate != nil && [strongSelf.delegate respondsToSelector:@selector(collectionView:layout:endMovementForItemAtIndexPath:)]){
                    [strongSelf.delegate collectionView:strongSelf.collectionView layout:strongSelf beginMovementForItemAtIndexPath:currentIndexPath];
                }
            }
            
        }];
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer{
    if (self.selectedSnapShotViewParentView == nil){
        self.selectedSnapShotViewParentView = self.collectionView.window.rootViewController.view;
    }
    if (self.panGestureRecognizer == nil){
        self.panGestureRecognizer = gestureRecognizer;
        [self.panGestureRecognizer setTranslation:CGPointZero inView:self.selectedSnapShotViewParentView];
    }
    if (self.selectedSnapShotView == nil){
        return;
    }
    
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged: {
            
            if (!self.isCanExit && [self isInScrollViewFrame]){
                self.isCanExit = YES;
            }
            //如果在在scrollView之外，则退出
            if ([self checkOutSideofCollectionViewToExit]){
                return;
            }
            
            //pan translation
             self.snapShotViewPanTranslation = [gestureRecognizer translationInView:self.selectedSnapShotViewParentView];
            
            CGPoint velocity =[gestureRecognizer velocityInView:self.selectedSnapShotViewParentView];

            
            //update snapshotView center
            CGPoint viewCenter = self.selectedSnapShotView.center = BG_CGPointAdd(self.snapShotViewScrollingCenter, self.snapShotViewPanTranslation);
            
            [self ajustItemIndexpathIfNecessary];
            
            CGFloat width = self.selectedSnapShotView.frame.size.width;
            CGFloat hegiht = self.selectedSnapShotView.frame.size.height;
            switch (self.scrollDirection) {
                case UICollectionViewScrollDirectionVertical: {
                    
                    CGFloat topExceedY = (viewCenter.y - hegiht/2) - (CGRectGetMinY(self.collectionView.frame) - self.scrollingTriggerEdgeInsets.top);
                    CGFloat bottomExceedtY = (viewCenter.y + hegiht/2) - (CGRectGetMaxY(self.collectionView.frame) + self.scrollingTriggerEdgeInsets.bottom);
                    
                    if (topExceedY < 0 && velocity.y < 0) {
                        [self caculateScrollSpeed:topExceedY];
                        [self setupScrollTimerInDirection:BookGroupScrollingDirectionUp];
                        
                    } else if (bottomExceedtY > 0 && velocity.y > 0) {
                        [self caculateScrollSpeed:bottomExceedtY];
                        [self setupScrollTimerInDirection:BookGroupScrollingDirectionDown];
                        
                    }else {
                        [self invalidatesScrollTimer];
                    }
                } break;
                case UICollectionViewScrollDirectionHorizontal: {
                    
                    CGFloat leftExceedX = (viewCenter.x - width/2) - (CGRectGetMinX(self.collectionView.frame) - self.scrollingTriggerEdgeInsets.left);
                    CGFloat rightExceedX = viewCenter.x + width/2 -  (CGRectGetMaxX(self.collectionView.frame) + self.scrollingTriggerEdgeInsets.right);
                    
                    if (leftExceedX < 0 && velocity.x < 0) {
                        [self caculateScrollSpeed:leftExceedX];
                        [self setupScrollTimerInDirection:BookGroupScrollingDirectionLeft];
                        
                    } else if (rightExceedX > 0 && velocity.x > 0) {
                        [self caculateScrollSpeed:rightExceedX];
                        [self setupScrollTimerInDirection:BookGroupScrollingDirectionRight];
                        
                    } else {
                        [self invalidatesScrollTimer];
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
    
    BookGroupScrollingDirection direction = (BookGroupScrollingDirection)[displayLink.BG_userInfo[kBSScrollingDirectionKey] integerValue];
    if (direction == BookGroupScrollingDirectionUnknown) {
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
        case BookGroupScrollingDirectionUp: {
            distance = -distance;
            CGFloat minY = 0.0f - contentInset.top;
            
            if ((contentOffset.y + distance) <= minY) {
                distance = -contentOffset.y - contentInset.top;
            }
            
            translation = CGPointMake(0.0f, distance);
        } break;
        case BookGroupScrollingDirectionDown: {
            CGFloat maxY = MAX(contentSize.height, frameSize.height) - frameSize.height + contentInset.bottom;
            
            if ((contentOffset.y + distance) >= maxY) {
                distance = maxY - contentOffset.y;
            }
            
            translation = CGPointMake(0.0f, distance);
        } break;
        case BookGroupScrollingDirectionLeft: {
            distance = -distance;
            CGFloat minX = 0.0f - contentInset.left;
            
            if ((contentOffset.x + distance) <= minX) {
                distance = -contentOffset.x - contentInset.left;
            }
            
            translation = CGPointMake(distance, 0.0f);
        } break;
        case BookGroupScrollingDirectionRight: {
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
    
    self.collectionView.contentOffset = BG_CGPointAdd(contentOffset, translation);
    
    [self ajustItemIndexpathIfNecessary];
}

//根据超出的距离，滚动的速度有个变化
- (void)caculateScrollSpeed:(CGFloat)exceedDistance{
    
    self.scrollingSpeed = ABS(exceedDistance) * 5 + 200;
}

//如果在在scrollView之外，则退出
- (BOOL)checkOutSideofCollectionViewToExit{
    
    
    if ([self isOutSideScrollViewFrame] && self.isCanExit){
        if ([self.delegate respondsToSelector:@selector(cancelGroupSelectedItemAtIndexPath:withSnapShotView:)]){
            [self.delegate cancelGroupSelectedItemAtIndexPath:self.selectedItemCurrentIndexPath withSnapShotView:self.selectedSnapShotView];
        }
        [self invalidatesScrollTimer];
        return YES;
    }else{
        return NO;
    }
}

- (BOOL)isOutSideScrollViewFrame{
    
    if (self.selectedSnapShotView.center.y > CGRectGetMaxY(self.collectionView.frame)){
        return YES;
    }else{
        return NO;
    }
}

- (BOOL)isInScrollViewFrame{
    if (self.selectedSnapShotView.center.y < CGRectGetMaxY(self.collectionView.frame)
        && self.selectedSnapShotView.center.y > CGRectGetMinY(self.collectionView.frame)){
        return YES;
    }else{
        return NO;
    }
}


#pragma mark - UICollectionViewLayout overridden methods
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    
    NSArray *layoutAttributes = [super layoutAttributesForElementsInRect:rect];
    
    for (UICollectionViewLayoutAttributes *attribute in layoutAttributes) {
        switch (attribute.representedElementCategory) {
            case UICollectionElementCategoryCell: {
                [self applyLayoutAttributes:attribute];
            } break;
            default: {
                // Do nothing...
            } break;
        }
    }
    
    
    
    return layoutAttributes;
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

//使每个item的frame 上对齐
- (NSArray *)alignTopLayoutAttributesForElements:(NSArray *)originAttributes;
{
    //use this init method can close mismatch warnning
    //NSArray *attrs = [[NSArray alloc] initWithArray:originAttributes copyItems:YES];
    NSArray *attrs = originAttributes;
    CGFloat baseline = -2;
    NSMutableArray *sameLineElements = [NSMutableArray array];
    
    for (UICollectionViewLayoutAttributes *element in attrs) {
        if (element.representedElementCategory == UICollectionElementCategoryCell) {
            CGRect frame = element.frame;
            CGFloat centerY = CGRectGetMidY(frame);
            if (ABS(centerY - baseline) > 1) {
                baseline = centerY;
                [self alignToTopForSameLineElements:sameLineElements];
                [sameLineElements removeAllObjects];
            }
            [sameLineElements addObject:element];
        }
    }
    [self alignToTopForSameLineElements:sameLineElements];//align one more time for the last line
    return attrs;
}

- (void)alignToTopForSameLineElements:(NSArray *)sameLineElements
{
    if (sameLineElements.count == 0) {
        return;
    }
    NSArray *sorted = [sameLineElements sortedArrayUsingComparator:^NSComparisonResult(UICollectionViewLayoutAttributes *obj1, UICollectionViewLayoutAttributes *obj2) {
        CGFloat height1 = obj1.frame.size.height;
        CGFloat height2 = obj2.frame.size.height;
        CGFloat delta = height1 - height2;
        return delta == 0. ? NSOrderedSame : ABS(delta)/delta;
    }];
    UICollectionViewLayoutAttributes *tallest = [sorted lastObject];
    [sameLineElements enumerateObjectsUsingBlock:^(UICollectionViewLayoutAttributes *obj, NSUInteger idx, BOOL *stop) {
        obj.frame = CGRectOffset(obj.frame, 0, tallest.frame.origin.y - obj.frame.origin.y);
    }];
}


#pragma mark - postion
//collectionview的view的坐标 转换到屏幕上的坐标
- (CGPoint)convertScrollPositionToScreenPostion:(CGPoint)scrollPostion  inScrollView:(UIScrollView *)scrollView inScreenView:(UIView *)screenView {
    
    return [scrollView convertPoint:scrollPostion toView:screenView];
    
}

//屏幕上的坐标 转到collcetion中的坐标
- (CGPoint)convertScreenPositionToScrollPostion:(CGPoint)screenPostion  inScrollView:(UIScrollView *)scrollView  inScreenView:(UIView *)screenView{
    
    return [screenView convertPoint:screenPostion toView:scrollView];
}

@end
