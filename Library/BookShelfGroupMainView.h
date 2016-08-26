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


/**
 *  打开分组界面的初始化方法
 *
 *  @param groupedItemData 分组里包含的所有的数据
 *  @param snapView        从书架选中的书籍的截图，不为nil, 表面最后一个item被选中，要能直接进行拖动
 *
 *  （注：初始化时，groupedItemData的最后一项必须是要被进行分组的itemData）
 */
- (void)initWithItemsData:(NSArray<ItemData *> *)groupedItemData snapView:(UIView *)snapView;

@end
