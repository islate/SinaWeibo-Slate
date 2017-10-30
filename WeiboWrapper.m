//
//  WeiboWrapper.m
//  Slate
//
//  Created by lin yize on 16-6-3.
//  Copyright (c) 2016年 modernmedia. All rights reserved.
//

#import "WeiboWrapper.h"

#import "DETweetComposer.h"
#import "SinaWeibo.h"
#import <Social/Social.h>
#import <Accounts/Accounts.h>

#define kWeiboOauthData   @"OauthData"

#define rawWeiboLoginFlag @"raw"
#define weiboSDKLoginFlag @"sdk"

#define kLoginType @"type"

#define kWeiboUid @"weiboUid"
#define kWeiboToken @"weiboToken"
#define kWeiboExpireTime @"weiboExpireTime"


typedef enum : NSUInteger {
    WeiboWrapperHandleTypeLogin = 0,
    WeiboWrapperHandleTypeShare,
    WeiboWrapperHandleTypeFollow,
    WeiboWrapperHandleTypeProfile,
} WeiboWrapperHandleType;

typedef void (^WeiboWrapperFollowBlock)(BOOL success);
typedef void (^WeiboWrapperShareBlock)(BOOL success);
typedef void (^WeiboWrapperLoginBlock)(BOOL isLogin);
typedef void (^WeiboWrapperProfileBlock)(BOOL success, NSString *weiboUid, NSString *accessToken, NSString *weiboNickname, NSString *weiboAvatarUrl, NSString *userAddingInfo);

@interface WeiboWrapper () <SinaWeiboDelegate, SinaWeiboRequestDelegate, DETweetComposeViewControllerDelegate>

@property (nonatomic,strong) SinaWeibo *sinaWeibo;

@property (nonatomic, copy) WeiboWrapperProfileBlock profileBlock;
@property (nonatomic, copy) WeiboWrapperShareBlock shareBlock;
@property (nonatomic, copy) WeiboWrapperFollowBlock followBlock;
@property (nonatomic, copy) WeiboWrapperLoginBlock loginBlock;

@property (nonatomic, assign) WeiboWrapperHandleType currentType;
@property (nonatomic, strong) NSString *shareContent;
@property (nonatomic, strong) UIImage *shareImage;
@property (nonatomic, strong) NSURL *shareURL;
@property (nonatomic, assign) BOOL shareEditable;
@property (nonatomic, strong) NSString *followScreenName;
@property (nonatomic, weak) UIViewController *presentingViewController;

@end

@implementation WeiboWrapper
@synthesize sinaWeibo, shareBlock, followBlock, loginBlock, profileBlock, currentType;

// 单例
+ (instancetype)sharedWrapper
{
    static id sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}

// 初始化设置参数
- (void)setWeiboAppKey:(NSString *)key weiboAppSecret:(NSString *)secret weiboRedirectUrl:(NSString *)redirectUrl
{
    if (!sinaWeibo)
    {
        sinaWeibo = [[SinaWeibo alloc] initWithAppKey:key
                                            appSecret:secret
                                       appRedirectURI:redirectUrl
                                          andDelegate:self];
        
        [self readOauthData];
    }
}

//读取存储weibo 认证数据
- (void)readOauthData
{
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:kWeiboOauthData];
    
    if (dict)
    {
        if ([[dict objectForKey:kLoginType] isEqualToString:weiboSDKLoginFlag])
        {
            sinaWeibo.userID = [dict objectForKey:kWeiboUid];
            sinaWeibo.accessToken = [dict objectForKey:kWeiboToken];
            sinaWeibo.expirationDate = [dict objectForKey:kWeiboExpireTime];
        }
    }
}

