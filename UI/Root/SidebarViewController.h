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
// YES when the bar docks at the bottom (items laid out horizontally).
@property (nonatomic) BOOL horizontal;

- (void)setSelectedTab:(SidebarTab)tab animated:(BOOL)animated;
- (void)updateTabAvailabilityForLoader:(NSString *)loader;

@end
