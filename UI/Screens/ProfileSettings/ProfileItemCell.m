#import "ProfileItemCell.h"
#import "ThemeManager.h"
#import "InstalledModsManager.h"
#import "ModMetadataReader.h"

@implementation ProfileItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.contentView.layer.cornerRadius = 14;
        self.contentView.clipsToBounds = YES;

        _iconView = [[UIImageView alloc] init];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeScaleAspectFill;
        _iconView.clipsToBounds = YES;
        _iconView.layer.cornerRadius = 10;
        _iconView.backgroundColor = ThemeManager.shared.separatorColor;
        [self.contentView addSubview:_iconView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
        [self.contentView addSubview:_nameLabel];

        _detailLabel = [[UILabel alloc] init];
        _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _detailLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _detailLabel.textColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_detailLabel];

        _sourceBadge = [self makeBadge];
        _statusBadge = [self makeBadge];

        _enabledSwitch = [[UISwitch alloc] init];
        _enabledSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        _enabledSwitch.onTintColor = ThemeManager.shared.successColor;
        [_enabledSwitch addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_enabledSwitch];

        _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
        _actionButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _actionButton.layer.cornerRadius = 8;
        _actionButton.contentEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 10);
        [_actionButton addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_actionButton];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_iconView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_iconView.widthAnchor constraintEqualToConstant:44],
            [_iconView.heightAnchor constraintEqualToConstant:44],

            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-8],

            [_detailLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
            [_detailLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_actionButton.leadingAnchor constant:-8],

            [_sourceBadge.topAnchor constraintEqualToAnchor:_detailLabel.bottomAnchor constant:4],
            [_sourceBadge.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_sourceBadge.heightAnchor constraintEqualToConstant:16],
            [_sourceBadge.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-10],

            [_statusBadge.centerYAnchor constraintEqualToAnchor:_sourceBadge.centerYAnchor],
            [_statusBadge.leadingAnchor constraintEqualToAnchor:_sourceBadge.trailingAnchor constant:6],
            [_statusBadge.heightAnchor constraintEqualToConstant:16],

            [_actionButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_actionButton.trailingAnchor constraintEqualToAnchor:_enabledSwitch.leadingAnchor constant:-8],
            [_actionButton.heightAnchor constraintEqualToConstant:30],

            [_enabledSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_enabledSwitch.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (UILabel *)makeBadge {
    UILabel *b = [[UILabel alloc] init];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    b.textColor = UIColor.whiteColor;
    b.textAlignment = NSTextAlignmentCenter;
    b.layer.cornerRadius = 4;
    b.clipsToBounds = YES;
    [self.contentView addSubview:b];
    return b;
}

- (void)updateTheme {
    self.contentView.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _nameLabel.textColor = ThemeManager.shared.primaryTextColor;
    _detailLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _enabledSwitch.onTintColor = ThemeManager.shared.successColor;
}

- (void)switchChanged { if (_onToggle) _onToggle(_itemData, _enabledSwitch.isOn); }
- (void)actionTapped { if (_onAction) _onAction(_itemData); }

- (void)configureWithItem:(NSDictionary *)item status:(NSDictionary *)status category:(NSString *)category {
    _itemData = item;
    NSString *title = item[@"title"];
    if (![title isKindOfClass:[NSString class]] || title.length == 0) title = item[@"filename"] ?: @"Unknown";
    _nameLabel.text = title;

    NSMutableArray *parts = [NSMutableArray array];
    NSString *ver = item[@"version_number"];
    if ([ver isKindOfClass:[NSString class]] && ver.length > 0) [parts addObject:ver];
    NSString *author = item[@"author"];
    if ([author isKindOfClass:[NSString class]] && author.length > 0) [parts addObject:author];
    NSString *mc = item[@"mc_version"];
    if ([mc isKindOfClass:[NSString class]] && mc.length > 0) [parts addObject:[NSString stringWithFormat:@"MC %@", mc]];
    NSString *loader = item[@"loader"];
    if ([loader isKindOfClass:[NSString class]] && loader.length > 0) [parts addObject:loader];
    if (parts.count == 0 && [item[@"filename"] isKindOfClass:[NSString class]]) [parts addObject:item[@"filename"]];
    _detailLabel.text = [parts componentsJoinedByString:@"  •  "];

    NSString *source = [item[@"source"] isKindOfClass:[NSString class]] ? item[@"source"] : @"";
    if ([source isEqualToString:@"curseforge"]) {
        _sourceBadge.text = @"  CurseForge  ";
        _sourceBadge.backgroundColor = [UIColor colorWithRed:0.18 green:0.50 blue:0.73 alpha:1.0];
    } else if (source.length > 0 && ![source isEqualToString:@"local"]) {
        _sourceBadge.text = @"  Modrinth  ";
        _sourceBadge.backgroundColor = [UIColor colorWithRed:0.20 green:0.62 blue:0.35 alpha:1.0];
    } else {
        _sourceBadge.text = @"  Local  ";
        _sourceBadge.backgroundColor = [UIColor grayColor];
    }

    NSString *st = [status[@"status"] isKindOfClass:[NSString class]] ? status[@"status"] : @"none";
    ThemeManager *theme = ThemeManager.shared;
    if ([st isEqualToString:@"update"]) {
        _statusBadge.text = @"  Outdated  ";
        _statusBadge.backgroundColor = theme.warningColor;
        [self setActionTitle:@"Update" color:theme.warningColor];
        _actionButton.hidden = NO;
    } else if ([st isEqualToString:@"latest"]) {
        _statusBadge.text = @"  Up to date  ";
        _statusBadge.backgroundColor = theme.successColor;
        [self setActionTitle:@"Installed" color:theme.accentColor];
        _actionButton.hidden = NO;
    } else if ([st isEqualToString:@"incompatible"]) {
        _statusBadge.text = @"  Incompatible  ";
        _statusBadge.backgroundColor = theme.errorColor;
        _actionButton.hidden = YES;
    } else if ([st isEqualToString:@"checking"]) {
        _statusBadge.text = @"  Checking  ";
        _statusBadge.backgroundColor = [UIColor grayColor];
        _actionButton.hidden = YES;
    } else if ([st isEqualToString:@"unknown"]) {
        _statusBadge.text = @"  Unknown  ";
        _statusBadge.backgroundColor = [UIColor grayColor];
        _actionButton.hidden = YES;
    } else {
        _statusBadge.text = @"  Manual  ";
        _statusBadge.backgroundColor = [UIColor grayColor];
        _actionButton.hidden = YES;
    }

    NSString *filename = item[@"filename"];
    BOOL enabled = YES;
    if ([filename isKindOfClass:[NSString class]] && filename.length > 0) {
        NSDictionary *profile = item[@"_profile"];
        if ([profile isKindOfClass:[NSDictionary class]]) {
            enabled = [[InstalledModsManager shared] isEnabledForFilename:filename category:category profile:profile];
        } else {
            enabled = [[InstalledModsManager shared] isEnabledForFilename:filename category:category];
        }
    }
    [_enabledSwitch setOn:enabled animated:NO];
    _requestToken = [filename isKindOfClass:[NSString class]] ? filename : nil;
}

- (void)setActionTitle:(NSString *)title color:(UIColor *)color {
    [_actionButton setTitle:title forState:UIControlStateNormal];
    [_actionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _actionButton.backgroundColor = color;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _requestToken = nil;
    _iconView.image = nil;
    _nameLabel.text = nil;
    _detailLabel.text = nil;
    _itemData = nil;
    _onToggle = nil;
    _onAction = nil;
    _actionButton.hidden = NO;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end
