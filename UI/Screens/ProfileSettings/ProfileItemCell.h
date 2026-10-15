#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Shared row for mod / shader / resource / datapack lists.
// Icon loads are guarded by requestToken: async completions must check
// [cell.requestToken isEqualToString:requestedFilename] before assigning.
@interface ProfileItemCell : UITableViewCell

@property (nonatomic, copy, nullable) NSString *requestToken;
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *detailLabel;
@property (nonatomic) UILabel *sourceBadge;
@property (nonatomic) UILabel *statusBadge;
@property (nonatomic) UISwitch *enabledSwitch;
@property (nonatomic) UIButton *actionButton;
@property (nonatomic, nullable) NSDictionary *itemData;
@property (nonatomic, copy, nullable) void(^onToggle)(NSDictionary *item, BOOL enabled);
@property (nonatomic, copy, nullable) void(^onAction)(NSDictionary *item);

- (void)configureWithItem:(NSDictionary *)item status:(NSDictionary *)status category:(NSString *)category;
- (void)setActionTitle:(NSString *)title color:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
