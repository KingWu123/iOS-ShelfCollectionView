//
//  ViewController.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/12/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "ViewController.h"
#import "BookCollectionViewCell.h"

@interface ViewController ()<UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIScrollViewDelegate>


@property (weak, nonatomic) IBOutlet UICollectionView *collcetionView;
@property (nonatomic, strong)NSMutableArray *modelSource;


@property (nonatomic, assign)NSIndexPath *selectedCellCurrentIndexPath;//选中cell，当前所在的indexPath
@property (nonatomic, assign)NSIndexPath *selectedCellOriginIndexPath;//选中的cell，被选中的一刹那时的 indexPath
@property (nonatomic, weak)UIImageView *selectedCellSnapImageView;//选中的cell的截图
@property (nonatomic, assign)CGPoint preLongGestureLocation;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.collcetionView registerNib:[UINib nibWithNibName:@"BookCollectionViewCell" bundle:nil] forCellWithReuseIdentifier:@"BookCollectionViewCell"];
    

    
    //UICollectionViewTransitionLayout
    //UICollectionViewLayoutAttributes
   // [self.collcetionView setCollectionViewLayout:[self createLayout]];
    
    
    self.collcetionView.delegate = self;
    self.collcetionView.dataSource = self;
    
    UILongPressGestureRecognizer *longGestrue = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPressGestureRecognizer1:)];
    [self.collcetionView addGestureRecognizer:longGestrue];
    longGestrue.delegate = self;
    
    //init modelSource
    self.modelSource = [[NSMutableArray alloc]init];
    for (int i=0; i<50; i++){
        [self.modelSource addObject:[NSString stringWithFormat:@"book %d", i]];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UICollectionViewLayout *)createLayout{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc]init];
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    [layout setMinimumLineSpacing:0];
    [layout setMinimumInteritemSpacing:0];
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
    return CGSizeMake(width, width + 50);
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


#pragma mark - UILongPressGestureRecognizer
- (void)longPressGestureRecognizer:(UILongPressGestureRecognizer *)recognizer{
    
    if (recognizer.state == UIGestureRecognizerStateBegan){
        
        CGPoint location = [recognizer locationInView:self.collcetionView];
        self.preLongGestureLocation = location;
        
        //selected cell and current indexPath
        NSIndexPath *indexPath = [self.collcetionView indexPathForItemAtPoint:location];
        self.selectedCellCurrentIndexPath = self.selectedCellOriginIndexPath = indexPath;
        BookCollectionViewCell *cell = (BookCollectionViewCell *)[self.collcetionView cellForItemAtIndexPath:indexPath];
        
        //cell snap imageView
        UIImage *image = [self snapImageOfView:cell scale:0.0];
        UIImageView *imageView = [[UIImageView alloc]initWithImage:image];
        imageView.frame = CGRectMake(cell.frame.origin.x, cell.frame.origin.y - 2, cell.frame.size.width, cell.frame.size.height);
        [self.collcetionView addSubview:imageView];
        self.selectedCellSnapImageView = imageView;
        
        //hidden cell
        [cell setHidden:YES];
        
    }else if (recognizer.state == UIGestureRecognizerStateChanged){

        //move offset
        CGPoint currentLoction = [recognizer locationInView:self.collcetionView];
        CGPoint offset = CGPointMake(currentLoction.x - self.preLongGestureLocation.x, currentLoction.y - self.preLongGestureLocation.y);
        
        //update selectedCellSnapImageView frame
        CGRect selectedImgViewFrame = self.selectedCellSnapImageView.frame;
        selectedImgViewFrame.origin = CGPointMake(selectedImgViewFrame.origin.x + offset.x, selectedImgViewFrame.origin.y + offset.y);
        self.selectedCellSnapImageView.frame = selectedImgViewFrame;
        
        self.preLongGestureLocation = currentLoction;
        
       
        //adjust collectionViewCell
        [self adjustCollectionViewCell:currentLoction];
    
    }else if (recognizer.state == UIGestureRecognizerStateFailed || recognizer.state == UIGestureRecognizerStateEnded){
        
        CGPoint currentLoction = [recognizer locationInView:self.collcetionView];
        NSIndexPath *destIndexPath = [self.collcetionView indexPathForItemAtPoint:currentLoction];
        
        //交换数据
        [self collectionView:self.collcetionView moveItemAtIndexPath:self.selectedCellOriginIndexPath toIndexPath:destIndexPath];
        
        
        BookCollectionViewCell *cell = (BookCollectionViewCell *)[self.collcetionView cellForItemAtIndexPath:self.selectedCellCurrentIndexPath];
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            
            self.selectedCellSnapImageView.frame = cell.frame;
        } completion:^(BOOL finished) {
            [self.selectedCellSnapImageView removeFromSuperview];
            self.selectedCellSnapImageView = nil;
           
            [cell setHidden:NO];

        }];

    }
    
}

- (void)adjustCollectionViewCell:(CGPoint)currentLocation{
    NSIndexPath *destIndexPath = [self.collcetionView indexPathForItemAtPoint:currentLocation];
  
    if (destIndexPath.row != self.selectedCellCurrentIndexPath.row
        || destIndexPath.section != self.selectedCellCurrentIndexPath.section){
    
        [self.collcetionView moveItemAtIndexPath:self.selectedCellCurrentIndexPath toIndexPath:destIndexPath];
   
        self.selectedCellCurrentIndexPath = destIndexPath;
    }

}






- (void)longPressGestureRecognizer1:(UILongPressGestureRecognizer *)recognizer{
    
    static CGPoint originCenter;
    if (recognizer.state == UIGestureRecognizerStateBegan){
        
        CGPoint location = [recognizer locationInView:self.collcetionView];
        self.preLongGestureLocation = location;
        NSIndexPath *indexPath = [self.collcetionView indexPathForItemAtPoint:location];
    
        
        [self.collcetionView beginInteractiveMovementForItemAtIndexPath:indexPath];
        
        originCenter = [self.collcetionView cellForItemAtIndexPath:indexPath].center;
        
    }else if (recognizer.state == UIGestureRecognizerStateChanged){
        
        CGPoint currentLoction = [recognizer locationInView:self.collcetionView];
        CGPoint offset = CGPointMake(currentLoction.x - self.preLongGestureLocation.x, currentLoction.y - self.preLongGestureLocation.y);
        
        //self.preLongGestureLocation = currentLoction;
        
        
        [self.collcetionView updateInteractiveMovementTargetPosition:CGPointMake(originCenter.x + offset.x, originCenter.y + offset.y)];
        
        
    }else if (recognizer.state == UIGestureRecognizerStateFailed || recognizer.state == UIGestureRecognizerStateEnded){
        
        [self.collcetionView endInteractiveMovement];
    }
    
}

#pragma mark - UIGestureRecognizerDelegate
//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
//   
//    if ([[otherGestureRecognizer view] isKindOfClass:[UICollectionView class]]){
//        return YES;
//    }
//    
//    return NO;
//}

#pragma mark - assistant method
-(UIImage *)snapImageOfView:(UIView *)aView scale:(CGFloat)aScale{
    if([[[UIDevice currentDevice] systemVersion] floatValue]>=7.0){
        UIGraphicsBeginImageContextWithOptions(aView.bounds.size, NO, aScale);
        [aView drawViewHierarchyInRect:aView.bounds afterScreenUpdates:YES];
        UIImage *copied = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return copied;
    }
    else
    {
        UIGraphicsBeginImageContextWithOptions(aView.bounds.size, NO, aScale);
        [aView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *copied = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return copied;
    }
}

@end


