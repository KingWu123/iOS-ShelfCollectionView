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

/**
 *  打开分组的方式有3种：
 *  1. 直接点击cell打开，
 *  2. 拖动一个item到分组，手松开，分组打开。
 *  3. 拖动一个item到分组，手没有松开，带着item的snapShot，分组打开。
 *  不管已什么方式打开，都是： 如果有选中的item，把item的数据合并到groupData里； 然后初始化分组界面，并打开分组；分组动画完后， 删除itemIndexPath对于的cell。
 *
 * 取消分组：取消分组后， 在groupIndex前插入一个indexPath,让拖出来的item有位置可以放置
 *
 * 分组完成：退出分组界面，刷新数据
 */


@interface BookShelfMainView ()<BookShelfCollectionViewDelegateFlowLayout, BookShelfCollectionViewDataSource,BookShelfGroupMainViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic)BookShelfGroupMainView *groupMainView;

@property (nonatomic, weak)BookshelfCollectionViewFlowLayout *bookShelfFlowLayout;

@property (nonatomic, strong)NSMutableArray *modelSource;
@property (nonatomic, strong)NSIndexPath *groupIndexPath;
@property (nonatomic, assign)BOOL isGroupIndexOriginalIsGroup;//被分组的item原先是不是分组item


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
        
        
        self.groupIndexPath = indexPath;
        self.isGroupIndexOriginalIsGroup = YES;
        
        [self.bookShelfFlowLayout groupMainViewWillOpened];
        [self openGroupWithData:itemData withSnapShotView:nil completion:^(BOOL finished) {
            [self.bookShelfFlowLayout groupMainViewDidOpened];
        }];
    
    }else{
        //打开书籍
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"打开一本书" message:nil preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:cancelAction];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
}




#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    float width = [[UIScreen mainScreen]bounds].size.width /3;
    float height = width + 50;
    return  CGSizeMake(width, height);
    
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
//打开分组界面，此时手势没有松开，还可以继续移动选中的书籍
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout beginGroupForItemAtIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath selectedSnapShotView:(UIView *)snaptShotView{
    
    
    NSMutableArray *tempGroupData = nil;
    
    id groupData = [self.modelSource objectAtIndex:groupIndexPath.row];
    if (![groupData isKindOfClass:[NSArray class]]){
        tempGroupData = [[NSMutableArray alloc]initWithObjects:groupData, nil];
        self.isGroupIndexOriginalIsGroup = NO;
    }else{
        tempGroupData = [[NSMutableArray alloc]initWithArray:groupData];
        self.isGroupIndexOriginalIsGroup = YES;
    }
    
    id itemData = [self.modelSource objectAtIndex:itemIndexPath.row];
    [tempGroupData addObject:itemData];
    
    
    self.groupIndexPath = groupIndexPath;
    
    [self.bookShelfFlowLayout groupMainViewWillOpened];
    //打开分组
    [self openGroupWithData:tempGroupData withSnapShotView:snaptShotView completion:^(BOOL finished) {
        
        [self.bookShelfFlowLayout groupMainViewDidOpened];
        
        //分组打开后，之前选中的item删除掉
        [self.modelSource removeObject:itemData];
        [self.collectionView deleteItemsAtIndexPaths:@[itemIndexPath]];
        
        //groupindex是否前移
        if ([self.collectionView compareIndexPath:itemIndexPath toIndexPath:groupIndexPath] < 0){
            self.groupIndexPath = [self.collectionView preIndexPathByCurrentIndexPath:groupIndexPath];
        }

        
    }];
    
    
}


//add itemIndexPath to groupIndexPath mmediately, add open groupMainView.
//打开分组界面，在此之前，手已经松开。此时groupIndexPath cell一定不是一个分组
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout addItemAtIndexPath:(NSIndexPath *)itemIndexPath andOpenGroupAtIndexPath:(NSIndexPath *)groupIndexPath{

    id itemData = [self.modelSource objectAtIndex:itemIndexPath.row];
    id groupData = [self.modelSource objectAtIndex:groupIndexPath.row];
    
    
    NSMutableArray *tempGroupData = [[NSMutableArray alloc]init];
    [tempGroupData addObject:groupData];
    [tempGroupData addObject:itemData];
    
    self.isGroupIndexOriginalIsGroup = NO;
    self.groupIndexPath = groupIndexPath;
    
    [self.bookShelfFlowLayout groupMainViewWillOpened];
    //打开分组
    [self openGroupWithData:tempGroupData withSnapShotView:nil completion:^(BOOL finished) {
        
        [self.bookShelfFlowLayout groupMainViewDidOpened];
        
        //删除这个item数据 和 cell
        [self.modelSource removeObject:itemData];
        [self.collectionView deleteItemsAtIndexPaths:@[itemIndexPath]];
        
        //groupindex是否前移
        if ([self.collectionView compareIndexPath:itemIndexPath toIndexPath:groupIndexPath] < 0){
            self.groupIndexPath = [self.collectionView preIndexPathByCurrentIndexPath:groupIndexPath];
        }
        
        
    }];
}


