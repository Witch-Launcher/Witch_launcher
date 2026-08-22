#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, SidebarTab) {
    SidebarTabGame = 0,
    SidebarTabMod,
    SidebarTabModpack,
    SidebarTabShader,
    SidebarTabResourcePack,
    SidebarTabMap
};

@protocol SidebarDelegate <NSObject>
- (void)sidebarDidSelectTab:(SidebarTab)tab;
@end

@interface SidebarViewController : UIViewController

@property (nonatomic, weak) id<SidebarDelegate> delegate;
@property (nonatomic) SidebarTab selectedTab;

- (void)setSelectedTab:(SidebarTab)tab animated:(BOOL)animated;
- (void)updateTabAvailabilityForLoader:(NSString *)loader;

@end
