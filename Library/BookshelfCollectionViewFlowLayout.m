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
 *  实现一个类似于能够对书籍进行排序、分组功能的的书架功能，类似于iphone手机界面对应用图标进行排序、分组。
 */
@interface BookshelfCollectionViewFlowLayout()<UIGestureRecognizerDelegate>

@property (nonatomic, strong) NSIndexPath *selectedItemOrignIndexPath;//选中的item最初的indexPath
@property (nonatomic, strong) NSIndexPath *selectedItemCurrentIndexPath;//选中的item当前的IndexPath
@property (nonatomic, strong) UIView* selectedSnapShotView;//选中的item的snapShotView
@property (nonatomic, assign) CGPoint snapShotViewScrollingCenter;//标记最初的selectedSnapShotView.center + scrollview.offset的值
@property (nonatomic, assign) CGPoint snapShotViewPanTranslation;//pan手势滑动的距离

@property (nonatomic, assign) CGFloat scrollingSpeed;//拖动item时滑动的速度
@property (nonatomic, assign) UIEdgeInsets scrollingTriggerEdgeInsets;//触发滑动的范围
@property (strong, nonatomic) CADisplayLink *displayLink;

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (strong, nonatomic) UIPanGestureRecognizer *panGestureRecognizer;


@property (assign, nonatomic, readonly) id<BookShelfCollectionViewDataSource> dataSource;
@property (assign, nonatomic, readonly) id<BookShelfCollectionViewDelegateFlowLayout> delegate;


@property (assign, nonatomic)BOOL isGroupBeginSucceed;
@property (strong, nonatomic) NSTimer *groupConditionStageOneTimer;//分组满足条件阶段1定时器
@property (strong, nonatomic) NSTimer *groupConditionStageTwoTimer;//分组满足条件阶段2定时器

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
    [self removeGroupConditionTimer];
    
    [self removeGesture];
    
    [self unRegisterKVO];
    [self unRegisterNotification];
}

- (void)initCommon{
    self.isGroupBeginSucceed = NO;
    
    _reorderEnabled = YES;
    _groupEnabled = NO;
    self.scrollingSpeed = 300.f;
    self.scrollingTriggerEdgeInsets = _scrollingTriggerEdgeInsets = UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f);
}


- (id<BookShelfCollectionViewDataSource>)dataSource {
    return (id<BookShelfCollectionViewDataSource>)self.collectionView.dataSource;
}

- (id<BookShelfCollectionViewDelegateFlowLayout>)delegate {
    return (id<BookShelfCollectionViewDelegateFlowLayout>)self.collectionView.delegate;
}


//reorderEnabled set method
- (void)setReorderEnabled:(BOOL)reorderEnabled{
    _reorderEnabled = reorderEnabled;
    
    reorderEnabled ? [self addGesture] : [self removeGesture];
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



//判断选中的item是否要换到新的位置或进行分组
- (void)ajustItemIndexpathIfNecessary {

    BOOL selectedItemIsGrouped = [self.dataSource respondsToSelector:@selector(collectionView:isGroupedItemAtIndexPath:)] ?  [self.dataSource collectionView:self.collectionView isGroupedItemAtIndexPath:self.selectedItemOrignIndexPath] : NO;
    
    CGPoint currentPostion = [self.panGestureRecognizer locationInView:self.collectionView];
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:currentPostion];
    NSIndexPath *previousIndexPath = self.selectedItemCurrentIndexPath;
    
    //如果新的位置不存在，则可能是滑到底边了，不可能是进行分组，直接进行排序尝试
    if (newIndexPath == nil){
        [self reorderItemFromIndexPath:previousIndexPath toIndexPath:newIndexPath];
        return;
    }else if ([previousIndexPath isEqual:newIndexPath]){
        //indexPath没有变化，直接退出
        return;
    }
    
    
    CGRect newIndexPathItemFrame = [self.collectionView cellForItemAtIndexPath:newIndexPath].frame;
    
    //如果选中的item是分组，或者分组功能关闭了，则直接进行排序尝试
    if (selectedItemIsGrouped || !self.groupEnabled){
       
        if (currentPostion.x > newIndexPathItemFrame.size.width/8){
            [self reorderItemFromIndexPath:previousIndexPath toIndexPath:newIndexPath];
        }
        
    }else{
        
        //如果手指的位置 在新的itemFrame的 0.3---0.7 范围内，且停留在那里的时间满足要求， 则进行分组流程处理
        if ([self checkPostion:currentPostion inGroupIndexItemFrame:newIndexPathItemFrame]){
            
            //如果分组开始没有成功， 且没有加入分组定时器的判断，则加入阶段一定时器
            if (!self.isGroupBeginSucceed
                && self.groupConditionStageOneTimer == nil
                && self.groupConditionStageTwoTimer == nil){
                
                self.groupConditionStageOneTimer =  [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(willBeginGroup:) userInfo:newIndexPath repeats:NO];
                [[NSRunLoop currentRunLoop] addTimer:self.groupConditionStageOneTimer forMode:NSRunLoopCommonModes];
            }
            
        }else if (currentPostion.x > newIndexPathItemFrame.origin.x + newIndexPathItemFrame.size.width * 0.75){
            [self reorderItemFromIndexPath:previousIndexPath toIndexPath:newIndexPath];
            
            //分组条件只要不成立，都取消掉定时器
            [self removeGroupConditionTimer];
        }else{
            
            //分组条件只要不成立，都取消掉定时器
            [self removeGroupConditionTimer];
        }
    }
    
}