//add itemIndexPath to groupIndexPath mmediately, and not open groupMainView.
//不用打开分组界面，直接进行分组的数据操作即可，在此之前，手已经松开
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
    
    
    
    //groupindex是否前移
    if ([self.collectionView compareIndexPath:itemIndexPath toIndexPath:groupIndexPath] < 0){
        self.groupIndexPath = [self.collectionView preIndexPathByCurrentIndexPath:groupIndexPath];
    }
    //告知书籍layout,分组完成
    [self.bookShelfFlowLayout finishedGroupForItemAtGroupIndexPath:self.groupIndexPath];
    self.groupIndexPath = nil;
}



#pragma mark - BookShelfGroupMainViewDelegate
//用户取消了分组操作
- (void)cancelGroupInGroupViewWithItemData:(ItemData *)itemData withGroupData:(NSArray<ItemData *> *)groupItemData withSnapShotView:(UIView *)snapShotView{
    

    //分组取消回来，item没有位置可以放，在groupIndex前放一个itemIndex
    [self.modelSource insertObject:itemData atIndex:self.groupIndexPath.row];
    [self.collectionView insertItemsAtIndexPaths:@[self.groupIndexPath]];
        
    NSIndexPath *selectedIndexPath  = self.groupIndexPath;
    self.groupIndexPath = [self.collectionView nextIndexPathByCurrentIndexPath:selectedIndexPath];

 
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
    [self.collectionView reloadItemsAtIndexPaths:@[selectedIndexPath, self.groupIndexPath]];
    
    
    //告知书籍layout,进入分组界面，没有分组，就又退出来了
    [self.bookShelfFlowLayout cancelGroupForItemAtIndexPath:selectedIndexPath toGroupIndexPath:self.groupIndexPath withSnapShotView:snapShotView];
    
    //关闭分组界面
    [self closeGroupMainView:self.groupMainView];
    
    self.groupIndexPath = nil;
}

//用户完成了分组操作
- (void)finishGroupInGroupViewWithGroupData:(NSArray<ItemData *> *)groupItemData{

    //合并分组的数据
    [self.modelSource replaceObjectAtIndex:self.groupIndexPath.row withObject:groupItemData];
    [self.collectionView reloadItemsAtIndexPaths: @[self.groupIndexPath]];
    
    
    //告知书籍layout,进入分组界面，进行了分组
    [self.bookShelfFlowLayout finishedGroupForItemAtGroupIndexPath:self.groupIndexPath];
    
    //移除分组界面
    [self closeGroupMainView:self.groupMainView];
    
    self.groupIndexPath = nil;
}


#pragma mark - assist method
//打开分组
- (void)openGroupWithData:(NSArray *)itemDatas withSnapShotView:(UIView *)snapShotView completion:(void (^ __nullable)(BOOL finished))completion {
    
    
    BookShelfGroupMainView *groupMainView = [BookShelfGroupMainView loadFromNib];
    groupMainView.delegate = self;
    self.groupMainView  = groupMainView;
    
    //书架的手势传给分组界面
    self.bookShelfFlowLayout.gestureDelegate = groupMainView;
    
    //初始化数据
    [groupMainView initWithItemsData:itemDatas snapView:snapShotView];
   
    
    // 必须这么写， 因为手势都加载collectionView的superView上，collectionView 和 groupMainView需要共用一套手势
    // 因此 groupMainView需要加在collectionView的superView上
    [self.collectionView.superview addSubview:groupMainView];
    groupMainView.frame = self.collectionView.superview.bounds;
    
    
    //groupView打开的动画
    groupMainView.alpha = 0.0;
    [UIView animateWithDuration:0.3 delay:0.0 options:(UIViewAnimationOptionCurveLinear) animations:^{
        groupMainView.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (completion != nil){
            completion(finished);
        }
    }];
    
}


//关闭分组界面
- (void)closeGroupMainView:(UIView *)groupMainView{
    
    self.groupMainView.delegate = nil;
    
    //分组界面接收书架界面手势的 回调 注销
    self.bookShelfFlowLayout.gestureDelegate = nil;
    
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