//写微博验证数据
- (void)writeUserInfoWithIsRawLogin:(BOOL)isRaw userUid:(NSString *)uid userToken:(NSString *)token expireTime:(NSDate *)time
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    //是否使用ios原生weibo
    if (isRaw)
    {
        [dict setObject:rawWeiboLoginFlag forKey:kLoginType];
    }
    else
    {
        [dict setObject:weiboSDKLoginFlag forKey:kLoginType];
    }
    
    if (uid)
    {
        [dict setObject:uid forKey:kWeiboUid];
        if (!isRaw)
        {
            sinaWeibo.userID = uid;
        }
    }
    
    if (token)
    {
        [dict setObject:token forKey:kWeiboToken];
        if (!isRaw)
        {
            sinaWeibo.accessToken = token;
        }
    }
    
    if (time)
    {
        [dict setObject:time forKey:kWeiboExpireTime];
        if (!isRaw)
        {
            sinaWeibo.expirationDate = time;
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:kWeiboOauthData];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - 授权用户

- (void)weiboLogin:(void(^)(BOOL isLogin))block
{
    currentType = WeiboWrapperHandleTypeLogin;
    loginBlock = [block copy];
    
    if ([sinaWeibo isAuthValid])
    {
        if (block)
        {
            block(YES);
        }
    }
    else
    {
        // 原生api
        [self weiboRawAPIAccount:^(ACAccount *firstAccount, NSError *error) {
            if (firstAccount)
            {
                if (block)
                {
                    block(YES);
                }
            }
            else {
                [sinaWeibo logIn];
            }
        }];
    }
}

#pragma mark - 检测授权用户

- (void)weiboIsLogin:(void(^)(BOOL isLogin))isLoginBlock
{
    if (!isLoginBlock) {
        return;
    }
    
    if ([sinaWeibo isAuthValid])
    {
        // WeiboSDK
        isLoginBlock(YES);
    }
    else
    {
        // 原生api
        [self weiboRawAPIAccount:^(ACAccount *firstAccount, NSError *error) {
            if (firstAccount) {
                isLoginBlock(YES);
            }
            else {
                isLoginBlock(NO);
            }
        }];
    }
}

#pragma mark - 微博登出

- (void)weiboLogout
{
    [sinaWeibo logOut];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWeiboOauthData];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - 实现分享协议方法

- (void)weiboShareWithContent:(NSString *)content image:(UIImage *)image url:(NSURL *)url shareBlock:(void(^)(BOOL success))block editable:(BOOL)editable
{
    currentType = WeiboWrapperHandleTypeShare;
    shareBlock = [block copy];
    _shareURL = url;
    _shareImage = image;
    _shareContent = content;
    _shareEditable = editable;
    _presentingViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    while (_presentingViewController.presentedViewController) {
        _presentingViewController = _presentingViewController.presentedViewController;
    }
    
    if ([sinaWeibo isAuthValid])
    {
        // WeiboSDK
        [self shareWeiboViaSDK];
    }
    else
    {
        // 原生api
        [self weiboRawAPIAccount:^(ACAccount *firstAccount, NSError *error) {
            if (firstAccount) {
                [self shareWeiboViaRawAPIWithAccount:firstAccount];
            }
            else {
                [sinaWeibo logIn];
            }
        }];
    }
}

#pragma mark - 微博分享私有方法

- (void)shareWeiboViaSDK
{
    if (!_shareEditable)
    {
        // 直接发送微博
        NSString *content = _shareContent;
        if (_shareURL) {
            content = [NSString stringWithFormat:@"%@ %@", _shareContent, _shareURL.absoluteString];
        }
        if (_shareImage && (NSNull *)_shareImage != [NSNull null])
        {
            [self sendWeiboText:content image:_shareImage composeViewController:nil];
        }
        else
        {
            [self sendWeiboText:content composeViewController:nil];
        }
        
        return;
    }
    
    // 弹出微博编辑框
    UIModalPresentationStyle oldStyle = _presentingViewController.modalPresentationStyle;
    DETweetComposeViewController *tcvc = [[DETweetComposeViewController alloc] init] ;
    tcvc.delegate = self;
    tcvc.modalPresentationStyle = UIModalPresentationFormSheet;
    if ([[UIDevice currentDevice].systemVersion intValue] >= 8.0)
    {
        tcvc.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    }
    else
    {
        _presentingViewController.modalPresentationStyle = UIModalPresentationCurrentContext;
    }
    
    if (_shareImage && (NSNull *)_shareImage != [NSNull null])
    {
        [tcvc addImage:_shareImage];
    }
    [tcvc setInitialText:_shareContent];
    if (_shareURL)
    {
        // url附加在微博文字后面
        [tcvc addURL:_shareURL];
    }
    
    @try {
        [_presentingViewController presentViewController:tcvc animated:YES completion:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"%@", exception);
        return;
    }
    _presentingViewController.modalPresentationStyle = oldStyle;
    
    for (UIView *v in tcvc.view.superview.subviews) {
        if ([v isKindOfClass:[UIImageView class]]) {
            UIImageView* formSheetImageView = (UIImageView*)v;
            formSheetImageView.hidden = YES;
        }
    }
    tcvc.view.superview.layer.shadowOpacity = 0.0;
    tcvc.view.superview.backgroundColor = [UIColor clearColor];
}

- (void)sendWeiboViaSLRequest:(ACAccount *)account
{
    NSURL *url = [NSURL URLWithString:@"https://api.weibo.com/2/statuses/update.json"];
    NSDictionary *para = nil;
    
    if (_shareImage && (NSNull *)_shareImage != [NSNull null])
    {
        NSData *imageData = UIImageJPEGRepresentation(_shareImage, 1);
        
        //配置参数字典
        para = [NSDictionary dictionaryWithObjectsAndKeys:_shareContent, @"status",
                imageData, @"pic", nil];
    }
    else
    {
        //配置参数字典
        para = [NSDictionary dictionaryWithObjectsAndKeys:_shareContent, @"status", nil];
    }
    
    //配置请求
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeSinaWeibo requestMethod:SLRequestMethodPOST URL:url parameters:para];
    //装载微博用户
    request.account = account;
    //发送微博
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
        
        //主线程中操作UI
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error)
            {
                if (shareBlock)
                {
                    shareBlock(NO);
                    shareBlock = nil;
                }
            }
            else
            {
                if (shareBlock)
                {
                    shareBlock(YES);
                    shareBlock = nil;
                }
            }
        });
    }];
}

