//
//  BookshelfCollectionViewFlowLayout.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/16/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "BookshelfCollectionViewFlowLayout.h"
#import <objc/runtime.h>
#import "UICollectionView+MathIndexPath.h"



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


typedef NS_ENUM(NSInteger, BookShelfGestureMoveDirection) {
    BookShelfGestureMoveDirectionUnknown = 0,
    BookShelfGestureMoveDirectionUp,
    BookShelfGestureMoveDirectionDown,
    BookShelfGestureMoveDirectionLeft,
    BookShelfGestureMoveDirectionRight,
};


//书架分组处于的状态，状态先后顺序为， ready、begin、attach、blink、grouping，如果其中一个状态没跳转成功， 则回到ready状态
typedef NS_ENUM(NSInteger, BookShelfGroupState) {
    BookShelfGroupReady,
    BookShelfGroupBegin,
    BookShelfGroupAttaching,
    BookShelfGroupBlink,
    BookShelfGrouping,
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

@property (nonatomic, weak) UIView *selectedSnapShotViewParentView; //选中的item的父view
@property (nonatomic, strong) NSIndexPath *selectedItemCurrentIndexPath;//选中的item当前的IndexPath
@property (nonatomic, strong) UIView* selectedSnapShotView;//选中的item的snapShotView
@property (nonatomic, assign) CGPoint snapShotViewScrollingCenter;//标记最初的selectedSnapShotView.center + offset的值
@property (nonatomic, assign) CGPoint snapShotViewPanTranslation;//pan手势滑动的距离

@property (nonatomic, assign) CGFloat scrollingSpeed;//拖动item时滑动的速度
@property (nonatomic, assign) UIEdgeInsets scrollingTriggerEdgeInsets;//触发滑动的范围
@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, strong, nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong, nonatomic) UIPanGestureRecognizer *panGestureRecognizer;

@property (nonatomic, assign) BookShelfGestureMoveDirection gestureMoveDirection;//手势移动的方向

@property (nonatomic, assign, readonly) id<BookShelfCollectionViewDataSource> dataSource;
@property (nonatomic, assign, readonly) id<BookShelfCollectionViewDelegateFlowLayout> delegate;

@property (nonatomic, strong) NSTimer *groupConditionWillBeginTimer;//满足将要进入分组状态的定时器
@property (nonatomic, strong)NSIndexPath *groupingIndexPath;
@property (nonatomic, assign)BookShelfGroupState groupState; //分组处于的状态
@property (nonatomic, assign)BOOL isGestureEndWatingGroup;//手势结束是否在等待进入分组界面
@property (nonatomic, assign)BOOL isGroupMainViewClickedOpened;//分组界面是否直接点击cell打开

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
    self.isGestureEndWatingGroup = NO;
    self.gestureMoveDirection = BookShelfGestureMoveDirectionUnknown;
    
    self.groupState = BookShelfGroupReady;
    self.isGroupMainViewClickedOpened = NO;

    _reorderEnabled = YES;
    _groupEnabled = NO;
    self.scrollingSpeed = 200.f;
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

    //如果正在进行分组，则不再进行其他处理
    if (self.groupState == BookShelfGrouping || self.isGestureEndWatingGroup){
        return;
    }
    
    BOOL selectedItemIsGrouped = [self.dataSource respondsToSelector:@selector(collectionView:isGroupedItemAtIndexPath:)] ?  [self.dataSource collectionView:self.collectionView isGroupedItemAtIndexPath:self.selectedItemCurrentIndexPath] : NO;
    
   // CGPoint currentPostion = [self.panGestureRecognizer locationInView:self.collectionView];
    CGPoint currentPostion = [self convertScreenPositionToScrollPostion:self.selectedSnapShotView.center inScrollView:self.collectionView inScreenView:self.selectedSnapShotViewParentView];
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:currentPostion];
    NSIndexPath *previousIndexPath = self.selectedItemCurrentIndexPath;
    
    
    //如果分组过程中，groupingIndexPath 与 snapShotView位置indexPath不同了，则取消分组过程
    if (self.groupingIndexPath != nil && ![self.groupingIndexPath isEqual: newIndexPath]){
      
        [self groupFailedCancelState:self.groupingIndexPath];
    }
    
    //如果新的位置不存在，则可能是滑到最后一个，或则第一个之外，不可能是进行分组，直接进行排序尝试
    if (newIndexPath == nil){
    
        [self reorderItemFromIndexPath:previousIndexPath toIndexPath:newIndexPath];
        
        return;
    }
    //indexPath没有变化，直接退出
    else if ([previousIndexPath isEqual:newIndexPath]){
        return;
    }
    
    
    //如果选中的item是分组，或者分组功能关闭了，则直接进行排序尝试
    if (selectedItemIsGrouped || !self.groupEnabled){
       
        if ([self checkPostion:currentPostion needReorderAtNewIndexPath:newIndexPath]){
            
            [self reorderItemFromIndexPath:previousIndexPath toIndexPath:newIndexPath];
        }
        
    }else{
        //如果手指的位置 在新的itemFrame的 0.3---0.7 范围内，且停留在那里的时间满足要求， 则进行分组流程处理
        if ([self checkPostion:currentPostion inGroupIndexPath:newIndexPath]){
            
            if (self.groupState == BookShelfGroupReady){
                
                self.groupConditionWillBeginTimer =  [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(willBeginGroup:) userInfo:newIndexPath repeats:NO];
                [[NSRunLoop currentRunLoop] addTimer:self.groupConditionWillBeginTimer forMode:NSRunLoopCommonModes];
                
                self.groupingIndexPath = newIndexPath;
                self.groupState = BookShelfGroupBegin;
            }
            
        }else if([self checkPostion:currentPostion needReorderAtNewIndexPath:newIndexPath]){
           
            //此时分组条件不在成立
            [self groupFailedCancelState:self.groupingIndexPath];
            
            [self reorderItemFromIndexPath:previousIndexPath toIndexPath:newIndexPath];
            
        }else{
            
            //此时分组条件不在成立
            [self groupFailedCancelState:self.groupingIndexPath];
        }
    }
    
}


