//
//  BookShelfGroupMainView.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/18/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "BookShelfGroupMainView.h"
#import "BookshelfCollectionViewFlowLayout.h"
#import "BookCollectionViewCell.h"

@interface BookShelfGroupMainView ()<BookShelfCollectionViewDelegateFlowLayout, BookShelfCollectionViewDataSource>


@property (weak, nonatomic) IBOutlet UIView *backgroundView;

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UITextField *groupTitleTextFiled;


@property (strong, nonatomic)NSMutableArray<ItemData *> * allGroupItems;
@end


@implementation BookShelfGroupMainView

+ (instancetype)loadFromNib{
    return [[[NSBundle mainBundle]loadNibNamed:@"BookShelfGroupMainView" owner:nil options:nil] objectAtIndex:0];
}



- (void)awakeFromNib{
    [self.collectionView registerNib:[UINib nibWithNibName:@"BookCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"BookCollectionViewCell"];

    
    BookshelfCollectionViewFlowLayout *layout = [[BookshelfCollectionViewFlowLayout alloc]init];
    [self.collectionView setCollectionViewLayout:layout];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    
    self.allGroupItems = [[NSMutableArray alloc]init];
}


- (void)initWithItemData:(ItemData *)itemData groupedItemData:(NSArray<ItemData *> *)groupedItemData{
    [self.allGroupItems removeAllObjects];
    [self.allGroupItems addObjectsFromArray:groupedItemData];
    [self.allGroupItems addObject:itemData];
    
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



@end