- (void)shareWeiboViaRawAPIWithAccount:(ACAccount *)account
{
    if (!_shareEditable)
    {
        // 直接发送微博
        [self sendWeiboViaSLRequest:account];
        return;
    }
    
    // BUG FIX #3108
    BOOL ret = NO;
    @try {
        ret = [SLComposeViewController isAvailableForServiceType:SLServiceTypeSinaWeibo];
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    } @finally {
        if (ret)
        {
            SLComposeViewController *composer = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
            SLComposeViewControllerCompletionHandler handler = ^(SLComposeViewControllerResult result) {
                [self clearCurrentWeiboShareData];
                if (result == SLComposeViewControllerResultCancelled)
                {
                    if (shareBlock)
                    {
                        shareBlock = nil;
                    }
                }
                else
                {
                    if (shareBlock)
                    {
                        shareBlock(YES);
                        shareBlock = nil;
                    }
                }
                [composer dismissViewControllerAnimated:YES completion:Nil];
            };
            composer.completionHandler = handler;
            [composer setInitialText:_shareContent];
            if (_shareURL)
            {
                [composer addURL:_shareURL];
            }
            if (_shareImage && (NSNull *)_shareImage != [NSNull null])
            {
                [composer addImage:_shareImage];
            }
            
            @try {
                [_presentingViewController presentViewController:composer animated:NO completion:nil];
            }
            @catch (NSException *exception) {
                NSLog(@"%@", exception);
            }
        }
        else
        {
            [sinaWeibo logIn];
        }
    }
}

