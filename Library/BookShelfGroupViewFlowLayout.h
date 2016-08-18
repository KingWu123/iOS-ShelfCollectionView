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


@end



@interface BookShelfGroupViewFlowLayout : UICollectionViewFlowLayout

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)recognizer;
- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer;


@end
