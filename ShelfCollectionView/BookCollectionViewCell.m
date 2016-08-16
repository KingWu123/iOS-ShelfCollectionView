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

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)initCellWithIndex:(NSString *)indexStr{
    self.numberIndexLabel.text = indexStr;
}

@end