#pragma mark - reorder
//reorder操作
- (void)reorderItemFromIndexPath:(NSIndexPath *)previousIndexPath toIndexPath:(NSIndexPath *)newIndexPath{
    
    if (newIndexPath != nil && ![newIndexPath isEqual:previousIndexPath]) {
        
        [self moveItemAtIndexPath:previousIndexPath toIndexPath:newIndexPath];
        
    }else if (newIndexPath == nil){
        
        CGPoint snapShotViewCenterInScorllView = [self convertScreenPositionToScrollPostion:self.selectedSnapShotView.center inScrollView:self.collectionView inScreenView:self.selectedSnapShotViewParentView];
        
        NSInteger lastSection = [self.collectionView numberOfSections] - 1;
        NSInteger lastRow = [self.collectionView numberOfItemsInSection:lastSection] - 1;
        NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:lastRow inSection:lastSection];
        UICollectionViewCell *lastCell = [self.collectionView cellForItemAtIndexPath:lastIndexPath];
        
        NSIndexPath *firstIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        UICollectionViewCell *firstCell = [self.collectionView cellForItemAtIndexPath:firstIndexPath];
        
        //竖直方向
        if ( self.scrollDirection == UICollectionViewScrollDirectionVertical){
            
            //超过最后一个
            if (snapShotViewCenterInScorllView.y > self.collectionView.contentSize.height - self.selectedSnapShotView.frame.size.height && snapShotViewCenterInScorllView.x > CGRectGetMaxX(lastCell.frame)){
               
                if (![self.selectedItemCurrentIndexPath isEqual:lastIndexPath]){
                   
                    [self moveItemAtIndexPath:previousIndexPath toIndexPath:lastIndexPath];
            
                }
            }
            //超出第一个
            else if (snapShotViewCenterInScorllView.y < firstCell.frame.origin.y + firstCell.frame.size.height * 0.6
                     && snapShotViewCenterInScorllView.x < firstCell.frame.size.width * 0.25){
                
                if (![self.selectedItemCurrentIndexPath isEqual:firstIndexPath]){
                    
                    [self moveItemAtIndexPath:previousIndexPath toIndexPath:firstIndexPath];
                }
            }
        }
        
        //水平方向
        else if (self.scrollDirection == UICollectionViewScrollDirectionHorizontal){
            //超过最后一个
            if (snapShotViewCenterInScorllView.x > self.collectionView.contentSize.width - self.selectedSnapShotView.frame.size.width && snapShotViewCenterInScorllView.y > CGRectGetMaxY(lastCell.frame)){
                
                if (![self.selectedItemCurrentIndexPath isEqual:lastIndexPath]){
                    [self moveItemAtIndexPath:previousIndexPath toIndexPath:lastIndexPath];
                }

            }//超出第一个
            else if (snapShotViewCenterInScorllView.y < firstCell.frame.origin.y + firstCell.frame.size.height * 0.6
                     && snapShotViewCenterInScorllView.x < firstCell.frame.size.width * 0.25){
                
                if (![self.selectedItemCurrentIndexPath isEqual:firstIndexPath]){
                    
                    [self moveItemAtIndexPath:previousIndexPath toIndexPath:firstIndexPath];
                }
            }
        }
        
    }
}

