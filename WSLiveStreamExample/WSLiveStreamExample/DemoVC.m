//
//  DemoVC.m
//  WSLiveStream
//
//  Created by jack on 2021/3/22.
//

#import "DemoVC.h"
#import "CaptureClientVC.h"

@interface DemoVC ()
- (IBAction)captureClientBtnClick:(id)sender;

@end

@implementation DemoVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)captureClientBtnClick:(id)sender {
    CaptureClientVC *vc = [[CaptureClientVC alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}
@end
