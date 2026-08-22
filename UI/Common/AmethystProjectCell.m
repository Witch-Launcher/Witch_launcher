#import "AmethystProjectCell.h"
#import "ThemeManager.h"
#import "UIImageView+AFNetworking.h"

@implementation AmethystProjectCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
        self.layer.cornerRadius = 8;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.45].CGColor;
        self.clipsToBounds = YES;

        _projectIcon = [[UIImageView alloc] init];
        _projectIcon.translatesAutoresizingMaskIntoConstraints = NO;
        _projectIcon.contentMode = UIViewContentModeScaleAspectFill;
        _projectIcon.clipsToBounds = YES;
        _projectIcon.layer.cornerRadius = 6;
        _projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
        [self.contentView addSubview:_projectIcon];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
        _titleLabel.numberOfLines = 1;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _subtitleLabel.textColor = ThemeManager.shared.secondaryTextColor;
        _subtitleLabel.numberOfLines = 1;
        [self.contentView addSubview:_subtitleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_projectIcon.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
            [_projectIcon.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_projectIcon.widthAnchor constraintEqualToConstant:44],
            [_projectIcon.heightAnchor constraintEqualToConstant:44],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_projectIcon.trailingAnchor constant:10],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],

            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_projectIcon.trailingAnchor constant:10],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        ]];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme) name:ThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)updateTheme {
    self.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    self.layer.borderColor = [ThemeManager.shared.accentColor colorWithAlphaComponent:0.45].CGColor;
    _titleLabel.textColor = ThemeManager.shared.primaryTextColor;
    _subtitleLabel.textColor = ThemeManager.shared.secondaryTextColor;
    _projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle iconURL:(NSString *)iconURL placeholder:(NSString *)symbolName {
    _titleLabel.text = title;
    _subtitleLabel.text = subtitle;

    UIImage *placeholder = [UIImage systemImageNamed:symbolName];
    _projectIcon.image = placeholder;

    if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0) {
        NSURL *url = [NSURL URLWithString:iconURL];
        if (!url || !url.scheme) {
            _projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
            return;
        }
        NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15];
        __weak typeof(self) weakSelf = self;
        [_projectIcon setImageWithURLRequest:request
                           placeholderImage:placeholder
                                    success:^(NSURLRequest *req, NSHTTPURLResponse *response, UIImage *image) {
                                        if (image) {
                                            weakSelf.projectIcon.image = image;
                                            weakSelf.projectIcon.tintColor = [UIColor clearColor];
                                        }
                                    } failure:^(NSURLRequest *req, NSHTTPURLResponse *response, NSError *error) {
                                        weakSelf.projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
                                    }];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [_projectIcon cancelImageDownloadTask];
    _projectIcon.image = nil;
    _projectIcon.tintColor = ThemeManager.shared.secondaryTextColor;
    _titleLabel.text = nil;
    _subtitleLabel.text = nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
