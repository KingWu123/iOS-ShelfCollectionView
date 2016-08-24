//
//  BookCollectionViewCell.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/12/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "BookCollectionViewCell.h"

@interface BookCollectionViewCell ()
@property (weak, nonatomic) IBOutlet UILabel *numberIndexLabel;

@end

@implementation BookCollectionViewCell


+ (instancetype)loadFromNib{
    return [[[NSBundle mainBundle]loadNibNamed:@"BookCollectionViewCell" owner:nil options:nil]objectAtIndex:0];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)initCellWithItemData:(ItemData *)itemData{
    self.numberIndexLabel.text = itemData.title;
}

- (void)prepareForReuse{
    [self.numberIndexLabel setText:@""];
}

@end
