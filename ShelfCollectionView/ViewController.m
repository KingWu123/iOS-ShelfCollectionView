//
//  ViewController.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/12/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "ViewController.h"

#import "ItemData.h"
#import "BookShelfMainView.h"


@interface ViewController ()

@property (nonatomic, strong)NSMutableArray *modelSource;
@property (weak, nonatomic)BookShelfMainView *bookShelfMainView;
@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
   

    //UICollectionViewLayoutAttributes

    //init modelSource
    float width = [[UIScreen mainScreen]bounds].size.width /3;
    
    NSMutableArray *groupItems = [[NSMutableArray alloc]init];
    self.modelSource = [[NSMutableArray alloc]init];
    for (int i=0; i<100; i++){
        
        float height = width + 50;
//        if (i%3 == 0){
//            height += 15;
//        }else if (i%3 == 1){
//            height += 30;
//        }
        
        CGSize itemSize = CGSizeMake(width, height);
        ItemData *itemData = [[ItemData alloc]initWithTitle:[NSString stringWithFormat:@"L %d", i] itemSize:itemSize];
        
        
        if (i >= 10 && i<=13){
            [groupItems addObject:itemData];
            
            if (i==13){
                NSArray *tempDataArr = [NSArray arrayWithArray:[groupItems copy]];
                [self.modelSource addObject:tempDataArr];
                [groupItems removeAllObjects];
            }
        }else if (i >= 20 && i <=25){
            [groupItems addObject:itemData];
            
            if (i==25){
                NSArray *tempDataArr = [NSArray arrayWithArray:[groupItems copy]];
                [self.modelSource addObject:tempDataArr];
                [groupItems removeAllObjects];
            }
        }else{
            [self.modelSource addObject:itemData];
        }
    }
    
    
    BookShelfMainView *bookShelfView = [BookShelfMainView loadFromNib];
    bookShelfView.frame = self.view.frame;
    [self.view addSubview:bookShelfView];
    self.bookShelfMainView = bookShelfView;
    
    [bookShelfView initWithData:self.modelSource];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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


