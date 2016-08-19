//
//  ViewController.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/12/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "ViewController.h"
#import "BookCollectionViewCell.h"

#import "BookshelfCollectionViewFlowLayout.h"
#import "ItemData.h"
#import "BookShelfGroupMainView.h"




@interface ViewController ()<BookShelfCollectionViewDelegateFlowLayout, BookShelfCollectionViewDataSource,BookShelfGroupMainViewDelegate>


@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong)NSMutableArray<ItemData *> *modelSource;

@property (weak, nonatomic)BookshelfCollectionViewFlowLayout *bookShelfFlowLayout;

@property (weak, nonatomic)NSIndexPath *selectedIndexPath;
@property (weak, nonatomic)NSIndexPath *groupIndexPath;
@property (weak, nonatomic)UIView *groupMainView;
@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.collectionView registerNib:[UINib nibWithNibName:@"BookCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"BookCollectionViewCell"];
    

    //UICollectionViewLayoutAttributes
    
    [self.collectionView setCollectionViewLayout:[self createLayout]];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    

    //init modelSource
    float width = [[UIScreen mainScreen]bounds].size.width /3;
    
    self.modelSource = [[NSMutableArray alloc]init];
    for (int i=0; i<100; i++){
        
        float height = width + 50;
//        if (i%3 == 0){
//            height += 15;
//        }else if (i%3 == 1){
//            height += 30;
//        }
        CGSize itemSize = CGSizeMake(width, height);
        ItemData *itemData = [[ItemData alloc]initWithTitle:[NSString stringWithFormat:@"book %d", i] itemSize:itemSize];
        [self.modelSource addObject:itemData];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    
    BookCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BookCollectionViewCell" forIndexPath:indexPath];
    
    [cell initCellWithIndex:[self.modelSource objectAtIndex:indexPath.row].title];
    return cell;
}


- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
 
    return 1;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath*)destinationIndexPath{
    
    id sourceObject = [self.modelSource objectAtIndex:sourceIndexPath.row];
    [self.modelSource removeObjectAtIndex:sourceIndexPath.row];
    [self.modelSource insertObject:sourceObject atIndex:destinationIndexPath.row];
}



#pragma mark - UICollectionViewDelegate


#pragma mark - UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    return [self.modelSource objectAtIndex:indexPath.row].itemSize;
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



//did begin group  itemIndexPath to the groupIndexPath
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout beginGroupForItemAtIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath selectedSnapShotView:(UIView *)snaptShotView{

    self.selectedIndexPath = itemIndexPath;
    self.groupIndexPath = groupIndexPath;
    
    
    BookShelfGroupMainView *groupMainView = [BookShelfGroupMainView loadFromNib];
    [groupMainView initWithItemData:[self.modelSource objectAtIndex:itemIndexPath.row] groupedItemData:@[[self.modelSource objectAtIndex:groupIndexPath.row]] snapView:snaptShotView];

    groupMainView.delegate = self;
    self.groupMainView  = groupMainView;
    
    //书架的手势传给分组界面
    self.bookShelfFlowLayout.gestureDelegate = groupMainView;
    
    
    // 必须这么写， 因为手势都加载collectionView的superView上，collectionView 和 groupMainView需要共用一套手势
    // 因此 groupMainView需要加在collectionView的superView上
    [self.collectionView.superview insertSubview:groupMainView belowSubview:snaptShotView];
    
}

#pragma mark - BookShelfGroupMainViewDelegate
//用户取消了分组操作
- (void)cancelGroupInGroupViewWithItemData:(ItemData *)itemData withGroupData:(NSArray<ItemData *> *)groupItemData withSnapShotView:(UIView *)snapShotView{
    
    //分组界面接收书架界面手势的 回调 注销
    self.bookShelfFlowLayout.gestureDelegate = nil;
    
    //取消分组，用户可能换了一个选中的item，退出来了，这里要处理一下 --todo--
    
    
    //移除分组界面
    [self.groupMainView removeFromSuperview];
    self.groupMainView = nil;
    
    //告知书籍layout,进入分组界面，没有分组，就又退出来了
    [self.bookShelfFlowLayout cancelGroupForItemAtIndexPath:self.selectedIndexPath toGroupIndexPath:self.groupIndexPath withSnapShotView:snapShotView];
}

//用户完成了分组操作
- (void)finishGroupInGroupViewWithGroupData:(NSArray<ItemData *> *)groupItemData{
    //分组界面接收书架界面手势的 回调 注销
      self.bookShelfFlowLayout.gestureDelegate = nil;
    
    
    //合并分组的数据--todo--
    
    
    //删除之前被分组的数据
    [self.modelSource removeObjectAtIndex:self.selectedIndexPath.row];
    //同时删除这个cell
    [self.collectionView deleteItemsAtIndexPaths:@[self.selectedIndexPath]];
    
    //移除分组界面
    [self.groupMainView removeFromSuperview];
    self.groupMainView = nil;
    
    [self.bookShelfFlowLayout finishedGroupForItemAtIndexPath:self.selectedIndexPath toGroupIndexPath:self.groupIndexPath];
}





//
//- (void)longPressGestureRecognizer1:(UILongPressGestureRecognizer *)recognizer{
//    
//    static CGPoint originCenter;
//    if (recognizer.state == UIGestureRecognizerStateBegan){
//        
//        CGPoint location = [recognizer locationInView:self.collectionView];
//        self.preLongGestureLocation = location;
//        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
//    
//        
//        [self.collectionView beginInteractiveMovementForItemAtIndexPath:indexPath];
//        
//        originCenter = [self.collectionView cellForItemAtIndexPath:indexPath].center;
//        
//    }else if (recognizer.state == UIGestureRecognizerStateChanged){
//        
//        CGPoint currentLoction = [recognizer locationInView:self.collectionView];
//        CGPoint offset = CGPointMake(currentLoction.x - self.preLongGestureLocation.x, currentLoction.y - self.preLongGestureLocation.y);
//        
//        //self.preLongGestureLocation = currentLoction;
//        
//        
//        [self.collectionView updateInteractiveMovementTargetPosition:CGPointMake(originCenter.x + offset.x, originCenter.y + offset.y)];
//        
//        
//    }else if (recognizer.state == UIGestureRecognizerStateFailed || recognizer.state == UIGestureRecognizerStateEnded){
//        
//        [self.collectionView endInteractiveMovement];
//    }
//    
//}


- (UIView *)snapShotView:(UIView *)aView{
    UIGraphicsBeginImageContextWithOptions(aView.bounds.size, aView.isOpaque, 0.0f);
    [aView drawViewHierarchyInRect:aView.bounds afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [[UIImageView alloc] initWithImage:image];
}


@end


