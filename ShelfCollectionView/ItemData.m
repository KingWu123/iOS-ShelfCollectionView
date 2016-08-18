//
//  ItemData.m
//  ShelfCollectionView
//
//  Created by king.wu on 8/18/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import "ItemData.h"


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

