//
//  BookShelfGroupMainView.h
//  ShelfCollectionView
//
//  Created by king.wu on 8/18/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "itemData.h"

@interface BookShelfGroupMainView : UIView

+ (instancetype)loadFromNib;

- (void)initWithItemData:(ItemData *)itemData groupedItemData:(NSArray<ItemData *> *)groupedItemData;

@end
