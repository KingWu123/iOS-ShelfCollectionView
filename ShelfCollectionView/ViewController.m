//
//  ViewController.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/12/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "ViewController.h"
#import "BookCollectionViewCell.h"
#import <objc/runtime.h>


#ifndef CGGEOMETRY_LXSUPPORT_H_
CG_INLINE CGPoint
LXS_CGPointAdd(CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
}
#endif

typedef NS_ENUM(NSInteger, ShelfScrollingDirection) {
    ShelfScrollingDirectionUnknown = 0,
    ShelfScrollingDirectionUp,
    ShelfScrollingDirectionDown,
    ShelfScrollingDirectionLeft,
    ShelfScrollingDirectionRight
};


static NSString * const kLXScrollingDirectionKey = @"LXScrollingDirection";

@interface CADisplayLink (LX_userInfo)
@property (nonatomic, copy) NSDictionary *LX_userInfo;
@end

@implementation CADisplayLink (LX_userInfo)
- (void) setLX_userInfo:(NSDictionary *) LX_userInfo {
    objc_setAssociatedObject(self, "LX_userInfo", LX_userInfo, OBJC_ASSOCIATION_COPY);
}

- (NSDictionary *) LX_userInfo {
    return objc_getAssociatedObject(self, "LX_userInfo");
}
@end






@interface ViewController ()<UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIScrollViewDelegate>


@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong)NSMutableArray *modelSource;


@property (nonatomic, assign)NSIndexPath *selectedCellCurrentIndexPath;//选中cell，当前所在的indexPath
@property (nonatomic, assign)NSIndexPath *selectedCellOriginIndexPath;//选中的cell，被选中的一刹那时的 indexPath
@property (nonatomic, weak)UIImageView *selectedCellSnapImageView;//选中的cell的截图


@property (assign, nonatomic) CGPoint selectedSnapImgViewCenter;
@property (assign, nonatomic) CGPoint panTranslationInCollectionView;
@property (strong, nonatomic) CADisplayLink *displayLink;

@property (nonatomic, assign)float scrollingSpeed;
@property (assign, nonatomic) UIEdgeInsets scrollingTriggerEdgeInsets;


@property (nonatomic, assign)CGPoint preLongGestureLocation;
@property (nonatomic, strong)UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong)UIPanGestureRecognizer * panGestureRecognizer;



@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.collectionView registerNib:[UINib nibWithNibName:@"BookCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"BookCollectionViewCell"];
    

    //UICollectionViewLayoutAttributes
   // [self.collcetionView setCollectionViewLayout:[self createLayout]];
    
    
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    
   
    
    //init modelSource
    self.modelSource = [[NSMutableArray alloc]init];
    for (int i=0; i<50; i++){
        [self.modelSource addObject:[NSString stringWithFormat:@"book %d", i]];
    }
    
    
    [self setupCollectionViewGesture];
    
    self.scrollingSpeed = 300.0f;
    self.scrollingTriggerEdgeInsets = UIEdgeInsetsMake(50.0f, 50.0f, 50.0f, 50.0f);
}

- (void)setupCollectionViewGesture {
    self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(handleLongPressGesture:)];
    self.longPressGestureRecognizer.delegate = self;
    
    // Links the default long press gesture recognizer to the custom long press gesture recognizer we are creating now
    // by enforcing failure dependency so that they doesn't clash.
    for (UIGestureRecognizer *gestureRecognizer in self.collectionView.gestureRecognizers) {
        if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            [gestureRecognizer requireGestureRecognizerToFail:self.longPressGestureRecognizer];
        }
    }
    
    [self.collectionView addGestureRecognizer:self.longPressGestureRecognizer];
    
    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                    action:@selector(handlePanGesture:)];
    self.panGestureRecognizer.delegate = self;
    [self.collectionView addGestureRecognizer:self.panGestureRecognizer];
}

