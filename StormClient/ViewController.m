//
//  ViewController.m
//  StormClient
//
//  Created by Bartłomiej Uchański on 24.01.2018.
//  Copyright © 2018 Bartłomiej Uchański. All rights reserved.
//
#define barColor [UIColor colorWithRed:27./255. green:110./255. blue:189.0/255. alpha:1.0]
#define maxLimit 60

#import "ViewController.h"

@import UserNotifications;
@import SocketIO;
@import Charts;


@interface ViewController () <ChartViewDelegate, UIWebViewDelegate>
@property IBOutlet LineChartView *chartView;
@property BOOL shouldHideData;
@property (weak, nonatomic) IBOutlet UIView *webContainerView;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIView *limitView;
@property (weak, nonatomic) IBOutlet UISlider *limitSlider;
@property (weak, nonatomic) IBOutlet UILabel *limitLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *limitConstraint;
@property NSMutableArray *sensorData;
@property NSTimer *timer;
@property UIView *loadingView;
@property UILabel *emptyLabel;
@property BOOL loadingData;
@property BOOL limitShown;
@property NSNumber *offset;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.offset = @0;
    self.limitSlider.value = 0.5;
    self.limitLabel.text = [NSString stringWithFormat:@"Limit: %.02f%@C", self.limitSlider.value*maxLimit,@"\u00B0"];
    [NSThread sleepForTimeInterval:0.5];
    [self startLoading];
    self.webContainerView.hidden = YES;
    self.sensorData = [NSMutableArray new];
    [self startTimer];
    
}

-(void)showHideLimit{
    
    self.limitConstraint.constant = self.limitShown ? -self.limitView.frame.size.height : 0;
    [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.limitView.alpha = self.limitShown ? 0.0 : 1.0;
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        self.limitShown = !self.limitShown;
    }];
}

-(void)startLoading{
    if(!self.loadingView){
        self.loadingView = [[UIView alloc] initWithFrame:self.view.frame];
        self.loadingView.backgroundColor = barColor;
        UILabel * stormLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 60.0)];
        stormLabel.textAlignment = NSTextAlignmentCenter;
        stormLabel.attributedText = [[NSAttributedString alloc] initWithString:@"StormClient" attributes:@{NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:40.0], NSForegroundColorAttributeName : [UIColor whiteColor]}];
        
        
        UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        UILabel * emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 60.0)];
        emptyLabel.attributedText = [[NSAttributedString alloc] initWithString:@"No measurements found..." attributes:@{NSFontAttributeName : [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:20.0], NSForegroundColorAttributeName : [UIColor whiteColor]}];
        emptyLabel.alpha = 0.0;
        emptyLabel.textAlignment = NSTextAlignmentCenter;
        [self.loadingView addSubview:emptyLabel];
        [self.loadingView addSubview:indicator];
        [self.loadingView addSubview:stormLabel];
        
        CGPoint center = self.loadingView.center;
        center = CGPointMake(center.x, center.y-100);
        stormLabel.center = center;
        center = CGPointMake(center.x, center.y+100);
        indicator.center = center;
        [indicator startAnimating];
        emptyLabel.center = CGPointMake(center.x, center.y+100);
        self.emptyLabel = emptyLabel;
        
        [[UIApplication sharedApplication].keyWindow addSubview:self.loadingView];
        
    }
   
    self.loadingView.alpha = 1.0;

}
-(void)stopLoading{
    [UIView animateWithDuration:0.5 animations:^{
        self.loadingView.alpha = 0.0;
    }];
}

-(void)showEmpty{
    [UIView animateWithDuration:0.5 animations:^{
        self.emptyLabel.alpha = 1.0;
    }];
}

-(void)hideEmpty{
    [UIView animateWithDuration:0.5 animations:^{
        self.emptyLabel.alpha = 0.0;
    }];
}

-(void)startTimer{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:10.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if(!self.loadingData)
            [self getSensorData];
    }];
}

