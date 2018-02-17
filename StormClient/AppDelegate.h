//
//  AppDelegate.h
//  StormClient
//
//  Created by Bartłomiej Uchański on 24.01.2018.
//  Copyright © 2018 Bartłomiej Uchański. All rights reserved.
//

#import <UIKit/UIKit.h>
@import UserNotifications;
@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>

@property (strong, nonatomic) UIWindow *window;


@end

