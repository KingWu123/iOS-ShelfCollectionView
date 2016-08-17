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


@interface ItemData : NSObject

@property (nonatomic, strong)NSString *title;
@property (nonatomic, assign)CGSize itemSize;

- (instancetype)initWithTitle:(NSString *)title itemSize:(CGSize)itemSize;
@end
@implementation ItemData
- (instancetype)initWithTitle:(NSString *)title itemSize:(CGSize)itemSize{
    self = [super init];
    if (self){
        self.title = title;
        self.itemSize = itemSize;
    }
    return self;
}
@end


@interface ViewController ()<BookShelfCollectionViewDelegateFlowLayout, BookShelfCollectionViewDataSource>


@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong)NSMutableArray<ItemData *> *modelSource;

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



- (UIView *)collectionView:(UICollectionView *)collectionView viewForGroupItemAtIndexPath:(NSIndexPath *)indexPath{
    
    UICollectionViewCell *groupCell = [self.collectionView cellForItemAtIndexPath:indexPath];
    
    UIView * groupBackgroundView = [[UIView alloc]initWithFrame:groupCell.bounds];
    groupBackgroundView.backgroundColor = [UIColor redColor];
    UIView *snapShot = [self snapShotView:groupCell];
    snapShot.frame = CGRectMake(2, 2, groupCell.frame.size.width/3, groupCell.frame.size.height/3);
    [groupBackgroundView addSubview:snapShot];
    
  
    return groupBackgroundView;
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



#pragma mark - UICollectionViewDelegateFlowLayout



//did begin group  itemIndexPath to the groupIndexPath
- (void)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout didBeginGroupItemIndexPath:(NSIndexPath *)itemIndexPath toGroupIndexPath:(NSIndexPath *)groupIndexPath{
    
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