-(void)updateChartWithMeasurements:(NSDictionary*)measurementsDict{
    NSArray* measurements = measurementsDict[@"measurements"];
    measurements = [[measurements reverseObjectEnumerator] allObjects];
    
    if(measurements.count > 0)
        self.offset = ((NSNumber*)measurements.lastObject[@"created_epoch"]);
   
    if(self.chartView.data.dataSetCount == 0){
        if(measurements.count == 0)
            [self showEmpty];
        else{
            [self hideEmpty];
            self.chartView.rightAxis.enabled = NO;
        
            _chartView.chartDescription.enabled = NO;
        
            NSMutableArray * dataEntries = [NSMutableArray new];
            int i = 0;
            for(NSDictionary*measurement in measurements){
                ChartDataEntry * entry = [[ChartDataEntry alloc] initWithX:(double)i++ y:((NSNumber*)measurement[@"value"]).doubleValue];
                [dataEntries addObject:entry];
            }
            LineChartDataSet * dataSet = [[LineChartDataSet alloc] initWithValues:dataEntries label:@"Temperature"];
        
            dataSet.axisDependency = AxisDependencyLeft;
            [dataSet setColor:barColor];
        
            [dataSet setCircleColor: barColor];
            dataSet.lineWidth = 2.0;
            dataSet.circleRadius = 3.0;
            dataSet.fillAlpha = 65.0/255.0;
            dataSet.fillColor = [UIColor colorWithRed:51/255.f green:181/255.f blue:229/255.f alpha:1.f];
            dataSet.highlightColor = [UIColor colorWithRed:244/255.f green:117/255.f blue:117/255.f alpha:1.f];
            dataSet.drawCircleHoleEnabled = NO;
            //dataSet.valueFormatter = [DateValueFormatter new];
            LineChartData * data = [[LineChartData alloc] initWithDataSet:dataSet];
        
            [data setValueTextColor:UIColor.blackColor];
            [data setValueFont:[UIFont systemFontOfSize:9.f]];
            ChartLimitLine * limitLine = [[ChartLimitLine alloc] initWithLimit:0.5*maxLimit];
        
            [self.chartView.leftAxis addLimitLine:limitLine];
            self.chartView.drawMarkers = YES;
            self.chartView.data = data;
            self.chartView.delegate = self;
        }
    }
    else{
       
        LineChartDataSet*dataSet = (LineChartDataSet*)self.chartView.data.dataSets[0];
        NSInteger i = dataSet.entryCount;
        BOOL alertNeeded = NO;
        for(NSDictionary*measurement in measurements){
            ChartDataEntry * entry = [[ChartDataEntry alloc] initWithX:(double)i++ y:((NSNumber*)measurement[@"value"]).doubleValue];
            [dataSet addEntry:entry];
            if(entry.y > ((ChartLimitLine*)self.chartView.leftAxis.limitLines[0]).limit)
                alertNeeded = YES;
        }
        if(alertNeeded)
            [self sendAlert];
    }
    
    if(self.chartView.data.dataSetCount != 0){
        [_chartView.data notifyDataChanged];
        [_chartView notifyDataSetChanged];
        if(self.loadingView.alpha != 0.0)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self stopLoading];
                [_chartView animateWithXAxisDuration:1.0];
                
            });
    }
    
}

-(void)sendAlert{
    UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
    content.title = @"Alert!";
    content.body = @"Man's hot !!!";
    content.sound = [UNNotificationSound defaultSound];
    
    UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                                                  triggerWithTimeInterval:1 repeats:NO];
    UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:@"FiveSecond"
                                                                          content:content trigger:trigger];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        
    }];
}
-(void)getSensorData{
    self.loadingData = YES;
    NSString *userId = @"baaarteeek@gmail.com";
    NSString *sensorId = @"5a68b65f846646151caf16b7";
    NSString * targetUrl = [NSString stringWithFormat:@"http://alfa.smartstorm.io/api/v1/measure?user_id=%@&sensor_id=%@&offset=%@",userId, sensorId, self.offset];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:targetUrl]];
    
    NSURLSession * session = [NSURLSession sharedSession];
    
    [[session dataTaskWithRequest:request completionHandler:
      ^(NSData * _Nullable data,
        NSURLResponse * _Nullable response,
        NSError * _Nullable error) {
          
          self.loadingData = NO;
          if(data && !error){
              NSError* jsonError;
              NSDictionary* measurementsDict = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:kNilOptions
                                                                     error:&jsonError];
              dispatch_async(dispatch_get_main_queue(), ^{
              [self updateChartWithMeasurements:measurementsDict];
              });
              
          }
          else
              NSLog(@"error:%@",error.localizedDescription);
          
      }] resume];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - ChartViewDelegate

- (void)chartValueSelected:(ChartViewBase * __nonnull)chartView entry:(ChartDataEntry * __nonnull)entry highlight:(ChartHighlight * __nonnull)highlight
{
    [_chartView centerViewToAnimatedWithXValue:entry.x yValue:entry.y axis:[_chartView.data getDataSetByIndex:highlight.dataSetIndex].axisDependency duration:1.0];
}

- (void)chartValueNothingSelected:(ChartViewBase * __nonnull)chartView
{
    NSLog(@"chartValueNothingSelected");
}



-(void)chart:(UIImage*)chart didSaveWithError:(NSError*)error ContextInfo:(id)info{
    UIAlertController * controller = [UIAlertController alertControllerWithTitle:@"Chart saved!" message:@"The chart has been saved to your camera roll." preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [controller addAction:okAction];
    [self.navigationController presentViewController:controller animated:YES completion:nil];
}

-(void)presentImageError{
    UIAlertController * controller = [UIAlertController alertControllerWithTitle:@"Chart couldn't be saved!" message:@"Something went wrong. Please try again." preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [controller addAction:okAction];
    [self.navigationController presentViewController:controller animated:YES completion:nil];
}

- (IBAction)sliderMoved:(id)sender {
    ((ChartLimitLine*)self.chartView.leftAxis.limitLines[0]).limit = self.limitSlider.value*maxLimit;
    self.limitLabel.text = [NSString stringWithFormat:@"Limit: %.02f*C", self.limitSlider.value*maxLimit];
    [_chartView.data notifyDataChanged];
    [_chartView notifyDataSetChanged];
}
-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

- (IBAction)saveClicked:(id)sender {
    UIImage* image = [self.chartView getChartImageWithTransparent:YES];
    if(image)
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(chart:didSaveWithError:ContextInfo:),nil);
    else
        [self presentImageError];
}
- (IBAction)actionsClicked:(id)sender {
    [self showHideLimit];
}
@end
