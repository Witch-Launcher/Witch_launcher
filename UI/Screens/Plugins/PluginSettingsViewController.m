#import "PluginSettingsViewController.h"
#import "WitchPluginManager.h"
#import "WitchPlugin.h"
#import "ThemeManager.h"
#import "AmethystBlurView.h"
#import "AppSheet.h"
#import "utils.h"
#import "ios_uikit_bridge.h"
#import <math.h>

@interface WitchPluginSliderCell : UITableViewCell
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *valueLabel;
@property (nonatomic) UISlider *slider;
@property (nonatomic, copy) void (^onChange)(float value);
@end

@implementation WitchPluginSliderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, 200, 22)];
        _titleLabel.font = [UIFont systemFontOfSize:16];
        [self.contentView addSubview:_titleLabel];
        CGFloat width = self.contentView.bounds.size.width > 0 ? self.contentView.bounds.size.width : UIScreen.mainScreen.bounds.size.width;
        _valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(width - 90, 8, 74, 22)];
        _valueLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _valueLabel.textAlignment = NSTextAlignmentRight;
        _valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];
        [self.contentView addSubview:_valueLabel];
        _slider = [[UISlider alloc] initWithFrame:CGRectMake(16, 36, self.contentView.bounds.size.width - 32, 30)];
        _slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_slider];
        __weak typeof(self) weakSelf = self;
        [_slider addAction:[UIAction actionWithHandler:^(UIAction *action) {
            UISlider *sender = (UISlider *)action.sender;
            weakSelf.valueLabel.text = [NSString stringWithFormat:@"%.2f", sender.value];
            if (weakSelf.onChange) weakSelf.onChange(sender.value);
        }] forControlEvents:UIControlEventValueChanged];
    }
    return self;
}

@end

@interface PluginSettingsViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSString *pluginID;
@property (nonatomic, strong) WitchPlugin *plugin;
@property (nonatomic) UITableView *tableView;
@property (nonatomic) BOOL suppressReload;
@end

@implementation PluginSettingsViewController

- (instancetype)initWithPluginID:(NSString *)pluginID {
    self = [super init];
    if (self) {
        _pluginID = [pluginID copy];
        self.title = localize(@"Plugin Settings", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadContent) name:WitchPluginsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];
    [self reloadContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadContent];
}

