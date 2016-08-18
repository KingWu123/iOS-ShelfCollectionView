//
//  BookShelfGroupMainView.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/18/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "BookShelfGroupMainView.h"
#import "BookCollectionViewCell.h"
#import "BookShelfGroupViewFlowLayout.h"

@interface BookShelfGroupMainView ()<BookShelfGroupViewDataSource, BookShelfGroupViewDelegateFlowLayout>


@property (weak, nonatomic) IBOutlet UIView *backgroundView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UITextField *groupTitleTextFiled;

@property (strong, nonatomic)BookShelfGroupViewFlowLayout *groupFlowLayout;

@property (strong, nonatomic)NSMutableArray<ItemData *> * allGroupItems;


@property (nonatomic, strong) UIView* selectedSnapShotView;//选中的item的snapShotView

@end


@implementation BookShelfGroupMainView

+ (instancetype)loadFromNib{
    return [[[NSBundle mainBundle]loadNibNamed:@"BookShelfGroupMainView" owner:nil options:nil] objectAtIndex:0];
}



- (void)awakeFromNib{
    [self.collectionView registerNib:[UINib nibWithNibName:@"BookCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"BookCollectionViewCell"];


    self.groupFlowLayout = [[BookShelfGroupViewFlowLayout alloc]init];
    [self.collectionView setCollectionViewLayout:self.groupFlowLayout];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;

    self.allGroupItems = [[NSMutableArray alloc]init];
}


- (void)initWithItemData:(ItemData *)itemData groupedItemData:(NSArray<ItemData *> *)groupedItemData snapView:(UIView *)snapView{

    [self.allGroupItems removeAllObjects];
    [self.allGroupItems addObjectsFromArray:groupedItemData];
    [self.allGroupItems addObject:itemData];
    
    
    self.selectedSnapShotView =  snapView;
    
    [self addSubview:self.selectedSnapShotView];
    
    [self.collectionView reloadData];
}




#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return [self.allGroupItems count];;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    BookCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BookCollectionViewCell" forIndexPath:indexPath];
    
    [cell initCellWithIndex:[self.allGroupItems objectAtIndex:indexPath.row].title];
    return cell;
}


- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath*)destinationIndexPath{
    
    id sourceObject = [self.allGroupItems objectAtIndex:sourceIndexPath.row];
    [self.allGroupItems removeObjectAtIndex:sourceIndexPath.row];
    [self.allGroupItems insertObject:sourceObject atIndex:destinationIndexPath.row];
}

#pragma mark - UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    return [self.allGroupItems objectAtIndex:indexPath.row].itemSize;
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



//进行分组时，分组界面需要利用书架界面传过来的手势进行处理。
#pragma mark - BookShelfCollectionViewGestureDelegate

- (void)handleLongPressGesture:(UILongPressGestureRecognizer *)gestureRecognizer inGestureView:(UIView*)view{
   
    [self.groupFlowLayout handleLongPressGesture:gestureRecognizer];
    
     CGPoint location = [gestureRecognizer locationInView:view];
    NSLog(@"groupView gesture x = %f, y = %f", location.x, location.y);
}


- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer inGestureView:(UIView *)view{
    
    [self.groupFlowLayout handlePanGesture:gestureRecognizer];
    
    CGPoint location = [gestureRecognizer locationInView:view];
    NSLog(@"groupView gesture x = %f, y = %f", location.x, location.y);
}


@end
