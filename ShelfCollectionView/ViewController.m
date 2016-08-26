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
    
   
    //init modelSource
    NSMutableArray *groupItems = [[NSMutableArray alloc]init];
    self.modelSource = [[NSMutableArray alloc]init];
    for (int i=0; i<100; i++){
        

        ItemData *itemData = [[ItemData alloc]initWithTitle:[NSString stringWithFormat:@"L %d", i]];
        
        
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
    
    //add BooksShelfMainView
    BookShelfMainView *bookShelfView = [BookShelfMainView loadFromNib];
    bookShelfView.frame = CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.height - 20);
    [self.view addSubview:bookShelfView];
    self.bookShelfMainView = bookShelfView;
    
    [bookShelfView initWithData:self.modelSource];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end