- (void)reloadContent {
    if (self.suppressReload) return;
    self.plugin = [WitchPluginManager.shared pluginWithID:self.pluginID];
    if (!self.plugin) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    [self.tableView reloadData];
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.plugin.settingsSchema.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.plugin.settingsSchema.count == 0 ? localize(@"This plugin does not expose settings.", nil) : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.plugin.settingsSchema[indexPath.row];
    return [item[@"type"] isEqualToString:@"slider"] ? 76 : 58;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.plugin.settingsSchema[indexPath.row];
    NSString *type = [item[@"type"] isKindOfClass:[NSString class]] ? item[@"type"] : @"text";
    NSString *key = [item[@"key"] isKindOfClass:[NSString class]] ? item[@"key"] : @"";
    NSString *label = [item[@"label"] isKindOfClass:[NSString class]] ? item[@"label"] : ([item[@"title"] isKindOfClass:[NSString class]] ? item[@"title"] : key);
    id current = self.plugin.settings[key] ?: item[@"default"];

    if ([type isEqualToString:@"slider"]) {
        WitchPluginSliderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SliderCell"];
        if (!cell) cell = [[WitchPluginSliderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SliderCell"];
        cell.titleLabel.text = label;
        cell.titleLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.valueLabel.textColor = ThemeManager.shared.secondaryTextColor;
        double min = [item[@"min"] respondsToSelector:@selector(doubleValue)] ? [item[@"min"] doubleValue] : 0;
        double max = [item[@"max"] respondsToSelector:@selector(doubleValue)] ? [item[@"max"] doubleValue] : 1;
        if (!isfinite(min) || !isfinite(max) || max <= min) {
            min = 0;
            max = 1;
        }
        double value = [current respondsToSelector:@selector(doubleValue)] ? [current doubleValue] : min;
        if (!isfinite(value)) value = min;
        value = MIN(MAX(value, min), max);
        cell.slider.minimumValue = min;
        cell.slider.maximumValue = max;
        cell.slider.value = value;
        cell.valueLabel.text = [NSString stringWithFormat:@"%.2f", cell.slider.value];
        __weak typeof(self) weakSelf = self;
        cell.onChange = ^(float value) {
            [weakSelf setValue:@(value) forKey:key reload:NO];
        };
        return cell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SettingCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SettingCell"];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    }
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = label;

    if ([type isEqualToString:@"switch"]) {
        cell.detailTextLabel.text = [item[@"description"] isKindOfClass:[NSString class]] ? item[@"description"] : nil;
        UISwitch *toggle = [[UISwitch alloc] init];
        toggle.on = [current boolValue];
        __weak typeof(self) weakSelf = self;
        [toggle addAction:[UIAction actionWithHandler:^(UIAction *action) {
            UISwitch *sender = (UISwitch *)action.sender;
            [weakSelf setValue:@(sender.isOn) forKey:key reload:YES];
        }] forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
    } else if ([type isEqualToString:@"picker"]) {
        cell.detailTextLabel.text = [self displayValue:current options:item[@"options"]];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([type isEqualToString:@"text"]) {
        cell.detailTextLabel.text = [current isKindOfClass:[NSString class]] ? current : [current description];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.detailTextLabel.text = localize(@"Unsupported setting type", nil);
    }
    return cell;
}

- (NSString *)displayValue:(id)value options:(NSArray *)options {
    for (id option in options) {
        if ([option isKindOfClass:[NSDictionary class]]) {
            id key = option[@"key"] ?: option[@"value"];
            if ([key isEqual:value]) return option[@"name"] ?: option[@"title"] ?: [key description];
        } else if ([option isEqual:value]) {
            return [option description];
        }
    }
    return [value description] ?: @"";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.plugin.settingsSchema[indexPath.row];
    NSString *type = [item[@"type"] isKindOfClass:[NSString class]] ? item[@"type"] : @"text";
    NSString *key = [item[@"key"] isKindOfClass:[NSString class]] ? item[@"key"] : @"";
    NSString *label = [item[@"label"] isKindOfClass:[NSString class]] ? item[@"label"] : ([item[@"title"] isKindOfClass:[NSString class]] ? item[@"title"] : key);
    id current = self.plugin.settings[key] ?: item[@"default"];
    if ([type isEqualToString:@"text"]) {
        NSString *placeholder = [item[@"placeholder"] isKindOfClass:[NSString class]] ? item[@"placeholder"] : nil;
        NSString *description = [item[@"description"] isKindOfClass:[NSString class]] ? item[@"description"] : nil;
        [AppSheet showPromptWithTitle:label message:description placeholder:placeholder initialText:[current isKindOfClass:[NSString class]] ? current : @"" onConfirm:^(NSString *text) {
            [self setValue:text ?: @"" forKey:key reload:YES];
        }];
    } else if ([type isEqualToString:@"picker"]) {
        NSArray *options = [item[@"options"] isKindOfClass:[NSArray class]] ? item[@"options"] : @[];
        NSMutableArray *sheetOptions = [NSMutableArray array];
        NSInteger selected = NSNotFound;
        for (NSInteger i = 0; i < options.count; i++) {
            id option = options[i];
            NSString *title = [option isKindOfClass:[NSDictionary class]] ? (option[@"name"] ?: option[@"title"] ?: [option[@"key"] description]) : [option description];
            [sheetOptions addObject:@{@"title": title ?: @""}];
            id value = [option isKindOfClass:[NSDictionary class]] ? (option[@"key"] ?: option[@"value"]) : option;
            if ([value isEqual:current]) selected = i;
        }
        [AppSheet showOptionsWithTitle:label message:nil options:sheetOptions selectedIndex:selected selection:^(NSInteger index) {
            if (index < 0 || index >= options.count) return;
            id option = options[index];
            id value = [option isKindOfClass:[NSDictionary class]] ? (option[@"key"] ?: option[@"value"]) : option;
            [self setValue:value forKey:key reload:YES];
        }];
    }
}

- (void)setValue:(id)value forKey:(NSString *)key reload:(BOOL)reload {
    if (key.length == 0) return;
    self.suppressReload = YES;
    NSError *error = nil;
    BOOL saved = [WitchPluginManager.shared setSettingValue:value forKey:key pluginID:self.pluginID error:&error];
    self.suppressReload = NO;
    if (!saved) {
        showDialog(localize(@"Error", nil), error.localizedDescription);
    }
    if (reload) [self.tableView reloadData];
}

@end
