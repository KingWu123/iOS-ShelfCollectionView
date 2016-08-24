//
//  UICollectionView+MathIndexPath.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/23/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "UICollectionView+MathIndexPath.h"

@implementation UICollectionView (MathIndexPath)


/**
 *  获得collectionView  currentIndexPath的下一个indexPath
 *
 *  @param currentIndexPath currentIndexPath
 *
 *  @return currentIndexPath的下一个indexPath,如果没有，返回nil
 */
- (NSIndexPath *)nextIndexPathByCurrentIndexPath:(NSIndexPath *)currentIndexPath{
    
    NSInteger currentRow = currentIndexPath.row;
    NSInteger currentSection = currentIndexPath.section;
    NSInteger totalRowAtCurrentSection = [self numberOfItemsInSection:currentSection];
    if (currentRow < totalRowAtCurrentSection -1){
        return [NSIndexPath indexPathForRow:currentRow + 1 inSection:currentSection];
    }else{
        if (currentSection < [self numberOfSections] - 1){
            return [NSIndexPath indexPathForRow:0 inSection:currentSection + 1];
        }
    }
    
    return nil;
}

/**
 *  获得collectionView  currentIndexPath的上一个indexPath
 *
 *  @param currentIndexPath currentIndexPath
 *
 *  @return currentIndexPath的上一个indexPath,如果没有，返回nil
 */
- (NSIndexPath *)preIndexPathByCurrentIndexPath:(NSIndexPath *)currentIndexPath{
    
    NSInteger currentRow = currentIndexPath.row;
    NSInteger currentSection = currentIndexPath.section;
    
    if (currentRow > 0){
        return [NSIndexPath indexPathForRow:currentRow -1 inSection:currentSection];
    }else{
        if (currentSection > 0){
            NSInteger preRow = [self numberOfItemsInSection: currentSection -1];
            return  [NSIndexPath indexPathForRow:preRow -1 inSection:currentSection];
        }
    }
    
    return nil;
}



/**
 *  比较两个indexPath的大小
 *
 *  @param indexPath
 *  @param toIndexPath
 *
 *  @return indexPath > toIndexPath 返回1， 相等返回0， 小于返回-1
 */
- (int)compareIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)toIndexPath{
   
    if (indexPath == nil || toIndexPath ==nil){
        return 0;
    }
    
    if (toIndexPath.section > indexPath.section || (toIndexPath.section == indexPath.section && toIndexPath.row > indexPath.row)){
        return -1;
    }else if (toIndexPath.section == indexPath.section && toIndexPath.row == indexPath.row){
        return 0;
    }else{
        return 1;
    }
}



@end
