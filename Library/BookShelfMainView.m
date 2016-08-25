//
//  BookShelfMainView.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/24/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "BookShelfMainView.h"

#import "BookCollectionViewCell.h"
#import "BookGroupCollectionViewCell.h"

#import "ItemData.h"
#import "BookshelfCollectionViewFlowLayout.h"
#import "BookShelfGroupMainView.h"
#import "UICollectionView+MathIndexPath.h"


@interface BookShelfMainView ()<BookShelfCollectionViewDelegateFlowLayout, BookShelfCollectionViewDataSource,BookShelfGroupMainViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong)NSMutableArray *modelSource;

@property (weak, nonatomic)BookshelfCollectionViewFlowLayout *bookShelfFlowLayout;

@property (weak, nonatomic)NSIndexPath *selectedIndexPath;
@property (weak, nonatomic)NSIndexPath *groupIndexPath;
@property (assign, nonatomic)BOOL isGroupIndexOriginalIsGroup;//被分组的item原先是不是分组item
@property (weak, nonatomic)UIView *groupMainView;

@end

@implementation BookShelfMainView

+ (instancetype)loadFromNib{
    return [[[NSBundle mainBundle]loadNibNamed:@"BookShelfMainView" owner:nil options:nil] objectAtIndex:0];
}

- (void)awakeFromNib{
    [self.collectionView registerNib:[UINib nibWithNibName:@"BookCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"BookCollectionViewCell"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"BookGroupCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"BookGroupCollectionViewCell"];
    
    [self.collectionView setCollectionViewLayout:[self createLayout]];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;

}

- (void)initWithData:(NSArray *)itemDatas{
    self.modelSource = [[NSMutableArray alloc]initWithArray:itemDatas];
}

- (UICollectionViewLayout *)createLayout{
    BookshelfCollectionViewFlowLayout *layout = [[BookshelfCollectionViewFlowLayout alloc]init];
    self.bookShelfFlowLayout = layout;
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    layout.groupEnabled = YES;
    return layout;
}


#pragma mark - UICollectionViewDataSource
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return [self.modelSource count];;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    id itemData = [self.modelSource objectAtIndex:indexPath.row];

    if ([itemData isKindOfClass:[ItemData class]]){
        
        BookCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BookCollectionViewCell" forIndexPath:indexPath];
        [cell initCellWithItemData:itemData];
        return cell;
        
    }else {
        BookGroupCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BookGroupCollectionViewCell" forIndexPath:indexPath];
        [cell initCellWithDatas:itemData];
        return cell;
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath*)destinationIndexPath{
    
    id sourceObject = [self.modelSource objectAtIndex:sourceIndexPath.row];
    [self.modelSource removeObjectAtIndex:sourceIndexPath.row];
    [self.modelSource insertObject:sourceObject atIndex:destinationIndexPath.row];
}

- (BOOL)collectionView:(UICollectionView *)collectionView isGroupedItemAtIndexPath:(NSIndexPath *)indexPath{
    id itemData = [self.modelSource objectAtIndex:indexPath.row];
    if ([itemData isKindOfClass:[NSArray class]]){
        return YES;
    }
    return NO;
}


#pragma mark - UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    id itemData = [self.modelSource objectAtIndex:indexPath.row];
    
    //是否是分组，如果是分组，打开分组
    if ([self collectionView:collectionView isGroupedItemAtIndexPath:indexPath]){
        [self clickToOpenGrouMainViewAtIndexPath:indexPath withData:itemData];
        
    }else{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"打开一本书" message:nil preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:cancelAction];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
}

//点击cell打开分组
- (void)clickToOpenGrouMainViewAtIndexPath:(NSIndexPath *)indexPath withData:(NSArray *)itemDatas{
    
    self.selectedIndexPath = nil;
    self.groupIndexPath = indexPath;
    
    BookShelfGroupMainView *groupMainView = [BookShelfGroupMainView loadFromNib];
    self.isGroupIndexOriginalIsGroup = YES;
    
    [groupMainView initWithItemsData:itemDatas];
    groupMainView.delegate = self;
    self.groupMainView  = groupMainView;
    
    //书架的手势传给分组界面
    self.bookShelfFlowLayout.gestureDelegate = groupMainView;
    [self.bookShelfFlowLayout groupMainViewClickedOpened];
    
    // 必须这么写， 因为手势都加载collectionView的superView上，collectionView 和 groupMainView需要共用一套手势
    // 因此 groupMainView需要加在collectionView的superView上
    [self.collectionView.superview addSubview:groupMainView];
    groupMainView.frame = self.collectionView.superview.bounds;
    [self openGroupMainView:groupMainView];

}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    id itemData = [self.modelSource objectAtIndex:indexPath.row];
    
    if ([itemData isKindOfClass:[ItemData class]]){
        return ((ItemData *)[self.modelSource objectAtIndex:indexPath.row]).itemSize;
    }else{
        float width = [[UIScreen mainScreen]bounds].size.width /3;
        float height = width + 50;
        return  CGSizeMake(width, height);
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}

