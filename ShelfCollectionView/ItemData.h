//
//  ItemData.h
//  ShelfCollectionView
//
//  Created by king.wu on 8/18/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ItemData : NSObject

@property (nonatomic, strong)NSString *title;

- (instancetype)initWithTitle:(NSString *)title;
@end