- (void)moveItemAtIndexPath:(NSIndexPath *)previousIndexPath toIndexPath:(NSIndexPath *)newIndexPath{
    //交换数据, 数据的交换要先执行
    if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(collectionView:moveItemAtIndexPath:toIndexPath:)]){
        [self.dataSource collectionView:self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:newIndexPath];
        
    }
    
    
    self.selectedItemCurrentIndexPath = newIndexPath;
    [self.collectionView moveItemAtIndexPath:previousIndexPath toIndexPath:newIndexPath];
}

//判断当前的snapShotView所处的位置，是否需要进行reorder
- (BOOL)checkPostion:(CGPoint )currentPostion needReorderAtNewIndexPath:(NSIndexPath *)newIndexPath{
    
    CGRect newIndexPathItemFrame = [self.collectionView cellForItemAtIndexPath:newIndexPath].frame;
    
    //只要不是向左滑动，就认为是向右滑动
    if(self.gestureMoveDirection != BookShelfGestureMoveDirectionLeft
       && currentPostion.x > newIndexPathItemFrame.origin.x + newIndexPathItemFrame.size.width * 0.75){
        
        
        NSIndexPath *nextIndexPath = [self.collectionView nextIndexPathByCurrentIndexPath:newIndexPath];
        //向右滑动，如果下一个indexPath 已经是自己，不需要换位置
        if (![nextIndexPath isEqual:self.selectedItemCurrentIndexPath]){
            return YES;
        }
        
    }
    //不是向右滑动，就认为是向左滑动
    else if (self.gestureMoveDirection != BookShelfGestureMoveDirectionRight
             && currentPostion.x < newIndexPathItemFrame.origin.x + newIndexPathItemFrame.size.width * 0.25){
        
        NSIndexPath *preIndexPath = [self.collectionView preIndexPathByCurrentIndexPath:newIndexPath];
        
        if (![preIndexPath isEqual:self.selectedItemCurrentIndexPath]){
            return YES;
        }
    }
    return NO;
}


#pragma mark - group
//将要进入开始分组
- (void)willBeginGroup:(NSTimer *)timer{
    
    //NSIndexPath *groupIndexPath = timer.userInfo;
            
    [self beginGroupStageOne:self.groupingIndexPath];

    [self removeGroupConditionTimer];
}

//分组阶段1时，被分组的item 要变为分组view显示， selectedItem snapView 黏附到groupItem处， 这个过程
- (void)beginGroupStageOne:(NSIndexPath *)groupIndexPath{

    self.groupState = BookShelfGroupAttaching;
    
    [self viewTurnToGroupedItemView:groupIndexPath];
    
    //selectedItem snapView 黏附到groupItem处
    [self selectedItemAttachToGroupItem:groupIndexPath];
}

//分组阶段1被取消了， 如果被取消，分组进不了阶段2
- (void)cancelBeginGroupStageOne:(NSIndexPath *)groupIndexPath{
    
     self.groupState = BookShelfGroupReady;
    [self viewOfGroupedItemBackToOriginView:groupIndexPath];
    
    [self selectedItemDeattachToGroupItem:groupIndexPath];
}

//分组阶段2， groupItem 闪烁2下
- (void)beginGroupStageTwo:(NSIndexPath *)groupIndexPath{
    
    self.groupState = BookShelfGroupBlink;
    
    [self groupItemStartBlinkAnimation:groupIndexPath];
}