- (void)clearCurrentWeiboShareData
{
    _shareContent = nil;
    _shareImage = nil;
    _shareURL = nil;
    _presentingViewController = nil;
}

#pragma mark - DETweetComposeViewControllerDelegate mothod

- (void)sendWeiboCancelledWithComposeViewController:(DETweetComposeViewController *)composeController
{
    [self clearCurrentWeiboShareData];
    [composeController dismissViewControllerAnimated:YES completion:nil];
    
    if (shareBlock)
    {
        shareBlock(NO);
        shareBlock = nil;
    }
}

- (void)sendWeiboText:(NSString *)weiboText composeViewController:(DETweetComposeViewController *)composeController
{
    [self sendWeiboText:weiboText image:nil composeViewController:composeController];
}

- (void)sendWeiboText:(NSString *)weiboText image:(UIImage *)image composeViewController:(DETweetComposeViewController *)composeController
{
    NSMutableDictionary *params = nil;
    
    if (image == nil)
    {
        params = [NSMutableDictionary dictionaryWithObjectsAndKeys:weiboText,@"status",
                  sinaWeibo.accessToken,@"access_token", nil];
    }
    else
    {
        NSData *imageData = UIImageJPEGRepresentation(image, 1);
        
        params = [NSMutableDictionary dictionaryWithObjectsAndKeys:weiboText,@"status",
                                       sinaWeibo.accessToken,@"access_token",imageData,@"pic", nil];
    }
    
    [sinaWeibo requestWithURL:@"statuses/share.json"
                       params:params
                   httpMethod:@"POST" delegate:self];
    
    [self clearCurrentWeiboShareData];
    [composeController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 获取微博信息

- (void)weiboProfile:(void (^)(BOOL success, NSString *weiboUid, NSString *accessToken, NSString *weiboNickname, NSString *weiboAvatarUrl, NSString *userAddingInfo))block
{
    if (!block) {
        return;
    }
    
    currentType = WeiboWrapperHandleTypeProfile;
    profileBlock = [block copy];
    
    if ([sinaWeibo isAuthValid])
    {
        // weiboSDK 获取信息
        [self weiboProfileViaSDK];
    }
    else
    {
        // 原生api
        [self weiboRawAPIAccount:^(ACAccount *firstAccount, NSError *error) {
            if (firstAccount) {
                [self requestWeiboProfileWithAccount:firstAccount];
            }
            else {
                [sinaWeibo logIn];
            }
        }];
    }
}

#pragma mark - 用户微博信息私有方法

- (void)weiboRawAPIAccount:(void (^)(ACAccount *firstAccount, NSError *error))block
{
    if (!block) {
        return;
    }
    
    ACAccountStore *store = [[ACAccountStore alloc] init];
    ACAccountType *type = [store accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierSinaWeibo];
    [store requestAccessToAccountsWithType:type options:nil completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted)//验证授权成功
            {
                //获取新浪微博用户列表
                NSArray *counts = [store accountsWithAccountType:type];
                if (counts && [counts count] > 0)
                {
                    block(counts[0], nil);
                }
                else
                {
                    block(nil, error);
                }
            }
            else
            {
                block(nil, error);
            }
        });
     }];
}

- (void)weiboProfileViaSDK
{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:sinaWeibo.accessToken,@"access_token",
                                   sinaWeibo.userID,@"uid", nil];
    
    [sinaWeibo requestWithURL:@"users/show.json" params:params httpMethod:@"GET" delegate:self];
}