#pragma mark - reorder
//reorder操作
- (void)reorderItemFromIndexPath:(NSIndexPath *)previousIndexPath toIndexPath:(NSIndexPath *)newIndexPath{
    
    
    if (newIndexPath != nil && ![newIndexPath isEqual:previousIndexPath]) {
        self.selectedItemCurrentIndexPath = newIndexPath;
        [self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:newIndexPath];
        
    }else if (newIndexPath == nil){
        
        //判断是否到最下边、或最右边，如果是，放在最后一个
        if ( (self.scrollDirection == UICollectionViewScrollDirectionVertical && (self.selectedSnapShotView.center.y > self.collectionView.contentSize.height - self.selectedSnapShotView.frame.size.height))
            
            || (self.scrollDirection == UICollectionViewScrollDirectionHorizontal && (self.selectedSnapShotView.center.x > self.collectionView.contentSize.width - self.selectedSnapShotView.frame.size.width)))
        {
            
            NSInteger lastSection = [self.collectionView numberOfSections] - 1;
            NSInteger lastRow = [self.collectionView numberOfItemsInSection:lastSection] - 1;
            NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:lastRow inSection:lastSection];
            
            
            if (![self.selectedItemCurrentIndexPath isEqual:lastIndexPath]){
                self.selectedItemCurrentIndexPath = lastIndexPath;
                [self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:lastIndexPath];
            }
            
        }
    }

}

#pragma mark - group

//将要进入开始分组
- (void)willBeginGroup:(NSTimer *)timer{
    
    NSIndexPath *groupIndexPath = timer.userInfo;
    CGPoint currentPostion = [self.panGestureRecognizer locationInView:self.collectionView];
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:currentPostion];
    
    if ([newIndexPath isEqual:groupIndexPath]){
        
        UICollectionViewCell *groupCell = [self.collectionView cellForItemAtIndexPath:newIndexPath];
        CGRect groupPathItemFrame = groupCell.frame;
        
        //在分组范围内停留了时间满足
        if ([self checkPostion:currentPostion inGroupIndexItemFrame:groupPathItemFrame]){
            
            //将要进入分组处理阶段2
            self.groupConditionStageTwoTimer =  [NSTimer timerWithTimeInterval:1 target:self selector:@selector(didBeginGroup:) userInfo:groupIndexPath repeats:NO];
            [[NSRunLoop currentRunLoop] addTimer:self.groupConditionStageTwoTimer forMode:NSRunLoopCommonModes];
            
            //此时被分组的item 要变为分组view显示
            UIView *groupView = [self viewForGroupedItem:groupIndexPath];
            [groupCell addSubview:groupView];
            
            [self beginGroupItemBlink:groupIndexPath];
            
            NSLog(@"will begin Group");
        }
        
    }
    
    [self.groupConditionStageOneTimer invalidate];
    self.groupConditionStageOneTimer = nil;
}

