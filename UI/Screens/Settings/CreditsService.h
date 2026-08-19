#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const CreditsDidUpdateNotification;

@interface CreditsComponent : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *license;
@property (nonatomic, copy, nullable) NSString *url;
@property (nonatomic, copy, nullable) NSString *licenseUrl;
@end

@interface CreditsSocial : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *url;
@end

@interface CreditsService : NSObject

@property (nonatomic, copy, readonly) NSString *authorName;
@property (nonatomic, copy, readonly) NSArray<CreditsComponent *> *components;
@property (nonatomic, copy, readonly) NSArray<CreditsSocial *> *socials;
@property (nonatomic, readonly) BOOL hasData;

+ (instancetype)shared;
- (void)refreshIfNeeded;
- (void)loadCached;

@end

NS_ASSUME_NONNULL_END
