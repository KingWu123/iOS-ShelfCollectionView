//
//  BookShelfGroupViewFlowLayout.h
//  ShelfCollectionView
//
//  Created by king.wu on 8/18/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol BookShelfGroupViewDataSource <UICollectionViewDataSource>

@optional
//use it to move data
- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

@end


@protocol BookShelfGroupViewDelegateFlowLayout <UICollectionViewDelegateFlowLayout>

@optional
//begin movement
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout beginMovementForItemAtIndexPath:(NSIndexPath *)indexPath;

//end movement
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout endMovementForItemAtIndexPath:(NSIndexPath *)indexPath;


//当拖动的item不再collectionView范围内时，取消分组，itemIndexPath为此时选中的item
- (void)cancelGroupSelectedItemAtIndexPath:(NSIndexPath *)itemIndexPath withSnapShotView:(UIView *)snapShotView;


@end




@interface BookShelfGroupViewFlowLayout : UICollectionViewFlowLayout

//longPress手势是从书架界面传进来的
- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer;

//panGesture手势也是从书架界面穿件来的
- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer;

//进入分组界面时， 手势是从底下的书架界面传上来的，因此不会从longPress手势对选中的item进行snapView的初始化，需要自己初始化
- (void)initSelectSnapShotViewIfNeeded:(UIView *)snapShotView selectedIndexPath:(NSIndexPath *)selectedIndexPath;


@end
