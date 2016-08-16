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





@interface ViewController ()<BookShelfCollectionViewDelegateFlowLayout, BookShelfCollectionViewDataSource>


@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong)NSMutableArray *modelSource;

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
    self.modelSource = [[NSMutableArray alloc]init];
    for (int i=0; i<100; i++){
        [self.modelSource addObject:[NSString stringWithFormat:@"book %d", i]];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (UICollectionViewLayout *)createLayout{
    BookshelfCollectionViewFlowLayout *layout = [[BookshelfCollectionViewFlowLayout alloc]init];
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    return layout;
}



#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return [self.modelSource count];;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    
    BookCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BookCollectionViewCell" forIndexPath:indexPath];
    
    [cell initCellWithIndex:[self.modelSource objectAtIndex:indexPath.row]];
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
    
    float width = [[UIScreen mainScreen]bounds].size.width /3;
    float height = width + 50;
//    if (indexPath.row%3 == 0){
//        height += 15;
//    }else if (indexPath.row%3 == 1){
//        height += 30;
//    }
    return CGSizeMake(width, height);
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

@end