//进入开始分组 失败
- (void)didBeginGroupFailed:(NSIndexPath *)groupIndexPath{
 
    [self endGroupItemBlink:groupIndexPath];
}

//进入开始分组处理
- (void)didBeginGroup:(NSTimer *)timer{

    
    NSIndexPath *groupIndexPath = timer.userInfo;
    CGPoint currentPostion = [self.panGestureRecognizer locationInView:self.collectionView];
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:currentPostion];
    
    [self endGroupItemBlink:groupIndexPath];
    
    if ([newIndexPath isEqual:groupIndexPath]){
        
        CGRect groupPathItemFrame = [self.collectionView cellForItemAtIndexPath:newIndexPath].frame;
        
        //在分组范围内停留了时间满足
        if ([self checkPostion:currentPostion inGroupIndexItemFrame:groupPathItemFrame]){
            
           
            
            NSLog(@"did begin Group");
            self.isGroupBeginSucceed = YES;
        }
        
    }
    
    
    [self.groupConditionStageTwoTimer invalidate];
    self.groupConditionStageTwoTimer = nil;
}



- (void)groupItemAtIndexPath:(NSIndexPath *)destIndexPath{
    NSLog(@"begin group");
}


//判断位置是否在分组的item frame 范围内
- (BOOL)checkPostion:(CGPoint )postion inGroupIndexItemFrame:(CGRect)itemframe{
    if( postion.x > itemframe.origin.x + itemframe.size.width * 0.2
       && postion.x < itemframe.origin.x + itemframe.size.width * 0.7
       && postion.y > itemframe.origin.y + itemframe.size.height * 0.3
       && postion.y < itemframe.origin.y + itemframe.size.height * 0.8){
        return YES;
    }else{
        return NO;
    }
}

- (UIView *)viewForGroupedItem:(NSIndexPath *)indexPath{
    
    
    if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(collectionView:viewForGroupItemAtIndexPath:)]){
        return [self.dataSource collectionView:self.collectionView viewForGroupItemAtIndexPath:indexPath];
    }
    
    
    if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(collectionView :isGroupedItemAtIndexPath:)]){
        //如果就是个groupview，则不要返回
        if ([self.dataSource collectionView:self.collectionView isGroupedItemAtIndexPath:indexPath]){
            return nil;
        }
    }
    
    UICollectionViewCell *groupCell = [self.collectionView cellForItemAtIndexPath:indexPath];
    UIView * grouView = [[UIView alloc]initWithFrame:groupCell.bounds];
    grouView.backgroundColor = [UIColor redColor];
    UIView *snapShot = [groupCell BS_snapShotView];
    snapShot.frame = CGRectMake(2, 2, groupCell.frame.size.width/3, groupCell.frame.size.height/3);
    [grouView addSubview:snapShot];
    return grouView;

    
}

- (void)beginGroupItemBlink:(NSIndexPath *)groupIndex{
    UIView *groupItem = [self.collectionView cellForItemAtIndexPath:groupIndex];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [animation setFromValue:[NSNumber numberWithFloat:1.0]];
    [animation setToValue:[NSNumber numberWithFloat:0.0]];
    [animation setDuration:0.5f];
    [animation setTimingFunction:[CAMediaTimingFunction
                                  functionWithName:kCAMediaTimingFunctionLinear]];
    [animation setAutoreverses:YES];
    [animation setRepeatCount:20000];
    [[groupItem layer] addAnimation:animation forKey:@"opacity"];
}

- (void)endGroupItemBlink:(NSIndexPath *)groupIndex{
    UIView *groupItem = [self.collectionView cellForItemAtIndexPath:groupIndex];
    [[groupItem layer] removeAnimationForKey:@"opacity"];
}

