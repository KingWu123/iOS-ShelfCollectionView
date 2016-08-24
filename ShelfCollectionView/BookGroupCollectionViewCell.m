//
//  BookGroupCollectionViewCell.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/23/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "BookGroupCollectionViewCell.h"
#import "BookCollectionViewCell.h"

@interface BookGroupCollectionViewCell ()
@property (weak, nonatomic) IBOutlet UIView *groupView;

@property (strong, nonatomic)NSArray *itemsArr;

@end

@implementation BookGroupCollectionViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    
}

- (void)initCellWithDatas:(NSArray *)itemsArrData{
    self.itemsArr = itemsArrData;

    for (UIView *subView in [_groupView subviews]){
        [subView removeFromSuperview];
    }
    
    long cout = MIN([itemsArrData count], 4);
    for (int i=0; i< cout; i++){
        BookCollectionViewCell *oneCell = [BookCollectionViewCell loadFromNib];
        [oneCell initCellWithItemData:[itemsArrData objectAtIndex:i]];
        [oneCell setUserInteractionEnabled:NO];
        
        CGFloat posX = i%2 * self.frame.size.width/2 + 5;
        CGFloat posY = i/2 * self.frame.size.height/2 + 5;
        CGFloat width = self.frame.size.width/2 - 20;
        CGFloat height = self.frame.size.height/2 - 20;
        oneCell.frame = CGRectMake(posX, posY, width, height);
        
        [self.groupView addSubview:oneCell];
    }
}




@end