//did begin group  itemIndexPath to the groupIndexPath, with snapShotView
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout beginGroupForItemAtIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath selectedSnapShotView:(UIView *)snaptShotView{
    
    self.selectedIndexPath = itemIndexPath;
    self.groupIndexPath = groupIndexPath;
    
    
    BookShelfGroupMainView *groupMainView = [BookShelfGroupMainView loadFromNib];
    id groupData = [self.modelSource objectAtIndex:groupIndexPath.row];
    if (![groupData isKindOfClass:[NSArray class]]){
        groupData = @[groupData];
        self.isGroupIndexOriginalIsGroup = NO;
    }else{
        self.isGroupIndexOriginalIsGroup = YES;
    }
    
    [groupMainView initWithItemData:[self.modelSource objectAtIndex:itemIndexPath.row] groupedItemData:groupData snapView:snaptShotView];
    
    groupMainView.delegate = self;
    self.groupMainView  = groupMainView;
    
    //书架的手势传给分组界面
    self.bookShelfFlowLayout.gestureDelegate = groupMainView;
    
    // 必须这么写， 因为手势都加载collectionView的superView上，collectionView 和 groupMainView需要共用一套手势
    // 因此 groupMainView需要加在collectionView的superView上
    [self.collectionView.superview insertSubview:groupMainView belowSubview:snaptShotView];
    groupMainView.frame = self.collectionView.superview.bounds;
    [self openGroupMainView:groupMainView];
}


//add itemIndexPath to groupIndexPath mmediately, add open groupMainView.
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout addItemAtIndexPath:(NSIndexPath *)itemIndexPath andOpenGroupAtIndexPath:(NSIndexPath *)groupIndexPath{
    
    id itemData = [self.modelSource objectAtIndex:itemIndexPath.row];
    id groupData = [self.modelSource objectAtIndex:groupIndexPath.row];
    
    
    //删除这个item数据 和 cell
    [self.modelSource removeObject:itemData];
    [self.collectionView deleteItemsAtIndexPaths:@[itemIndexPath]];
    
    //groupindex是否前移
    if ([self.collectionView compareIndexPath:itemIndexPath toIndexPath:groupIndexPath] < 0){
        groupIndexPath = [self.collectionView preIndexPathByCurrentIndexPath:groupIndexPath];
    }
    
    //打开分组
    [self clickToOpenGrouMainViewAtIndexPath:groupIndexPath withData:@[groupData, itemData]];
    self.isGroupIndexOriginalIsGroup = NO;
}


//add itemIndexPath to groupIndexPath mmediately, and not open groupMainView.
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout addItemAtIndexPath:(NSIndexPath *)itemIndexPath unOpenGroupAtIndexPath:(NSIndexPath *)groupIndexPath{
    
    id groupData = [self.modelSource objectAtIndex:groupIndexPath.row];
    id itemData = [self.modelSource objectAtIndex:itemIndexPath.row];
    
    if(![groupData isKindOfClass:[NSArray class]]){
        return;
    }
    
    //将数据添加到group中
    NSMutableArray *tempGroupArr = [[NSMutableArray alloc]initWithArray:groupData];
    [tempGroupArr addObject:itemData];
    [self.modelSource replaceObjectAtIndex:groupIndexPath.row withObject:tempGroupArr];

    //删除这个item数据
    [self.modelSource removeObject:itemData];
   
    //更新分组item和 groupItem
    [self.collectionView performBatchUpdates:^{
        [self.collectionView deleteItemsAtIndexPaths:@[itemIndexPath]];
        [self.collectionView reloadItemsAtIndexPaths:@[groupIndexPath]];
    } completion:nil];
    
    
    //告知书籍layout,分组完成
    [self.bookShelfFlowLayout finishedGroupForItemAtIndexPath:self.selectedIndexPath toGroupIndexPath:self.groupIndexPath];

}



