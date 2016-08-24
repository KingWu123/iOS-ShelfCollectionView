//
//  UICollectionView+MathIndexPath.h
//  ShelfCollectionView
//
//  Created by king.wu on 8/23/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UICollectionView (MathIndexPath)

/**
 *  获得collectionView  currentIndexPath的下一个indexPath
 *
 *  @param currentIndexPath currentIndexPath
 *
 *  @return currentIndexPath的下一个indexPath,如果没有，返回nil
 */
- (NSIndexPath *)nextIndexPathByCurrentIndexPath:(NSIndexPath *)currentIndexPath;



/**
 *  获得collectionView  currentIndexPath的上一个indexPath
 *
 *  @param currentIndexPath currentIndexPath
 *
 *  @return currentIndexPath的上一个indexPath,如果没有，返回nil
 */
- (NSIndexPath *)preIndexPathByCurrentIndexPath:(NSIndexPath *)currentIndexPath;



/**
 *  比较两个indexPath的大小
 *
 *  @param indexPath
 *  @param toIndexPath
 *
 *  @return indexPath > toIndexPath 返回1， 相等返回0， 小于返回-1
 */
- (int)compareIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)toIndexPath;

@end