//取消分组阶段2
- (void)cancelBeginGroupStageTwo:(NSIndexPath *)groupIndexPath{
    
    [self groupItemCancelBlinkAnimation:groupIndexPath];
    

    //分组阶段1也要取消掉,阶段1的取消，会置状态为BookShelfGroupReady
    [self cancelBeginGroupStageOne:groupIndexPath];
}

//分组阶段3， 最后的阶段
- (void)beginGroupStageEnd:(NSIndexPath *)groupIndexPath{
    
    self.groupState = BookShelfGrouping;
    [self invalidatesScrollTimer];
    
    //回调分组成功，进入分组界面
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(collectionView:layout:beginGroupForItemAtIndexPath:toGroupIndexPath:selectedSnapShotView:)]){
        [self.delegate collectionView:self.collectionView layout:self beginGroupForItemAtIndexPath:self.selectedItemCurrentIndexPath toGroupIndexPath:groupIndexPath selectedSnapShotView:self.selectedSnapShotView];
    }
    
    //为分组包装的view此时消失掉
   [self viewOfGroupedItemBackToOriginView:groupIndexPath];
}

//分组界面是从 cell选中打开的。
- (void)groupMainViewClickedOpened{
   
    self.isGroupMainViewClickedOpened = YES;
    self.groupState = BookShelfGrouping;
    [self invalidatesScrollTimer];
}

//分组失败的 状态清空处理
- (void)groupFailedCancelState:(NSIndexPath *)groupIndextPath{
    switch (self.groupState) {
        case BookShelfGroupReady: {
            break;
        }
        case BookShelfGroupBegin: {
            self.groupState = BookShelfGroupReady;
            [self removeGroupConditionTimer];
            break;
        }
        case BookShelfGroupAttaching: {
            [self cancelBeginGroupStageOne:groupIndextPath];
            break;
        }
        case BookShelfGroupBlink: {
            [self cancelBeginGroupStageTwo:groupIndextPath];
            break;
        }
        case BookShelfGrouping: {
            break;
        }
    }
    
    self.groupingIndexPath = nil;
}

//选中的item 黏附到 分组的item位置处
- (void)selectedItemAttachToGroupItem:(NSIndexPath *)groupIndexPath{
    
    [self.selectedSnapShotView.layer removeAllAnimations];
    
    UICollectionViewCell *groupCell = [self.collectionView cellForItemAtIndexPath:groupIndexPath];
    
    CGPoint destcenter = groupCell.center;
    destcenter = [self convertScrollPositionToScreenPostion:destcenter inScrollView:self.collectionView inScreenView:self.selectedSnapShotViewParentView];
    destcenter.y = self.selectedSnapShotView.center.y;
    
    CGPoint offset = CGPointMake(destcenter.x - self.selectedSnapShotView.center.x, destcenter.y - self.selectedSnapShotView.center.y);
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf){
            
            strongSelf.snapShotViewScrollingCenter = BS_CGPointAdd(strongSelf.snapShotViewScrollingCenter, offset);
            strongSelf.selectedSnapShotView.center  = BS_CGPointAdd(strongSelf.snapShotViewScrollingCenter, strongSelf.snapShotViewPanTranslation);
            
            strongSelf.selectedSnapShotView.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
        }
    } completion:^(BOOL finished) {
        if(finished){
            
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [self beginGroupStageTwo:groupIndexPath];
            }
        }
    }];
}

- (void)selectedItemDeattachToGroupItem:(NSIndexPath *)groupIndexPath{

    [self.selectedSnapShotView.layer removeAllAnimations];
    
    self.selectedSnapShotView.transform = CGAffineTransformIdentity;
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf){
            strongSelf.selectedSnapShotView.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
        }
    } completion:^(BOOL finished) {
        
    }];
}

