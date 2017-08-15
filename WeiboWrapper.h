//
//  WeiboWrapper.h
//  Slate
//
//  Created by lin yize on 16-6-3.
//  Copyright (c) 2016年 islate. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 * 微博API封装，兼容oauth登录 和 iOS原生微博功能
 *
 */
@interface WeiboWrapper : NSObject

@property (nonatomic, strong) NSError *lastError;

// 单例
+ (instancetype)sharedWrapper;

// 初始化设置参数
- (void)setWeiboAppKey:(NSString *)key weiboAppSecret:(NSString *)secret weiboRedirectUrl:(NSString *)redirectUrl;

// 进行微博登录
- (void)weiboLogin:(void(^)(BOOL isLogin))loginBlock;

// 微博是否登录
- (void)weiboIsLogin:(void(^)(BOOL isLogin))isLoginBlock;

// 微博登出
- (void)weiboLogout;

/*
 *  微博关注
 *  @param followBlock
 *  @param screenName             要关注的微博昵称
 */
- (void)weiboFollow:(void(^)(BOOL success))followBlock screenName:(NSString *)screenName;

/*
 *  发送微博
 *  @param content      微博内容
 *  @param image        图片
 *  @param url          网址
 *  @param shareBlock
 *  @param editable     是否打开编辑框，不打开的话就直接发送了
 */
- (void)weiboShareWithContent:(NSString *)content image:(UIImage *)image url:(NSURL *)url shareBlock:(void(^)(BOOL success))shareBlock editable:(BOOL)editable;

/*
 *  获取微博账户信息
 *  @block param    weiboUid            微博uid
 *  @block param    weiboNickname       微博昵称
 *  @block param    weiboAvatarUrl      微博头像网址
 */
- (void)weiboProfile:(void (^)(BOOL success, NSString *weiboUid, NSString *weiboNickname, NSString *weiboAvatarUrl, NSString *userAddingInfo))profileBlock;

// sso相关方法
- (void)applicationDidBecomeActive;
- (BOOL)isWeiboSSOURL:(NSURL *)url;
- (BOOL)weiboSSOHandleOpenURL:(NSURL *)url;

@end
