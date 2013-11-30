//
//  ResultCollectionViewCell.h
//  Heartbeat
//
//  Created by michael leybovich on 10/12/13.
//  Copyright (c) 2013 michael leybovich. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ResultView.h"

@interface ResultCollectionViewCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet ResultView *resultView;
@property (weak, nonatomic) IBOutlet UILabel *resultLabel;

@property (weak, nonatomic) IBOutlet UIButton *facebookButton;

@end