- (void)tearDownCollectionViewGesture {
    // Tear down long press gesture
    if (_longPressGestureRecognizer) {
        UIView *view = _longPressGestureRecognizer.view;
        if (view) {
            [view removeGestureRecognizer:_longPressGestureRecognizer];
        }
        _longPressGestureRecognizer.delegate = nil;
        _longPressGestureRecognizer = nil;
    }
    
    // Tear down pan gesture
    if (_panGestureRecognizer) {
        UIView *view = _panGestureRecognizer.view;
        if (view) {
            [view removeGestureRecognizer:_panGestureRecognizer];
        }
        _panGestureRecognizer.delegate = nil;
        _panGestureRecognizer = nil;
    }
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)dealloc{
    [self invalidatesScrollTimer];
    [self tearDownCollectionViewGesture];
}


- (UICollectionViewLayout *)createLayout{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc]init];
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    [layout setMinimumLineSpacing:0];
    [layout setMinimumInteritemSpacing:0];
    return layout;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return [self.modelSource count];;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    BookCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BookCollectionViewCell" forIndexPath:indexPath];
    
    [cell initCellWithIndex:[self.modelSource objectAtIndex:indexPath.row]];
    return cell;
}


- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
 
    return 1;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath*)destinationIndexPath{
    
    id sourceObject = [self.modelSource objectAtIndex:sourceIndexPath.row];
    [self.modelSource removeObjectAtIndex:sourceIndexPath.row];
    [self.modelSource insertObject:sourceObject atIndex:destinationIndexPath.row];
}
#pragma mark - UICollectionViewDelegate


#pragma mark - UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    float width = [[UIScreen mainScreen]bounds].size.width /3;
    float height = width + 50;
//    if (indexPath.row%3 == 0){
//        height += 15;
//    }else if (indexPath.row%3 == 1){
//        height += 30;
//    }
    return CGSizeMake(width, height);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}


