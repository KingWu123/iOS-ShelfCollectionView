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
- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

@end


@protocol BookShelfCollectionViewDelegateFlowLayout <UICollectionViewDelegateFlowLayout>

@optional

@end

/**
 *  实现一个类似于能够对书籍进行排序， 分组功能的的书架功能，类似于iphone手机界面对应用图标进行排序，分组。
 */
@interface BookshelfCollectionViewFlowLayout : UICollectionViewFlowLayout

@end