//分组的item开始闪烁的动画
- (void)groupItemStartBlinkAnimation:(NSIndexPath *)groupIndexPath{
    
    UICollectionViewCell *groupCell = [self.collectionView cellForItemAtIndexPath:groupIndexPath];
    
    [UIView animateKeyframesWithDuration:0.5 delay:0.0 options:UIViewKeyframeAnimationOptionAutoreverse animations:^{
        
        
        [UIView addKeyframeWithRelativeStartTime:0.1 relativeDuration:0.4 animations:^{
            groupCell.alpha = 0.0;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.5 relativeDuration:0.4 animations:^{
            groupCell.alpha = 1.0;
        }];
        
    } completion:^(BOOL finished) {
        if (finished){
            if (self.isGestureEndWatingGroup){
                [self gestureEndAutoGoingGroup];
            }else{
                [self beginGroupStageEnd:groupIndexPath];
            }
        }
        
    }];
}

- (void)groupItemCancelBlinkAnimation:(NSIndexPath *)groupIndexPath{
    UICollectionViewCell *groupCell = [self.collectionView cellForItemAtIndexPath:groupIndexPath];
    [groupCell.layer removeAllAnimations];
    
    groupCell.alpha = 1.0;
}

//判断位置是否在分组的item frame 范围内
- (BOOL)checkPostion:(CGPoint )postion inGroupIndexPath:(NSIndexPath *)newIndexPath{
    
    CGRect itemframe = [self.collectionView cellForItemAtIndexPath:newIndexPath].frame;
    
    if( postion.x > itemframe.origin.x + itemframe.size.width * 0.3
       && postion.x < itemframe.origin.x + itemframe.size.width * 0.7
       && postion.y > itemframe.origin.y + itemframe.size.height * 0.2
       && postion.y < itemframe.origin.y + itemframe.size.height * 0.8){
        return YES;
    }else{
        return NO;
    }
}

//移除确定分组开始的定时器
- (void)removeGroupConditionTimer{
    if (self.groupConditionWillBeginTimer != nil){
        [self.groupConditionWillBeginTimer invalidate];
        self.groupConditionWillBeginTimer = nil;
    }
}

//一个item的View 变为分组的view，如果已经是分组的view，则不用改变
- (void)viewTurnToGroupedItemView:(NSIndexPath *)indexPath{
    
    //如果这个item 就是groupedItem，则直接用这个界面
    if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(collectionView :isGroupedItemAtIndexPath:)]){
        
        if ([self.dataSource collectionView:self.collectionView isGroupedItemAtIndexPath:indexPath]){
            return;
        }
    }
    
    UICollectionViewCell *groupCell = [self.collectionView cellForItemAtIndexPath:indexPath];
    UIView * groupView = [[UIView alloc]initWithFrame:groupCell.bounds];
    groupView.backgroundColor = [UIColor colorWithRed:0.815 green:0.8666 blue:0.509 alpha:1.0];
    UIView *snapShot = [groupCell BS_snapShotView];
    snapShot.transform = CGAffineTransformMakeScale(.9f, .9f);
    [groupView addSubview:snapShot];
   
    [groupView setTag:13333];
    [groupCell addSubview:groupView];
}

//一个分组item的View 变为之前的view
- (void)viewOfGroupedItemBackToOriginView:(NSIndexPath *)indexPath{
    
    UICollectionViewCell *groupCell = [self.collectionView cellForItemAtIndexPath:indexPath];
    UIView *groupView = [groupCell viewWithTag:13333];
    [groupView removeFromSuperview];
}


#pragma mark - 手指松开，分组处于attach和blink状态, 自动进行分组处理
- (void)gestureEndAutoGoingGroup{
    
    self.isGestureEndWatingGroup = NO;
    self.groupState = BookShelfGrouping;
    [self invalidatesScrollTimer];
    [self viewOfGroupedItemBackToOriginView:self.groupingIndexPath];
    
    BOOL isGroupingIndexPathAlreadyGrouped = NO;
    if (self.dataSource != nil && [self.dataSource respondsToSelector:@selector(collectionView:isGroupedItemAtIndexPath:)]){
        isGroupingIndexPathAlreadyGrouped = [self.dataSource collectionView:self.collectionView isGroupedItemAtIndexPath:self.groupingIndexPath];
    }
    
    [self.selectedSnapShotView removeFromSuperview];
    self.selectedSnapShotView = nil;
    
    
    //如果将要进行分组的indexPath 已经是分组了，则不用打开分组界面，直接进行分组
    if (isGroupingIndexPathAlreadyGrouped){
        //告知不用打开分组，直接加入到分组即可
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(collectionView:layout:addItemAtIndexPath:unOpenGroupAtIndexPath:)]){
            [self.delegate collectionView:self.collectionView layout:self addItemAtIndexPath:self.selectedItemCurrentIndexPath unOpenGroupAtIndexPath:self.groupingIndexPath];
        }
        
    }else{
        
        //告知打开分组
        if (self.delegate != nil && [self.delegate respondsToSelector:@selector(collectionView:layout:addItemAtIndexPath:andOpenGroupAtIndexPath:)]){
            [self.delegate collectionView:self.collectionView layout:self addItemAtIndexPath:self.selectedItemCurrentIndexPath andOpenGroupAtIndexPath:self.groupingIndexPath];
        }
    }
}