#pragma mark - UILongPressGestureRecognizer
- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer{
    
    if (recognizer.state == UIGestureRecognizerStateBegan){
        
        CGPoint location = [recognizer locationInView:self.collectionView];
        self.preLongGestureLocation = location;
        
        //selected cell and current indexPath
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
        self.selectedCellCurrentIndexPath = self.selectedCellOriginIndexPath = indexPath;
        BookCollectionViewCell *cell = (BookCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        
        //cell snap imageView
        UIImage *image = [self snapImageOfView:cell scale:0.0];
        UIImageView *imageView = [[UIImageView alloc]initWithImage:image];
        imageView.frame = CGRectMake(cell.frame.origin.x, cell.frame.origin.y - 2, cell.frame.size.width, cell.frame.size.height);
        [self.collectionView addSubview:imageView];
        self.selectedCellSnapImageView = imageView;
        
        //hidden cell
        [cell setHidden:YES];
        
    }else if (recognizer.state == UIGestureRecognizerStateChanged){

        //move offset
        CGPoint currentLoction = [recognizer locationInView:self.collectionView];
        CGPoint offset = CGPointMake(currentLoction.x - self.preLongGestureLocation.x, currentLoction.y - self.preLongGestureLocation.y);
        self.preLongGestureLocation = currentLoction;
        
        //update selectedCellSnapImageView frame
        CGRect selectedImgViewFrame = self.selectedCellSnapImageView.frame;
        selectedImgViewFrame.origin = CGPointMake(selectedImgViewFrame.origin.x + offset.x, selectedImgViewFrame.origin.y + offset.y);
        self.selectedCellSnapImageView.frame = selectedImgViewFrame;
        
        
        //adjust collectionViewCell
        [self adjustCollectionViewCell:currentLoction];
        
        //need collectionView scroll
        //[self collectionViewNeedScroll:currentLoction];
    
    }else if (recognizer.state == UIGestureRecognizerStateFailed || recognizer.state == UIGestureRecognizerStateEnded){
        
        //indexPath changed, exchange data
        if (![self.selectedCellCurrentIndexPath isEqual:self.selectedCellOriginIndexPath]){
            [self collectionView:self.collectionView moveItemAtIndexPath:self.selectedCellOriginIndexPath toIndexPath:self.selectedCellCurrentIndexPath];
        }
        
        //end animation to set result cell
        BookCollectionViewCell *cell = (BookCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:self.selectedCellCurrentIndexPath];
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.selectedCellSnapImageView.frame = cell.frame;
            
        } completion:^(BOOL finished) {
            
            [self.selectedCellSnapImageView removeFromSuperview];
            self.selectedCellSnapImageView = nil;
        
            [cell setHidden:NO];

        }];

    }
    
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer{
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged: {
            self.panTranslationInCollectionView = [gestureRecognizer translationInView:self.collectionView];
            
            CGPoint viewCenter  = LXS_CGPointAdd(self.selectedSnapImgViewCenter, self.panTranslationInCollectionView);
            //self.selectedCellSnapImageView.center = viewCenter;
            
            switch (((UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout).scrollDirection) {
                case UICollectionViewScrollDirectionVertical: {
                    if (viewCenter.y < (CGRectGetMinY(self.collectionView.bounds) + self.scrollingTriggerEdgeInsets.top)) {
                        [self setupScrollTimerInDirection:ShelfScrollingDirectionUp];
                    } else {
                        if (viewCenter.y > (CGRectGetMaxY(self.collectionView.bounds) - self.scrollingTriggerEdgeInsets.bottom)) {
                            [self setupScrollTimerInDirection:ShelfScrollingDirectionDown];
                        } else {
                            [self invalidatesScrollTimer];
                        }
                    }
                } break;
                case UICollectionViewScrollDirectionHorizontal: {
                    if (viewCenter.x < (CGRectGetMinX(self.collectionView.bounds) + self.scrollingTriggerEdgeInsets.left)) {
                        [self setupScrollTimerInDirection:ShelfScrollingDirectionLeft];
                    } else {
                        if (viewCenter.x > (CGRectGetMaxX(self.collectionView.bounds) - self.scrollingTriggerEdgeInsets.right)) {
                            [self setupScrollTimerInDirection:ShelfScrollingDirectionRight];
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
            // Do nothing...
        } break;
    }
}




- (void)adjustCollectionViewCell:(CGPoint)currentLocation{
    NSIndexPath *destIndexPath = [self.collectionView indexPathForItemAtPoint:currentLocation];
  
    if (destIndexPath.row != self.selectedCellCurrentIndexPath.row
        || destIndexPath.section != self.selectedCellCurrentIndexPath.section){
    
        [self.collectionView moveItemAtIndexPath:self.selectedCellCurrentIndexPath toIndexPath:destIndexPath];
   
        self.selectedCellCurrentIndexPath = destIndexPath;
    }

}

/*
- (void)collectionViewNeedScroll:(CGPoint)currentLocation{
    CGRect snapImageFrame = self.selectedCellSnapImageView.frame;
    
    float bottomOffsetY = snapImageFrame.origin.y + snapImageFrame.size.height - (self.collectionView.contentOffset.y + self.collectionView.frame.size.height);
    
    float upOffsetY = snapImageFrame.origin.y - self.collectionView.contentOffset.y;

    self.scrollingSpeed = 300.0f;
    //底部超出，需要滚动
    if (bottomOffsetY > 0){
        CGPoint destOffset = self.collectionView.contentOffset;
        destOffset.y += 10;
        destOffset.y = MIN(destOffset.y, self.collectionView.contentSize.height - self.collectionView.frame.size.height);
        
        
        [self setupScrollTimerInDirection:ShelfScrollingDirectionDown];
    }else if (upOffsetY < 0){
        CGPoint destOffset = self.collectionView.contentOffset;
        destOffset.y -= 10;
        destOffset.y = MAX(destOffset.y, 0);
        
       [self setupScrollTimerInDirection:ShelfScrollingDirectionUp];
    }else{
        [self invalidatesScrollTimer];
    }
}

*/


- (void)invalidatesScrollTimer {
    if (!self.displayLink.paused) {
        [self.displayLink invalidate];
    }
    self.displayLink = nil;
}

- (void)setupScrollTimerInDirection:(ShelfScrollingDirection)direction {
    if (!self.displayLink.paused) {
        ShelfScrollingDirection oldDirection = [self.displayLink.LX_userInfo[kLXScrollingDirectionKey] integerValue];
        
        if (direction == oldDirection) {
            return;
        }
    }
    
    [self invalidatesScrollTimer];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleScroll:)];
    self.displayLink.LX_userInfo = @{ kLXScrollingDirectionKey : @(direction) };
    
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}


// Tight loop, allocate memory sparely, even if they are stack allocation.
- (void)handleScroll:(CADisplayLink *)displayLink {
    ShelfScrollingDirection direction = (ShelfScrollingDirection)[displayLink.LX_userInfo[kLXScrollingDirectionKey] integerValue];
    if (direction == ShelfScrollingDirectionUnknown) {
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
        case ShelfScrollingDirectionUp: {
            distance = -distance;
            CGFloat minY = 0.0f - contentInset.top;
            
            if ((contentOffset.y + distance) <= minY) {
                distance = -contentOffset.y - contentInset.top;
            }
            
            translation = CGPointMake(0.0f, distance);
        } break;
        case ShelfScrollingDirectionDown: {
            CGFloat maxY = MAX(contentSize.height, frameSize.height) - frameSize.height + contentInset.bottom;
            
            if ((contentOffset.y + distance) >= maxY) {
                distance = maxY - contentOffset.y;
            }
            
            translation = CGPointMake(0.0f, distance);
        } break;
        case ShelfScrollingDirectionLeft: {
            distance = -distance;
            CGFloat minX = 0.0f - contentInset.left;
            
            if ((contentOffset.x + distance) <= minX) {
                distance = -contentOffset.x - contentInset.left;
            }
            
            translation = CGPointMake(distance, 0.0f);
        } break;
        case ShelfScrollingDirectionRight: {
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

   // self.selectedSnapImgViewCenter = LXS_CGPointAdd(self.selectedSnapImgViewCenter, translation);
   // self.selectedCellSnapImageView.center = LXS_CGPointAdd(self.selectedSnapImgViewCenter, self.panTranslationInCollectionView);
    self.collectionView.contentOffset = LXS_CGPointAdd(contentOffset, translation);
}



- (void)longPressGestureRecognizer1:(UILongPressGestureRecognizer *)recognizer{
    
    static CGPoint originCenter;
    if (recognizer.state == UIGestureRecognizerStateBegan){
        
        CGPoint location = [recognizer locationInView:self.collectionView];
        self.preLongGestureLocation = location;
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
    
        
        [self.collectionView beginInteractiveMovementForItemAtIndexPath:indexPath];
        
        originCenter = [self.collectionView cellForItemAtIndexPath:indexPath].center;
        
    }else if (recognizer.state == UIGestureRecognizerStateChanged){
        
        CGPoint currentLoction = [recognizer locationInView:self.collectionView];
        CGPoint offset = CGPointMake(currentLoction.x - self.preLongGestureLocation.x, currentLoction.y - self.preLongGestureLocation.y);
        
        //self.preLongGestureLocation = currentLoction;
        
        
        [self.collectionView updateInteractiveMovementTargetPosition:CGPointMake(originCenter.x + offset.x, originCenter.y + offset.y)];
        
        
    }else if (recognizer.state == UIGestureRecognizerStateFailed || recognizer.state == UIGestureRecognizerStateEnded){
        
        [self.collectionView endInteractiveMovement];
    }
    
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([self.panGestureRecognizer isEqual:gestureRecognizer]) {
        return (self.selectedCellSnapImageView != nil);
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



#pragma mark - assistant method
-(UIImage *)snapImageOfView:(UIView *)aView scale:(CGFloat)aScale{
    if([[[UIDevice currentDevice] systemVersion] floatValue]>=7.0){
        UIGraphicsBeginImageContextWithOptions(aView.bounds.size, NO, aScale);
        [aView drawViewHierarchyInRect:aView.bounds afterScreenUpdates:YES];
        UIImage *copied = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return copied;
    }
    else
    {
        UIGraphicsBeginImageContextWithOptions(aView.bounds.size, NO, aScale);
        [aView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *copied = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return copied;
    }
}

@end


