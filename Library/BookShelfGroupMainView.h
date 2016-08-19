//
//  BookShelfGroupMainView.h
//  ShelfCollectionView
//
//  Created by king.wu on 8/18/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "itemData.h"
#import "BookshelfCollectionViewFlowLayout.h"

@protocol BookShelfGroupMainViewDelegate <NSObject>

//用户取消了分组操作
- (void)cancelGroupInGroupViewWithItemData:(ItemData *)itemData withGroupData:(NSArray<ItemData *> *)groupItemData withSnapShotView:(UIView *)snapShotView;

//用户完成了分组操作
- (void)finishGroupInGroupViewWithGroupData:(NSArray<ItemData *> *)groupItemData;


@end



@interface BookShelfGroupMainView : UIView<BookShelfCollectionViewGestureDelegate>

@property (nonatomic, assign)id<BookShelfGroupMainViewDelegate> delegate;

+ (instancetype)loadFromNib;

- (void)initWithItemData:(ItemData *)itemData groupedItemData:(NSArray<ItemData *> *)groupedItemData snapView:(UIView *)snapView;


@end