- (void)removeGroupConditionTimer{
    if (self.groupConditionStageOneTimer != nil){
        [self.groupConditionStageOneTimer invalidate];
        self.groupConditionStageOneTimer = nil;
    }
    if(self.groupConditionStageTwoTimer != nil){
        
        //如果进入了阶段而定时器，但此时有取消了定时器，需要告知 开始进入分组失败
        [self didBeginGroupFailed:self.groupConditionStageTwoTimer.userInfo];
        
        [self.groupConditionStageTwoTimer invalidate];
        self.groupConditionStageTwoTimer = nil;
    }
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
        
        //begin movement
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(collectionView:layout:beginMovementForItemAtIndexPath:)]){
            [self.delegate collectionView:self.collectionView layout:self beginMovementForItemAtIndexPath:indexPath];
        }
        
        //snapshot view
        UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
        self.selectedSnapShotView = [[UIView alloc] initWithFrame:cell.frame];
        UIView *imageView = [cell BS_snapShotView];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.selectedSnapShotView addSubview:imageView];
        [self.collectionView addSubview:self.selectedSnapShotView];
        
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
        
        //just need post change data delegate at the end of move
        if (![self.selectedItemOrignIndexPath isEqual:self.selectedItemCurrentIndexPath]){
           
            if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(collectionView:moveItemAtIndexPath:toIndexPath:)]){
                [self.dataSource collectionView:self.collectionView moveItemAtIndexPath:self.selectedItemOrignIndexPath toIndexPath:self.selectedItemCurrentIndexPath];
            }
        }
        
        
        NSIndexPath *currentIndexPath = self.selectedItemCurrentIndexPath;
        self.selectedItemCurrentIndexPath = self.selectedItemOrignIndexPath = nil;
        self.snapShotViewScrollingCenter = CGPointZero;
        
        UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForItemAtIndexPath:currentIndexPath];
        
        self.longPressGestureRecognizer.enabled = NO;
        
        __weak typeof(self) weakSelf = self;
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf){
                
                strongSelf.selectedSnapShotView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
                strongSelf.selectedSnapShotView.center = layoutAttributes.center;
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
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged: {
            
            //pan translation
            self.snapShotViewPanTranslation = [gestureRecognizer translationInView:self.collectionView];
           
            //update snapshotView center
            CGPoint viewCenter = self.selectedSnapShotView.center = BS_CGPointAdd(self.snapShotViewScrollingCenter, self.snapShotViewPanTranslation);
            
            [self ajustItemIndexpathIfNecessary];
            
            CGFloat width = self.selectedSnapShotView.frame.size.width;
            CGFloat hegiht = self.selectedSnapShotView.frame.size.height;
            switch (self.scrollDirection) {
                case UICollectionViewScrollDirectionVertical: {
                    
                    CGFloat topExceedY = (viewCenter.y - hegiht/2) - (CGRectGetMinY(self.collectionView.bounds) - self.scrollingTriggerEdgeInsets.top);
                    CGFloat bottomExceedtY = (viewCenter.y + hegiht/2) - (CGRectGetMaxY(self.collectionView.bounds) + self.scrollingTriggerEdgeInsets.bottom);
                    
                    if (topExceedY < 0) {
                        [self caculateScrollSpeed:topExceedY];
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionUp];
                        
                    } else if (bottomExceedtY > 0) {
                        [self caculateScrollSpeed:bottomExceedtY];
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionDown];
                        
                    }else {
                            [self invalidatesScrollTimer];
                    }
                } break;
                case UICollectionViewScrollDirectionHorizontal: {
                    
                    CGFloat leftExceedX = (viewCenter.x - width/2) - (CGRectGetMinX(self.collectionView.bounds) - self.scrollingTriggerEdgeInsets.left);
                    CGFloat rightExceedX = viewCenter.x + width/2 -  (CGRectGetMaxX(self.collectionView.bounds) + self.scrollingTriggerEdgeInsets.right);
                    
                    if (leftExceedX < 0) {
                        [self caculateScrollSpeed:leftExceedX];
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionLeft];
                        
                    } else if (rightExceedX > 0) {
                        [self caculateScrollSpeed:rightExceedX];
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionRight];
                        
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
    
    [self ajustItemIndexpathIfNecessary];
}

//根据超出的距离，滚动的速度有个变化
- (void)caculateScrollSpeed:(CGFloat)exceedDistance{
    
    self.scrollingSpeed = ABS(exceedDistance) * 5 + 200;
}


#pragma mark - UICollectionViewLayout overridden methods

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    
    NSArray *layoutAttributes = [super layoutAttributesForElementsInRect:rect];
    
    //上对齐
   // layoutAttributes =[self alignTopLayoutAttributesForElements:layoutAttributes];
    
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