- (void)requestWeiboProfileWithAccount:(ACAccount *)account
{
    NSURL *url = [NSURL URLWithString:@"https://api.weibo.com/2/users/show.json"];
    
    //配置参数字典
    NSDictionary *para = [NSDictionary dictionaryWithObjectsAndKeys:account.accountDescription, @"screen_name", nil];
    //配置轻取
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeSinaWeibo requestMethod:SLRequestMethodGET URL:url parameters:para];
    //装载微博用户
    request.account = account;
    //发送微博
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
        
        //主线程中操作UI
        dispatch_async(dispatch_get_main_queue(), ^{

            if (!error)
            {
                id result = nil;
                NSString *userAddingInfo = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                @try {
                    result = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:nil];
                }
                @catch (NSException *exception) {
                    NSLog(@"%@", exception);
                }
                
                NSString *weiboUid = [result objectForKey:@"idstr"];
                NSString *weiboNickname = [result objectForKey:@"screen_name"];
                NSString *weiboAvatar = [result objectForKey:@"profile_image_url"];
                
                if (weiboUid)
                {
                    // 请求登录接口
                    [self writeUserInfoWithIsRawLogin:YES
                                              userUid:weiboUid
                                            userToken:nil expireTime:nil];
                    
                    if (profileBlock)
                    {
                        profileBlock(YES, weiboUid, account.credential.oauthToken, weiboNickname, weiboAvatar,userAddingInfo);
                        profileBlock = nil;
                    }
                }
                else
                {
                    self.lastError = [NSError errorWithDomain:@"Weibo error" code:200 userInfo:@{NSLocalizedDescriptionKey:@"uid empty"}];
                    [self failed];
                }
            }
            else
            {
                self.lastError = error;
                [self failed];
            }
        });
    }];
}

#pragma mark - 实现关注协议方法

- (void)weiboFollow:(void(^)(BOOL success))block screenName:(NSString *)screenName
{
    followBlock = [block copy];
    _followScreenName = screenName;
    currentType = WeiboWrapperHandleTypeFollow;
    
    if ([sinaWeibo isAuthValid])
    {
        // weiboSDK关注
        [self followWeiboAccountViaSDKWithScreenName:screenName];
    }
    else
    {
        // 原生api
        [self weiboRawAPIAccount:^(ACAccount *firstAccount, NSError *error) {
            if (firstAccount)
            {
                [self followWeiboAccountViaRawAPIWithScreenName:screenName account:firstAccount];
            }
            else
            {
                [sinaWeibo logIn];
            }
        }];
    }
}

#pragma mark - 微博关注私有方法

- (void)followWeiboAccountViaSDKWithScreenName:(NSString *)name
{
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:name, @"screen_name", sinaWeibo.accessToken, @"access_token", nil];
    
    [sinaWeibo requestWithURL:@"friendships/create.json"
                       params:params
                   httpMethod:@"POST" delegate:self];
}

- (void)followWeiboAccountViaRawAPIWithScreenName:(NSString *)name account:(ACAccount *)account
{
    NSURL *url = [NSURL URLWithString:@"https://api.weibo.com/2/friendships/create.json"];
    
    //配置参数字典
    NSDictionary *para = [NSDictionary dictionaryWithObjectsAndKeys:name, @"screen_name", nil];
    //配置轻取
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeSinaWeibo requestMethod:SLRequestMethodPOST URL:url parameters:para];
    //装载微博用户
    request.account = account;
    //发送微博
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
        
        //主线程中操作UI
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error)
            {
                if (followBlock)
                {
                    followBlock(YES);
                    followBlock = nil;
                }
            }
            else
            {
                self.lastError = error;
                [self failed];
            }
        });
    }];
}

#pragma mark - SinaWeiboDelegate

