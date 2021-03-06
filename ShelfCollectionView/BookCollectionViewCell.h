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

+ (instancetype)loadFromNib;

- (void)initCellWithItemData:(ItemData *)itemData;

@end
