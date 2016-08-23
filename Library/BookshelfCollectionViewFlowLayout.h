//
//  BookshelfCollectionViewFlowLayout.h
//  ShelfCollectionView
//
//  Created by king.wu on 8/16/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BookShelfCollectionViewDataSource <UICollectionViewDataSource>

@optional

//use it to move data
- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;


//item是否是 分过组的item
- (BOOL)collectionView:(UICollectionView *)collectionView isGroupedItemAtIndexPath:(NSIndexPath *)indexPath;



@end


@protocol BookShelfCollectionViewDelegateFlowLayout <UICollectionViewDelegateFlowLayout>

@optional

//begin movement
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout beginMovementForItemAtIndexPath:(NSIndexPath *)indexPath;

//end movement
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout endMovementForItemAtIndexPath:(NSIndexPath *)indexPath;


//begin group, itemIndexPath to groupIndexPath
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout beginGroupForItemAtIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath selectedSnapShotView:(UIView *)snaptShotView;

@end



//进行分组时，分组界面需要利用书架界面传过来的手势进行处理。
@protocol BookShelfCollectionViewGestureDelegate <NSObject>

@required

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)gestureRecognizer inGestureView:(UIView*)view;

- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer inGestureView:(UIView*)view;

@end


/**
 *  实现一个类似于能够对书籍进行排序、分组功能的的书架功能，类似于iphone手机界面对应用图标进行排序、分组。
 */
@interface BookshelfCollectionViewFlowLayout : UICollectionViewFlowLayout


@property (nonatomic, assign)id<BookShelfCollectionViewGestureDelegate> gestureDelegate;


//是否打开重排功能， default is YES
@property (nonatomic, assign)BOOL reorderEnabled;

//是否打开分组功能， default is NO,
@property (nonatomic, assign)BOOL groupEnabled;


//分组界面打开， 用户取消了分组操作，一定要调用此接口 告知
- (void)cancelGroupForItemAtIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath withSnapShotView:(UIView *)snapShotView;

//分组界面打开， 用户完成了分组操作， 一定要调用此接口，告知
- (void)finishedGroupForItemAtIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath ;

@end