#pragma mark - 分组界面打开后，回到书架界面
//分组界面打开， 用户取消了分组操作，一定要调用此接口 告知
- (void)cancelGroupForItemAtIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath withSnapShotView:(UIView *)snapShotView{
    
    self.groupState = BookShelfGroupReady;
    self.isGroupMainViewClickedOpened = NO;
  
    self.selectedItemCurrentIndexPath = itemIndexPath;
  
    
    self.selectedSnapShotView = snapShotView;
    self.snapShotViewScrollingCenter = snapShotView.center;
    self.snapShotViewPanTranslation = CGPointZero;
    [self.panGestureRecognizer setTranslation:CGPointZero inView:self.selectedSnapShotViewParentView];
    
    [self invalidateLayout];
}

//分组界面打开， 用户完成了分组操作， 一定要调用此接口，告知
- (void)finishedGroupForItemAtIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath{
    
    self.isGroupMainViewClickedOpened = NO;
    self.groupState = BookShelfGroupReady;
    
    [self.selectedSnapShotView removeFromSuperview];
    self.selectedSnapShotView = nil;
    
    self.selectedItemCurrentIndexPath  = nil;
    self.snapShotViewScrollingCenter = CGPointZero;
    self.snapShotViewPanTranslation = CGPointZero;
    
    [self invalidateLayout];
    
}


