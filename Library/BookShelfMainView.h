//
//  BookShelfMainView.h
//  ShelfCollectionView
//
//  Created by king.wu on 8/24/16.
//  Copyright © 2016 king.wu. All rights reserved.
//

#import <UIKit/UIKit.h>


/**
 *  书架主界面
 */
@interface BookShelfMainView : UIView

+ (instancetype)loadFromNib;

- (void)initWithData:(NSArray *)itemDatas;
@end
