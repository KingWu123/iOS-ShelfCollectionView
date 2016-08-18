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



//itemIndexPath to the groupIndexPath, 用于变跟分组数据
- (void)collectionView:(UICollectionView *)collectionView itemIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath;

@end


@protocol BookShelfCollectionViewDelegateFlowLayout <UICollectionViewDelegateFlowLayout>

@optional

//begin movement
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout beginMovementForItemAtIndexPath:(NSIndexPath *)indexPath;

//end movement
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout endMovementForItemAtIndexPath:(NSIndexPath *)indexPath;



@end




/**
 *  实现一个类似于能够对书籍进行排序、分组功能的的书架功能，类似于iphone手机界面对应用图标进行排序、分组。
 */
@interface BookshelfCollectionViewFlowLayout : UICollectionViewFlowLayout

//是否打开重排功能， default is YES
@property (nonatomic, assign)BOOL reorderEnabled;

//是否打开分组功能， default is NO,
@property (nonatomic, assign)BOOL groupEnabled;

@end