#pragma mark - gesture
/**
 *  手势都加载collectionView的superView上，groupMainView也是加载collectionView的superView上的
 *  这样 collectionView 和 groupMainView就能共用一套手势
 */
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
        
        [self.collectionView.superview addGestureRecognizer:self.longPressGestureRecognizer];
    }
    
    if (self.panGestureRecognizer == nil){
        self.panGestureRecognizer = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(handlePanGesture:)];
        self.panGestureRecognizer.delegate = self;
        [self.collectionView.superview addGestureRecognizer:self.panGestureRecognizer];
    
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
    
    if (self.gestureDelegate != nil && [self.gestureDelegate respondsToSelector:@selector(handleLongPressGesture:inGestureView:)]){
        [self.gestureDelegate handleLongPressGesture:recognizer inGestureView:self.collectionView];
    }
    
    if(self.groupState == BookShelfGrouping || self.isGestureEndWatingGroup){
        return;
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
        UIView *imageView = [cell BS_snapShotView];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.selectedSnapShotView addSubview:imageView];
        
        [self.selectedSnapShotViewParentView addSubview:self.selectedSnapShotView];
        self.snapShotViewScrollingCenter = self.selectedSnapShotView.center;
        self.snapShotViewPanTranslation = CGPointZero;
        
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
        
        //如果分组状态处于 blink和attach状态，此时手指松开，则进入 自动进入分组流程处理
        if (self.groupState == BookShelfGroupBlink || self.groupState == BookShelfGroupAttaching){
            
            self.isGestureEndWatingGroup = YES;
            return;
        }else if (self.groupState == BookShelfGroupBegin){
            //清除分组状态
            [self groupFailedCancelState:self.groupingIndexPath];
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
    
    //分组界面也会需要书架界面的pan手势，进行拖动、排序等操作。
    if (self.gestureDelegate != nil && [self.gestureDelegate respondsToSelector:@selector(handlePanGesture:inGestureView:)]){
        [self.gestureDelegate handlePanGesture:gestureRecognizer inGestureView:self.collectionView];
    }
    if (self.groupState == BookShelfGrouping || self.isGestureEndWatingGroup){
        return;
    }
    if (self.selectedSnapShotView == nil){
        return;
    }
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged: {
            
            //pan translation
            CGPoint panTranslation = [gestureRecognizer translationInView:self.selectedSnapShotViewParentView];
            [self caculateGestureMoveDirection:panTranslation];
            self.snapShotViewPanTranslation = panTranslation;
            
            CGPoint velocity =[gestureRecognizer velocityInView:self.selectedSnapShotViewParentView];
            
            //update snapshotView center
            CGPoint viewCenter = self.selectedSnapShotView.center = BS_CGPointAdd(self.snapShotViewScrollingCenter, self.snapShotViewPanTranslation);
        
            [self ajustItemIndexpathIfNecessary];
            
            CGFloat width = self.selectedSnapShotView.frame.size.width;
            CGFloat hegiht = self.selectedSnapShotView.frame.size.height;
            switch (self.scrollDirection) {
                case UICollectionViewScrollDirectionVertical: {
                    
                    CGFloat topExceedY = (viewCenter.y - hegiht/2) - (CGRectGetMinY(self.collectionView.frame) - self.scrollingTriggerEdgeInsets.top);
                    CGFloat bottomExceedtY = (viewCenter.y + hegiht/2) - (CGRectGetMaxY(self.collectionView.frame) + self.scrollingTriggerEdgeInsets.bottom);
                    
                    if (topExceedY < 0 && velocity.y < 0) {
                        [self caculateScrollSpeed:topExceedY];
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionUp];
                        
                    } else if (bottomExceedtY > 0 && velocity.y > 0) {
                        [self caculateScrollSpeed:bottomExceedtY];
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionDown];
                        
                    }else {
                            [self invalidatesScrollTimer];
                    }
                } break;
                case UICollectionViewScrollDirectionHorizontal: {
                    
                    CGFloat leftExceedX = (viewCenter.x - width/2) - (CGRectGetMinX(self.collectionView.frame) - self.scrollingTriggerEdgeInsets.left);
                    CGFloat rightExceedX = viewCenter.x + width/2 -  (CGRectGetMaxX(self.collectionView.frame) + self.scrollingTriggerEdgeInsets.right);
                    
                    if (leftExceedX < 0 && velocity.x < 0) {
                        [self caculateScrollSpeed:leftExceedX];
                        [self setupScrollTimerInDirection:BookShelfScrollingDirectionLeft];
                        
                    } else if (rightExceedX > 0 && velocity.x > 0) {
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
    
    //self.snapShotViewScrollingCenter = BS_CGPointAdd(self.snapShotViewScrollingCenter, translation);
    //self.selectedSnapShotView.center = BS_CGPointAdd(self.snapShotViewScrollingCenter, self.snapShotViewPanTranslation);
    self.collectionView.contentOffset = BS_CGPointAdd(contentOffset, translation);
    
    [self ajustItemIndexpathIfNecessary];
}

//根据超出的距离，滚动的速度有个变化
- (void)caculateScrollSpeed:(CGFloat)exceedDistance{
    
    self.scrollingSpeed = ABS(exceedDistance) * 5 + 200;
}

- (void)caculateGestureMoveDirection:(CGPoint)panTranslation{
    CGFloat offsetX = panTranslation.x - self.snapShotViewPanTranslation.x;
    CGFloat offsetY = panTranslation.y - self.snapShotViewPanTranslation.y;
    
    //60度
    if (ABS(offsetY/offsetX) <= 1.732){
        if (offsetX >= 0){
            self.gestureMoveDirection = BookShelfGestureMoveDirectionRight;
        }else{
            self.gestureMoveDirection = BookShelfGestureMoveDirectionLeft;
        }
    }else {
        if (offsetY < 0){
            self.gestureMoveDirection = BookShelfGestureMoveDirectionUp;
        }else{
            self.gestureMoveDirection = BookShelfGestureMoveDirectionDown;
        }
    }
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
    if (self.selectedSnapShotViewParentView == nil){
        self.selectedSnapShotViewParentView = self.collectionView.window.rootViewController.view;
    }
    
    
    if ([self.panGestureRecognizer isEqual:gestureRecognizer]) {
       
        return (self.selectedItemCurrentIndexPath != nil || self.isGroupMainViewClickedOpened);
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



