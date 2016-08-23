//
//  BookCollectionViewCell.h
//  ShelfCollectionView
//
//  Created by king.wu on 8/12/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ItemData.h"

@interface BookCollectionViewCell : UICollectionViewCell


- (void)initCellWithItemData:(ItemData *)itemData;
@end