#pragma mark - BookShelfGroupMainViewDelegate
//用户取消了分组操作
- (void)cancelGroupInGroupViewWithItemData:(ItemData *)itemData withGroupData:(NSArray<ItemData *> *)groupItemData withSnapShotView:(UIView *)snapShotView{
    
    //分组界面接收书架界面手势的 回调 注销
    self.bookShelfFlowLayout.gestureDelegate = nil;
    
    //self.selectedIndexPath ==nil,表示从cell click打开，此时拖动一个item从分组界面出来，没有位置可以插入这个，在groupIndex前面插入一个位置，放拖出来的item
    if (self.selectedIndexPath == nil){
        [self.modelSource insertObject:itemData atIndex:self.groupIndexPath.row];
        [self.collectionView insertItemsAtIndexPaths:@[self.groupIndexPath]];
        
        self.selectedIndexPath = self.groupIndexPath;
        self.groupIndexPath = [self.collectionView nextIndexPathByCurrentIndexPath:self.selectedIndexPath];
    }else{
        
        //取消分组，用户可能换了一个选中的item，退出来了，这里要处理一下.
        [self.modelSource replaceObjectAtIndex:self.selectedIndexPath.row withObject:itemData];
    }
    
    
    //如果之前是分组，直接换array数据
    if (self.isGroupIndexOriginalIsGroup){
        //如果分组里还有数据
        if ([groupItemData count] != 0){
            [self.modelSource replaceObjectAtIndex:self.groupIndexPath.row withObject:groupItemData];
        }else{
            [self.modelSource removeObjectAtIndex:self.groupIndexPath.row];
            [self.collectionView deleteItemsAtIndexPaths:@[self.groupIndexPath]];
        }
        
    }else{
        //如果分组前， groupitem本身不是个分组，则取消退出来后，也要不是个分组
        [self.modelSource replaceObjectAtIndex:self.groupIndexPath.row withObject:[groupItemData objectAtIndex:0]];
    }
    
    //collectionView reload data
    [self.collectionView reloadItemsAtIndexPaths:@[self.selectedIndexPath, self.groupIndexPath]];
    
    
    //告知书籍layout,进入分组界面，没有分组，就又退出来了
    [self.bookShelfFlowLayout cancelGroupForItemAtIndexPath:self.selectedIndexPath toGroupIndexPath:self.groupIndexPath withSnapShotView:snapShotView];
    
    //关闭分组界面
    [self closeGroupMainView:self.groupMainView];
    
    self.groupIndexPath = nil;
    self.selectedIndexPath = nil;
}

//用户完成了分组操作
- (void)finishGroupInGroupViewWithGroupData:(NSArray<ItemData *> *)groupItemData{
    //分组界面接收书架界面手势的 回调 注销
    self.bookShelfFlowLayout.gestureDelegate = nil;
    
    //合并分组的数据
    [self.modelSource replaceObjectAtIndex:self.groupIndexPath.row withObject:groupItemData];
    
    //self.selectedIndexPath != nil表示是进行分组时，进入分组界面，==nil,表示从cell click打开
    if (self.selectedIndexPath != nil){
        //删除之前被分组的数据
        [self.modelSource removeObjectAtIndex:self.selectedIndexPath.row];
        
        //collectionView reloadData
        [self.collectionView performBatchUpdates:^{
            [self.collectionView deleteItemsAtIndexPaths:@[self.selectedIndexPath]];
            [self.collectionView reloadItemsAtIndexPaths: @[self.groupIndexPath]];
        } completion:nil];
    }else{
        [self.collectionView reloadItemsAtIndexPaths: @[self.groupIndexPath]];
    }
    
    //上面的操作有可能 groupIndexPath变了，这里需要调一下
    if ([self.collectionView compareIndexPath:self.selectedIndexPath toIndexPath:self.groupIndexPath] < 0){
        self.groupIndexPath = [self.collectionView preIndexPathByCurrentIndexPath:self.groupIndexPath];
    }
    
    //告知书籍layout,进入分组界面，进行了分组
    [self.bookShelfFlowLayout finishedGroupForItemAtIndexPath:self.selectedIndexPath toGroupIndexPath:self.groupIndexPath];
    
    //移除分组界面
    [self closeGroupMainView:self.groupMainView];
    
    
    self.selectedIndexPath = nil;
    self.groupIndexPath = nil;
}


#pragma mark - assist method
//打开分组界面
- (void)openGroupMainView:(UIView *)groupMainView{
    
    groupMainView.alpha = 0.0;
    [UIView animateWithDuration:0.3 delay:0.0 options:(UIViewAnimationOptionCurveLinear) animations:^{
        groupMainView.alpha = 1.0;
    } completion:^(BOOL finished) {
        
    }];
}

//关闭分组界面
- (void)closeGroupMainView:(UIView *)groupMainView{
    groupMainView.alpha = 1.0;
    [UIView animateWithDuration:0.3 delay:0.0 options:(UIViewAnimationOptionCurveLinear) animations:^{
        groupMainView.alpha = 0.0;
    } completion:^(BOOL finished) {
        //移除分组界面
        [self.groupMainView removeFromSuperview];
        self.groupMainView = nil;
    }];
}

@end