//登录成功
- (void)sinaweiboDidLogIn:(SinaWeibo *)sinaweibo
{
    [self writeUserInfoWithIsRawLogin:NO
                              userUid:sinaweibo.userID
                            userToken:sinaweibo.accessToken
                           expireTime:sinaweibo.expirationDate];
    
    if (currentType == WeiboWrapperHandleTypeShare)
    {
        [self shareWeiboViaSDK];
    }
    else if (currentType == WeiboWrapperHandleTypeProfile)
    {
        [self weiboProfileViaSDK];
    }
    else if (currentType == WeiboWrapperHandleTypeLogin)
    {
        if (loginBlock)
        {
            loginBlock(YES);
            loginBlock = nil;
        }
    }
    else if (currentType == WeiboWrapperHandleTypeFollow)
    {
        [self followWeiboAccountViaSDKWithScreenName:_followScreenName];
    }
}

//登出成功
- (void)sinaweiboDidLogOut:(SinaWeibo *)sinaweibo
{
    NSLog(@"微博登出成功");
}

//登录取消
- (void)sinaweiboLogInDidCancel:(SinaWeibo *)sinaweibo
{
    self.lastError = [NSError errorWithDomain:@"Weibo error" code:100 userInfo:@{NSLocalizedDescriptionKey:@"user cancel"}];
    [self failed];
}

//登录失败
- (void)sinaweibo:(SinaWeibo *)sinaweibo logInDidFailWithError:(NSError *)error
{
    self.lastError = error;
    [self failed];
}

//token不正确或者过期
- (void)sinaweibo:(SinaWeibo *)sinaweibo accessTokenInvalidOrExpired:(NSError *)error
{
    self.lastError = error;
    [self failed];
}

#pragma mark - SinaWeiboRequestDelegate

- (void)request:(SinaWeiboRequest *)request didFailWithError:(NSError *)error
{
    self.lastError = error;
    [self failed];
}

- (void)request:(SinaWeiboRequest *)request didFinishLoadingWithResult:(id)result
{
    //先判断是什么请求（用户资料or发送微博）
    if ([request.url hasSuffix:@"users/show.json"])
    {
        //登录请求用户资料（发微博不请求用户资料） 成功
        
        NSString *weiboUid = [result objectForKey:@"idstr"];
        NSString *weiboNickname = [result objectForKey:@"screen_name"];
        NSString *weiboAvatar = [result objectForKey:@"avatar_large"];
        
        NSString *useraddingInfo = [NSString stringWithFormat:@"%@",result];
        
        if (profileBlock)
        {
            profileBlock(YES, weiboUid, sinaWeibo.accessToken, weiboNickname, weiboAvatar, useraddingInfo);
            profileBlock = nil;
        }
        
    }
    else if ([request.url hasSuffix:@"friendships/create.json"])
    {
        if (followBlock)
        {
            followBlock(YES);
            followBlock = nil;
        }
    }
    else
    {
        if (shareBlock)
        {
            shareBlock(YES);
            shareBlock = nil;
        }
    }
}

#pragma mark - 失败处理

- (void)failed
{
    if (currentType == WeiboWrapperHandleTypeProfile)
    {
        if (profileBlock)
        {
            profileBlock(NO,nil,nil,nil,nil,nil);
            loginBlock = nil;
        }
    }
    else if (currentType == WeiboWrapperHandleTypeShare)
    {
        if (shareBlock)
        {
            shareBlock(NO);
            shareBlock = nil;
        }
    }
    else if (currentType == WeiboWrapperHandleTypeLogin)
    {
        if (loginBlock)
        {
            loginBlock(NO);
            loginBlock = nil;
        }
    }
    else if (currentType == WeiboWrapperHandleTypeFollow)
    {
        if (followBlock)
        {
            followBlock(NO);
            followBlock = nil;
        }
    }
}

#pragma mark - SSO

- (void)applicationDidBecomeActive
{
    [sinaWeibo applicationDidBecomeActive];
}

- (BOOL)isWeiboSSOURL:(NSURL *)url
{
    return ([url.scheme hasPrefix:sinaWeibo.ssoCallbackScheme]);
}

- (BOOL)weiboSSOHandleOpenURL:(NSURL *)url
{
    return [sinaWeibo handleOpenURL:url];
}

@end
