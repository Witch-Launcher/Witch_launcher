#import "SettingsViewController.h"
#import "ThemeManager.h"
#import "LauncherPreferences.h"
#import "utils.h"
#import "HapticManager.h"
#import "ios_uikit_bridge.h"
#import "CurseForgeService.h"
#import "CreditsService.h"
#import "config.h"
#import "CustomControlsViewController.h"
#import "AmethystBlurView.h"
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SettingsViewController () <UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, UIColorPickerViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, PHPickerViewControllerDelegate, UIDocumentPickerDelegate>
@property (nonatomic) NSArray *sections;
@property (nonatomic) UIScrollView *tabBarScroll;
@property (nonatomic) NSLayoutConstraint *tabWidthConstraint;
@property (nonatomic) NSMutableArray *tabButtons;
@property (nonatomic) UIScrollView *pageScroll;
@property (nonatomic) NSMutableArray *pageTables;
@property (nonatomic) NSInteger currentPage;
@property (nonatomic) BOOL skipOffsetSync;
@property (nonatomic, copy) void (^pendingColorPickCallback)(UIColor *);
@property (nonatomic) AmethystBlurView *panelBlur;
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildSections];
    [self setup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(creditsDidUpdate) name:CreditsDidUpdateNotification object:nil];
    [self updateColors];
}

- (void)buildSections {
    NSArray *rendererOptions = [self getRendererOptions];

    NSArray *lwjglOptions = getLwjglVersionsWithAuto();
    NSMutableArray *lwjglItems = [NSMutableArray array];
    for (NSString *ver in lwjglOptions) {
        [lwjglItems addObject:ver];
    }

    NSArray *glVersions = @[@"0", @"3.0", @"3.1", @"3.2", @"3.3", @"4.0", @"4.1", @"4.2", @"4.3", @"4.4", @"4.5", @"4.6"];
    NSArray *zinkOptLevels = @[@"-1", @"0", @"1", @"2", @"3", @"4", @"5"];

    _sections = @[
        @{@"title": localize(@"Render", nil), @"items": @[
            @{@"type": @"picker", @"label": localize(@"preference.title.renderer", nil), @"key": @"video.renderer", @"options": rendererOptions, @"default": @"auto"},
            @{@"type": @"slider", @"label": localize(@"preference.title.resolution", nil), @"key": @"video.resolution", @"min": @25, @"max": @150, @"suffix": @"%"},
            @{@"type": @"switch", @"label": localize(@"preference.title.max_framerate", nil), @"key": @"video.max_framerate"},
            @{@"type": @"switch", @"label": localize(@"preference.title.performance_hud", nil), @"key": @"video.performance_hud"},
        ]},
        @{@"title": localize(@"Custom Controls", nil), @"items": @[
            @{@"type": @"slider", @"label": localize(@"preference.title.button_scale", nil), @"key": @"control.button_scale", @"min": @30, @"max": @200, @"suffix": @"%"},
            @{@"type": @"slider", @"label": localize(@"preference.title.mouse_scale", nil), @"key": @"control.mouse_scale", @"min": @30, @"max": @200, @"suffix": @"%"},
            @{@"type": @"slider", @"label": localize(@"preference.title.mouse_speed", nil), @"key": @"control.mouse_speed", @"min": @10, @"max": @300, @"suffix": @"%"},
            @{@"type": @"switch", @"label": localize(@"preference.title.virtmouse_enable", nil), @"key": @"control.virtmouse_enable"},
            @{@"type": @"switch", @"label": localize(@"preference.title.gyroscope_enable", nil), @"key": @"control.gyroscope_enable"},
            @{@"type": @"switch", @"label": localize(@"preference.title.gyroscope_invert_x_axis", nil), @"key": @"control.gyroscope_invert_x_axis"},
            @{@"type": @"slider", @"label": localize(@"preference.title.gyroscope_sensitivity", nil), @"key": @"control.gyroscope_sensitivity", @"min": @10, @"max": @300, @"suffix": @"%"},
            @{@"type": @"switch", @"label": localize(@"preference.title.slideable_hotbar", nil), @"key": @"control.slideable_hotbar"},
            @{@"type": @"switch", @"label": localize(@"preference.title.gesture_mouse", nil), @"key": @"control.gesture_mouse"},
            @{@"type": @"switch", @"label": localize(@"preference.title.gesture_hotbar", nil), @"key": @"control.gesture_hotbar"},
            @{@"type": @"switch", @"label": localize(@"preference.title.recording_hide", nil), @"key": @"control.recording_hide"},
            @{@"type": @"switch", @"label": localize(@"preference.title.disable_haptics", nil), @"key": @"control.disable_haptics"},
            @{@"type": @"slider", @"label": localize(@"preference.title.press_duration", nil), @"key": @"control.press_duration", @"min": @100, @"max": @1000, @"suffix": @"ms"},
            @{@"type": @"navigate", @"label": localize(@"Mouse Cursors", nil), @"vc": @"CursorManageViewController"},
            @{@"type": @"navigate", @"label": localize(@"Edit Controls Layout", nil), @"vc": @"CustomControlsViewController"},
        ]},
        @{@"title": localize(@"In-Game Widget", nil), @"items": @[
            @{@"type": @"switch", @"label": localize(@"preference.title.widget_menu", nil), @"key": @"general.widget_menu"},
            @{@"type": @"switch", @"label": localize(@"preference.title.widget_show_fps", nil), @"key": @"general.widget_show_fps"},
            @{@"type": @"switch", @"label": localize(@"preference.title.widget_show_cpu", nil), @"key": @"general.widget_show_cpu"},
            @{@"type": @"switch", @"label": localize(@"preference.title.widget_show_gpu", nil), @"key": @"general.widget_show_gpu"},
            @{@"type": @"picker", @"label": localize(@"preference.title.widget_cpu_style", nil), @"key": @"general.widget_cpu_style", @"default": @"percent", @"options": @[
                @{@"key": @"bars", @"name": localize(@"preference.title.widget_cpu_style.bars", nil)},
                @{@"key": @"percent", @"name": localize(@"preference.title.widget_cpu_style.percent", nil)},
                @{@"key": @"ring", @"name": localize(@"preference.title.widget_cpu_style.ring", nil)},
            ]},
            @{@"type": @"picker", @"label": localize(@"preference.title.widget_ram_style", nil), @"key": @"general.widget_ram_style", @"default": @"none", @"options": @[
                @{@"key": @"none", @"name": localize(@"preference.title.widget_ram_style.none", nil)},
                @{@"key": @"text", @"name": @"RAM (1)"},
                @{@"key": @"bar", @"name": @"RAM (2)"},
            ]},
            @{@"type": @"slider", @"label": localize(@"preference.title.widget_size", nil), @"key": @"general.widget_scale", @"min": @50, @"max": @200, @"suffix": @"%"},
            @{@"type": @"switch", @"label": localize(@"preference.title.widget_show_temp", nil), @"key": @"general.widget_show_temp"},
            @{@"type": @"picker", @"label": localize(@"preference.title.widget_temp_unit", nil), @"key": @"general.widget_temp_unit", @"default": @"c", @"options": @[
                @{@"key": @"c", @"name": localize(@"preference.title.widget_temp_unit.c", nil)},
                @{@"key": @"f", @"name": localize(@"preference.title.widget_temp_unit.f", nil)},
            ]},
            @{@"type": @"switch", @"label": localize(@"preference.title.widget_show_batt", nil), @"key": @"general.widget_show_batt"},
            @{@"type": @"slider", @"label": localize(@"preference.title.widget_bg_opacity", nil), @"key": @"general.widget_bg_opacity", @"min": @0, @"max": @80, @"suffix": @"%"},
        ]},
        @{@"title": localize(@"Game", nil), @"items": @[
            @{@"type": @"picker", @"label": localize(@"LWJGL Version", nil), @"key": @"java.lwjgl_version", @"options": lwjglItems, @"default": @"(auto)"},
            @{@"type": @"switch", @"label": localize(@"preference.title.fullscreen_airplay", nil), @"key": @"video.fullscreen_airplay"},
        ]},
        @{@"title": localize(@"Audio", nil), @"items": @[
            @{@"type": @"switch", @"label": localize(@"preference.title.allow_microphone", nil), @"key": @"video.allow_microphone"},
            @{@"type": @"picker", @"label": localize(@"preference.title.microphone_source", nil), @"key": @"video.microphone_source", @"options": @[@"auto", @"front", @"bottom", @"back"], @"default": @"auto"},
            @{@"type": @"switch", @"label": localize(@"preference.title.silence_other_audio", nil), @"key": @"video.silence_other_audio"},
        ]},
        @{@"title": localize(@"Gamepad", nil), @"items": @[
            @{@"type": @"picker", @"label": localize(@"preference.title.default_gamepad_ctrl", nil), @"key": @"control.controller_type", @"options": @[@"none", @"mfi", @"ps4", @"ps5", @"xbox"], @"default": @"none"},
            @{@"type": @"slider", @"label": localize(@"preference.title.gamepad_sensitivity", nil), @"key": @"control.gamepad_sensitivity", @"min": @10, @"max": @300, @"suffix": @"%"},
            @{@"type": @"switch", @"label": localize(@"preference.title.hardware_hide", nil), @"key": @"control.hardware_hide"},
            @{@"type": @"navigate", @"label": localize(@"Gamepad Layout", nil), @"vc": @"LauncherPrefContCfgViewController"},
        ]},
        @{@"title": localize(@"Launcher", nil), @"items": @[
            @{@"type": @"navigate", @"label": localize(@"preference.title.game_directory", nil), @"vc": @"LauncherPrefGameDirViewController"},
            @{@"type": @"navigate", @"label": localize(@"preference.title.manage_runtime", nil) , @"vc": @"LauncherPrefManageJREViewController"},
            @{@"type": @"text", @"label": localize(@"preference.title.java_args", nil), @"key": @"java.java_args", @"placeholder": @"-Xmx2G -Xms512M"},
            @{@"type": @"text", @"label": localize(@"preference.title.env_variables", nil), @"key": @"java.env_variables", @"placeholder": @"VAR=value"},
            @{@"type": @"slider", @"label": localize(@"preference.title.allocated_memory", nil), @"key": @"java.allocated_memory", @"min": @256, @"max": @((NSProcessInfo.processInfo.physicalMemory / 1048576) * 0.85), @"suffix": @"MB"},
            @{@"type": @"switch", @"label": localize(@"preference.title.auto_ram", nil), @"key": @"java.auto_ram"},
            @{@"type": @"switch", @"label": localize(@"preference.title.check_sha", nil), @"key": @"general.check_sha"},
            @{@"type": @"switch", @"label": localize(@"preference.title.cosmetica", nil), @"key": @"general.cosmetica"},
            @{@"type": @"picker", @"label": localize(@"Screen Orientation", nil), @"key": @"general.orientation_lock", @"options": @[
                @{@"key": @"off", @"name": localize(@"Off", nil)},
                @{@"key": @"portrait", @"name": localize(@"Portrait", nil)},
                @{@"key": @"landscape", @"name": localize(@"Landscape", nil)},
            ], @"default": @"off"},
            @{@"type": @"picker", @"label": localize(@"Theme", nil), @"key": @"launcher.theme", @"options": @[@"System", @"Dark", @"Light"], @"default": @"System"},
            @{@"type": @"picker", @"label": localize(@"Launcher Logo", nil), @"key": @"launcher.logo_style", @"options": @[
                @{@"key": @"purple", @"name": localize(@"Purple", nil)},
                @{@"key": @"blue", @"name": localize(@"Blue", nil)},
                @{@"key": @"dev", @"name": localize(@"Dev", nil)},
            ], @"default": (CONFIG_RELEASE ? @"purple" : @"dev"), @"preview": @YES},
            @{@"type": @"text", @"label": localize(@"CurseForge API Key", nil), @"key": @"curseforge.api_key", @"placeholder": localize(@"Paste your CurseForge API key here", nil)},
            @{@"type": @"switch", @"label": localize(@"preference.title.debug_logging", nil), @"key": @"general.debug_logging"},
            @{@"type": @"switch", @"label": localize(@"preference.title.debug_ipad_ui", nil), @"key": @"debug.debug_ipad_ui"},
            @{@"type": @"switch", @"label": localize(@"preference.title.debug_skip_wait_jit", nil), @"key": @"debug.debug_skip_wait_jit"},
        ]},
        @{@"title": localize(@"MobileGlues", nil), @"items": @[
            @{@"type": @"switch", @"label": localize(@"preference.title.enable_angle", nil), @"key": @"mobileglues.enable_angle"},
            @{@"type": @"picker", @"label": localize(@"preference.title.enable_no_error", nil), @"key": @"mobileglues.enable_no_error", @"options": @[@"0", @"1", @"2"], @"default": @"0"},
            @{@"type": @"switch", @"label": localize(@"preference.title.enable_ext_timer_query", nil), @"key": @"mobileglues.enable_ext_timer_query"},
            @{@"type": @"switch", @"label": localize(@"preference.title.enable_ext_compute_shader", nil), @"key": @"mobileglues.enable_ext_compute_shader"},
            @{@"type": @"switch", @"label": localize(@"preference.title.enable_ext_direct_state_access", nil), @"key": @"mobileglues.enable_ext_direct_state_access"},
            @{@"type": @"slider", @"label": localize(@"preference.title.max_glsl_cache_size", nil), @"key": @"mobileglues.max_glsl_cache_size", @"min": @8, @"max": @512, @"suffix": @"MB"},
            @{@"type": @"picker", @"label": localize(@"preference.title.multidraw_mode", nil), @"key": @"mobileglues.multidraw_mode", @"options": @[@"0", @"1", @"2", @"3"], @"default": @"0"},
            @{@"type": @"switch", @"label": localize(@"preference.title.angle_depth_clear_fix_mode", nil), @"key": @"mobileglues.angle_depth_clear_fix_mode"},
            @{@"type": @"picker", @"label": localize(@"preference.title.custom_gl_version", nil), @"key": @"mobileglues.custom_gl_version", @"options": glVersions, @"default": @"0"},
            @{@"type": @"picker", @"label": localize(@"preference.title.fsr1_setting", nil), @"key": @"mobileglues.fsr1_setting", @"options": @[@"0", @"1", @"2", @"3", @"4", @"5"], @"default": @"0"},
        ]},
        @{@"title": localize(@"Zink", nil), @"items": @[
            @{@"type": @"picker", @"label": localize(@"Optimization Level", nil), @"key": @"zink.optimization_level", @"options": zinkOptLevels, @"default": @"-1"},
            @{@"type": @"picker", @"label": localize(@"preference.title.zink_gl_override", nil), @"key": @"zink.gl_override", @"options": @[@"0", @"3.3", @"4.0", @"4.1", @"4.3", @"4.6"], @"default": @"0"},
            @{@"type": @"switch", @"label": localize(@"preference.title.zink_enable_gl_thread", nil), @"key": @"zink.enable_gl_thread"},
            @{@"type": @"slider", @"label": localize(@"preference.title.zink_glsl_cache_size", nil), @"key": @"zink.glsl_cache_size", @"min": @8, @"max": @512, @"suffix": @"MB"},
            @{@"type": @"picker", @"label": localize(@"preference.title.zink_api_features", nil), @"key": @"zink.api_features", @"options": @[@"0", @"1", @"2", @"3"], @"default": @"3"},
        ]},
        @{@"title": localize(@"Debug", nil), @"items": @[
            @{@"type": @"switch", @"label": localize(@"preference.title.debug_always_attached_jit", nil), @"key": @"debug.debug_always_attached_jit"},
            @{@"type": @"switch", @"label": localize(@"preference.title.debug_hide_home_indicator", nil), @"key": @"debug.debug_hide_home_indicator"},
            @{@"type": @"switch", @"label": localize(@"preference.title.debug_auto_correction", nil), @"key": @"debug.debug_auto_correction"},
            @{@"type": @"switch", @"label": localize(@"preference.title.debug_server_enabled", nil), @"key": @"debug.debug_server_enabled"},
            @{@"type": @"text", @"label": localize(@"Debug Server Port", nil), @"key": @"debug.debug_server_port", @"placeholder": @"9090"},
            @{@"type": @"text", @"label": localize(@"Debug Server Token", nil), @"key": @"debug.debug_server_token", @"placeholder": @""},
            @{@"type": @"switch", @"label": localize(@"preference.title.debug_server_localhost_only", nil), @"key": @"debug.debug_server_localhost_only"},
        ]},
        @{@"title": localize(@"Appearance", nil), @"items": @[
            @{@"type": @"color", @"label": localize(@"Accent Color", nil), @"key": @"amethyst_accent_color"},
            @{@"type": @"color", @"label": localize(@"Text Color", nil), @"key": @"amethyst_text_color"},
            @{@"type": @"color", @"label": localize(@"Secondary Text Color", nil), @"key": @"amethyst_secondary_text_color"},
            @{@"type": @"color", @"label": localize(@"Background Color", nil), @"key": @"amethyst_bg_color"},
            @{@"type": @"color", @"label": localize(@"Sidebar Color", nil), @"key": @"amethyst_sidebar_bg_color"},
            @{@"type": @"color", @"label": localize(@"Top Bar Color", nil), @"key": @"amethyst_topbar_bg_color"},
            @{@"type": @"color", @"label": localize(@"Right Panel Color", nil), @"key": @"amethyst_rightpanel_bg_color"},
            @{@"type": @"color", @"label": localize(@"Content Card Color", nil), @"key": @"amethyst_card_bg_color"},
            @{@"type": @"image", @"label": localize(@"Background", nil)},
            @{@"type": @"slider", @"label": localize(@"UI Opacity", nil), @"key": @"amethyst_ui_opacity", @"min": @0, @"max": @100, @"suffix": @"%"},
            @{@"type": @"slider", @"label": localize(@"Background Blur", nil), @"key": @"amethyst_bg_blur", @"min": @0, @"max": @20, @"suffix": @""},
            @{@"type": @"slider", @"label": @"UI Panels Blur", @"key": @"amethyst_settings_blur", @"min": @0, @"max": @100, @"suffix": @"%"},
            @{@"type": @"export", @"label": localize(@"Export Appearance Theme", nil)},
            @{@"type": @"import", @"label": localize(@"Import Appearance Theme", nil)},
            @{@"type": @"color", @"label": localize(@"Reset Appearance", nil), @"key": @"amethyst_reset_appearance"},
        ]},
        @{@"title": localize(@"credits.title", nil), @"items": [self creditsItems]},
    ];

    NSUInteger appearanceIndex = NSNotFound;
    for (NSUInteger i = 0; i < _sections.count; i++) {
        if ([_sections[i][@"title"] isEqualToString:localize(@"Appearance", nil)]) {
            appearanceIndex = i;
            break;
        }
    }
    NSMutableArray *appearanceItems = [_sections[appearanceIndex][@"items"] mutableCopy];
    if (@available(iOS 16, *)) {
        [appearanceItems insertObject:@{@"type": @"switch", @"label": @"Liquid Glass", @"key": @"general.liquid_glass"} atIndex:0];
    }
    NSMutableDictionary *appearanceSection = [_sections[appearanceIndex] mutableCopy];
    appearanceSection[@"items"] = appearanceItems;
    NSMutableArray *mutableSections = [_sections mutableCopy];
    mutableSections[appearanceIndex] = appearanceSection;
    _sections = mutableSections;
}

- (NSArray *)creditsItems {
    CreditsService *service = CreditsService.shared;
    NSMutableArray *items = [NSMutableArray array];

    if (service.authorName.length > 0) {
        [items addObject:@{@"type": @"author", @"label": localize(@"credits.author", nil), @"detail": service.authorName}];
    }
    for (CreditsSocial *social in service.socials) {
        [items addObject:@{@"type": @"link", @"label": social.label, @"detail": @"", @"url": social.url}];
    }
    if (service.components.count == 0) {
        [items addObject:@{@"type": @"label", @"label": localize(@"credits.unavailable", nil), @"detail": @""}];
    } else {
        for (CreditsComponent *component in service.components) {
            [items addObject:@{@"type": @"credit", @"label": component.name, @"detail": component.license ?: @"", @"license": component.license ?: @"", @"url": component.url ?: @"", @"licenseUrl": component.licenseUrl ?: @""}];
        }
    }
    return items;
}

- (void)creditsDidUpdate {
    NSUInteger creditsIndex = NSNotFound;
    for (NSUInteger i = 0; i < _sections.count; i++) {
        if ([_sections[i][@"title"] isEqualToString:localize(@"credits.title", nil)]) {
            creditsIndex = i;
            break;
        }
    }
    if (creditsIndex == NSNotFound) return;
    NSMutableDictionary *creditsSection = [_sections[creditsIndex] mutableCopy];
    creditsSection[@"items"] = [self creditsItems];
    NSMutableArray *mutableSections = [_sections mutableCopy];
    mutableSections[creditsIndex] = creditsSection;
    _sections = mutableSections;
    [self reloadTables];
}

- (NSArray *)getRendererOptions {
    NSArray *renderers = getRendererKeys(YES);
    NSArray *names = getRendererNames(YES);
    NSMutableArray *options = [NSMutableArray array];
    for (NSUInteger i = 0; i < renderers.count && i < names.count; i++) {
        [options addObject:@{
            @"key": renderers[i],
            @"name": names[i]
        }];
    }
    if (options.count == 0) {
        options = [@[@{@"key": @"auto", @"name": @"Auto"}] mutableCopy];
    }
    return options;
}

- (void)setup {
    self.view.clipsToBounds = YES;
    self.navigationItem.title = localize(@"Settings", nil);
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSettings)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:localize(@"preference.title.reset_settings", nil) style:UIBarButtonItemStylePlain target:self action:@selector(resetSettings)];

    [self setupTabBar];
    [self setupPages];
    [self setupBackgroundBlur];

    _tabWidthConstraint = [_tabBarScroll.widthAnchor constraintEqualToConstant:132];
    [NSLayoutConstraint activateConstraints:@[
        [_tabBarScroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tabBarScroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tabBarScroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        _tabWidthConstraint,

        [_pageScroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_pageScroll.leadingAnchor constraintEqualToAnchor:_tabBarScroll.trailingAnchor],
        [_pageScroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_pageScroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupTabBar {
    _tabBarScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _tabBarScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _tabBarScroll.showsHorizontalScrollIndicator = NO;
    _tabBarScroll.showsVerticalScrollIndicator = NO;
    _tabBarScroll.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_tabBarScroll];

    _tabButtons = [NSMutableArray array];
    for (NSUInteger i = 0; i < _sections.count; i++) {
        NSDictionary *section = _sections[i];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = (NSInteger)i;
        [btn setTitle:section[@"title"] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        btn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        btn.contentEdgeInsets = UIEdgeInsetsMake(0, 14, 0, 4);
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(0, 13, 3, 16)];
        indicator.tag = 99;
        indicator.layer.cornerRadius = 1.5;
        indicator.hidden = YES;
        [btn addSubview:indicator];

        [_tabBarScroll addSubview:btn];
        [_tabButtons addObject:btn];
    }
    [self layoutTabButtons];
}

- (void)layoutTabButtons {
    CGFloat sideWidth = _tabBarScroll.bounds.size.width;
    CGFloat y = 8;
    for (NSUInteger i = 0; i < _tabButtons.count; i++) {
        UIButton *btn = _tabButtons[i];
        btn.frame = CGRectMake(0, y, sideWidth, 40);
        y += 46;
    }
    _tabBarScroll.contentSize = CGSizeMake(sideWidth, y + 8);
}

- (void)setupPages {
    _pageScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _pageScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _pageScroll.pagingEnabled = YES;
    _pageScroll.showsHorizontalScrollIndicator = NO;
    _pageScroll.showsVerticalScrollIndicator = NO;
    _pageScroll.bounces = NO;
    _pageScroll.delegate = self;
    [self.view addSubview:_pageScroll];

    _pageTables = [NSMutableArray array];
    for (NSUInteger i = 0; i < _sections.count; i++) {
        UITableView *tv = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
        tv.translatesAutoresizingMaskIntoConstraints = NO;
        tv.delegate = self;
        tv.dataSource = self;
        tv.backgroundColor = [UIColor clearColor];
        tv.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        tv.tag = (NSInteger)i;
        [_pageScroll addSubview:tv];
        [_pageTables addObject:tv];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat sideWidth = MAX(110, MIN(190, self.view.bounds.size.width * 0.24));
    if (_tabWidthConstraint.constant != sideWidth) {
        _tabWidthConstraint.constant = sideWidth;
        [self.view layoutIfNeeded];
    }
    [self layoutTabButtons];

    CGFloat pageW = MAX(_pageScroll.bounds.size.width, 1);
    CGFloat pageH = _pageScroll.bounds.size.height;
    _pageScroll.contentSize = CGSizeMake(pageW * _pageTables.count, pageH);
    for (NSUInteger i = 0; i < _pageTables.count; i++) {
        UITableView *tv = _pageTables[i];
        tv.frame = CGRectMake(pageW * i, 0, pageW, pageH);
    }
    if (!_skipOffsetSync && fabs(_pageScroll.contentOffset.x - pageW * _currentPage) > 1.0) {
        [_pageScroll setContentOffset:CGPointMake(pageW * _currentPage, 0) animated:NO];
    }
}

- (void)dismissSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setupBackgroundBlur {
    // One realtime frost layer behind everything in Settings.
    _panelBlur = [[AmethystBlurView alloc] initWithFrame:CGRectZero];
    [self.view insertSubview:_panelBlur atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [_panelBlur.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_panelBlur.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_panelBlur.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_panelBlur.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

- (void)refreshTableBackdrops {
    BOOL blurOn = AmethystBlurView.blurEnabled;
    UIColor *bg = blurOn ? [UIColor clearColor] : ThemeManager.shared.contentBackgroundColor;
    for (UITableView *tv in _pageTables) {
        tv.backgroundColor = bg;
    }
}

- (void)updateColors {
    ThemeManager *theme = ThemeManager.shared;
    self.view.backgroundColor = theme.contentBackgroundColor;
    [_panelBlur applyCurrentIntensity];
    [self refreshTableBackdrops];
    for (UIButton *btn in _tabButtons) {
        [self updateTabStyle:btn];
    }
}

#pragma mark - Tab Bar

- (void)tabTapped:(UIButton *)sender {
    [HapticManager.shared play:HapticTypeLight];
    [self setPage:sender.tag animated:YES];
}

- (void)setPage:(NSInteger)page animated:(BOOL)animated {
    _currentPage = page;
    for (UIButton *btn in _tabButtons) {
        [self updateTabStyle:btn];
    }
    UIButton *btn = _tabButtons[page];
    [_tabBarScroll scrollRectToVisible:CGRectInset(btn.frame, 0, -40) animated:animated];
    if (animated) {
        _skipOffsetSync = YES;
        [_pageScroll setContentOffset:CGPointMake(_pageScroll.bounds.size.width * page, 0) animated:YES];
    } else {
        _skipOffsetSync = NO;
        [_pageScroll setContentOffset:CGPointMake(_pageScroll.bounds.size.width * page, 0) animated:NO];
    }
}

- (void)updateTabStyle:(UIButton *)btn {
    BOOL selected = btn.tag == _currentPage;
    ThemeManager *theme = ThemeManager.shared;
    [btn setTitleColor:selected ? theme.accentColor : theme.secondaryTextColor forState:UIControlStateNormal];
    UIView *indicator = [btn viewWithTag:99];
    indicator.backgroundColor = theme.accentColor;
    indicator.hidden = !selected;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView == _pageScroll) {
        _skipOffsetSync = NO;
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == _pageScroll) {
        [self syncPageFromScroll];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (scrollView == _pageScroll) {
        _skipOffsetSync = NO;
        [self syncPageFromScroll];
    }
}

- (void)syncPageFromScroll {
    NSInteger page = roundf(_pageScroll.contentOffset.x / MAX(_pageScroll.bounds.size.width, 1));
    page = MAX(0, MIN((NSInteger)_pageTables.count - 1, page));
    if (page != _currentPage) {
        _currentPage = page;
    }
    for (UIButton *btn in _tabButtons) {
        [self updateTabStyle:btn];
    }
    UIButton *btn = _tabButtons[page];
    [_tabBarScroll scrollRectToVisible:CGRectInset(btn.frame, 0, -40) animated:YES];
}

#pragma mark - TableView

- (NSDictionary *)itemsForTable:(UITableView *)tableView {
    return _sections[tableView.tag][@"items"];
}

- (NSDictionary *)itemAtIndexPath:(NSIndexPath *)indexPath inTable:(UITableView *)tableView {
    return [_sections[tableView.tag][@"items"] objectAtIndex:indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self itemsForTable:tableView].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[tableView.tag][@"title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (tableView.tag == (NSInteger)(_sections.count - 1)) {
        return localize(@"Colors apply to the current theme (Light/Dark). Switch theme to customize each separately.", nil);
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 36;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = [self itemAtIndexPath:indexPath inTable:tableView];
    if ([item[@"type"] isEqualToString:@"label"]) {
        return 64;
    }
    return 48;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = [self itemAtIndexPath:indexPath inTable:tableView];
    NSString *type = item[@"type"];
    NSString *cellId = type;

    NSInteger const kLabelTag = 100;
    NSInteger const kValLabelTag = 101;
    NSInteger const kSliderTag = 102;
    NSInteger const kTextFieldTag = 103;
    NSInteger const kColorWellTag = 104;

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        if ([type isEqualToString:@"switch"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
            UISwitch *sw = [[UISwitch alloc] init];
            sw.onTintColor = ThemeManager.shared.accentColor;
            [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if ([type isEqualToString:@"slider"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UILabel *label = [[UILabel alloc] init];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.tag = kLabelTag;
            label.font = [UIFont systemFontOfSize:15];
            label.textColor = ThemeManager.shared.primaryTextColor;
            label.numberOfLines = 1;
            [cell.contentView addSubview:label];

            UILabel *valLabel = [[UILabel alloc] init];
            valLabel.translatesAutoresizingMaskIntoConstraints = NO;
            valLabel.tag = kValLabelTag;
            valLabel.font = [UIFont systemFontOfSize:13];
            valLabel.textColor = ThemeManager.shared.secondaryTextColor;
            valLabel.textAlignment = NSTextAlignmentRight;
            [cell.contentView addSubview:valLabel];

            UISlider *slider = [[UISlider alloc] init];
            slider.translatesAutoresizingMaskIntoConstraints = NO;
            slider.tag = kSliderTag;
            slider.minimumValue = [item[@"min"] floatValue];
            slider.maximumValue = [item[@"max"] floatValue];
            slider.minimumTrackTintColor = ThemeManager.shared.accentColor;
            slider.maximumTrackTintColor = ThemeManager.shared.separatorColor;
            slider.thumbTintColor = ThemeManager.shared.accentColor;
            [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:slider];

            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
                [label.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:6],

                [valLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
                [valLabel.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
                [valLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:label.trailingAnchor constant:8],

                [slider.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
                [slider.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
                [slider.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:0],
                [slider.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4],
            ]];
        } else if ([type isEqualToString:@"picker"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
            cell.detailTextLabel.textColor = ThemeManager.shared.accentColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([type isEqualToString:@"text"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UILabel *label = [[UILabel alloc] init];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.tag = kLabelTag;
            label.font = [UIFont systemFontOfSize:15];
            label.textColor = ThemeManager.shared.primaryTextColor;
            [cell.contentView addSubview:label];

            UITextField *tf = [[UITextField alloc] init];
            tf.translatesAutoresizingMaskIntoConstraints = NO;
            tf.tag = kTextFieldTag;
            tf.font = [UIFont systemFontOfSize:13];
            tf.textColor = ThemeManager.shared.secondaryTextColor;
            tf.textAlignment = NSTextAlignmentRight;
            tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
            tf.autocorrectionType = UITextAutocorrectionTypeNo;
            [tf addTarget:self action:@selector(textFieldChanged:) forControlEvents:UIControlEventEditingChanged];
            [cell.contentView addSubview:tf];

            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
                [label.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [label.trailingAnchor constraintLessThanOrEqualToAnchor:tf.leadingAnchor constant:-8],

                [tf.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
                [tf.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
                [tf.widthAnchor constraintEqualToConstant:200],
            ]];
        } else if ([type isEqualToString:@"navigate"] || [type isEqualToString:@"export"] || [type isEqualToString:@"import"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([type isEqualToString:@"color"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;

            UIView *colorPreview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
            colorPreview.tag = kColorWellTag;
            colorPreview.layer.cornerRadius = 6;
            colorPreview.layer.borderWidth = 1;
            colorPreview.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
            colorPreview.userInteractionEnabled = NO;
            cell.accessoryView = colorPreview;
        } else if ([type isEqualToString:@"image"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([type isEqualToString:@"credit"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
            cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([type isEqualToString:@"author"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.secondaryTextColor;
            cell.detailTextLabel.textColor = ThemeManager.shared.accentColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if ([type isEqualToString:@"link"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([type isEqualToString:@"label"]) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
            cell.textLabel.font = [UIFont systemFontOfSize:13];
            cell.textLabel.numberOfLines = 0;
            cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
            cell.textLabel.textColor = ThemeManager.shared.secondaryTextColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    }

    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    if ([type isEqualToString:@"switch"] || [type isEqualToString:@"picker"] || [type isEqualToString:@"navigate"] || [type isEqualToString:@"color"] || [type isEqualToString:@"image"] || [type isEqualToString:@"export"] || [type isEqualToString:@"import"] || [type isEqualToString:@"credit"] || [type isEqualToString:@"author"] || [type isEqualToString:@"link"] || [type isEqualToString:@"label"]) {
        cell.textLabel.text = item[@"label"];
    }

    if ([type isEqualToString:@"credit"] || [type isEqualToString:@"author"]) {
        cell.detailTextLabel.text = item[@"detail"];
    } else if ([type isEqualToString:@"picker"]) {
        id value = getPrefObject(item[@"key"]) ?: item[@"default"];
        NSString *display = [value isKindOfClass:[NSString class]] ? value : [value description];
        NSArray *options = item[@"options"];
        if ([options.firstObject isKindOfClass:[NSDictionary class]]) {
            for (NSDictionary *opt in options) {
                if ([opt[@"key"] isEqualToString:display]) {
                    display = opt[@"name"];
                    break;
                }
            }
        }
        cell.detailTextLabel.text = display;
        if ([item[@"preview"] boolValue]) {
            UIImageView *preview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
            preview.contentMode = UIViewContentModeScaleAspectFit;
            preview.layer.cornerRadius = 9;
            preview.layer.masksToBounds = YES;
            preview.layer.borderWidth = 1;
            preview.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
            preview.image = [UIImage imageNamed:[self logoImageNameForStyle:value]];
            cell.accessoryView = preview;
        } else {
            cell.accessoryView = nil;
        }
    } else if ([type isEqualToString:@"switch"]) {
        UISwitch *sw = (UISwitch *)cell.accessoryView;
        sw.on = getPrefBool(item[@"key"]);
    } else if ([type isEqualToString:@"slider"]) {
        UILabel *label = (UILabel *)[cell.contentView viewWithTag:kLabelTag];
        UILabel *valLabel = (UILabel *)[cell.contentView viewWithTag:kValLabelTag];
        UISlider *sl = (UISlider *)[cell.contentView viewWithTag:kSliderTag];
        label.text = item[@"label"];
        float val;
        BOOL disabled = NO;
        if ([item[@"key"] isEqualToString:@"java.allocated_memory"] && getPrefBool(@"java.auto_ram")) {
            CGFloat autoRatio = getEntitlementValue(@"com.apple.private.memorystatus") ? 0.4 : 0.25;
            val = roundf((NSProcessInfo.processInfo.physicalMemory / 1048576) * autoRatio);
            disabled = YES;
        } else if ([item[@"key"] isEqualToString:@"amethyst_bg_blur"]) {
            val = ThemeManager.shared.backgroundBlurIntensity;
        } else if ([item[@"key"] isEqualToString:@"amethyst_ui_opacity"]) {
            val = ThemeManager.shared.uiOpacity * 100.0;
        } else if ([item[@"key"] isEqualToString:@"amethyst_settings_blur"]) {
            val = [[NSUserDefaults standardUserDefaults] floatForKey:@"amethyst_settings_blur"];
        } else {
            val = getPrefFloat(item[@"key"]);
            if ([item[@"key"] isEqualToString:@"java.allocated_memory"] && val < [item[@"min"] floatValue]) {
                CGFloat autoRatio = getEntitlementValue(@"com.apple.private.memorystatus") ? 0.4 : 0.25;
                val = roundf((NSProcessInfo.processInfo.physicalMemory / 1048576) * autoRatio);
                setPrefFloat(@"java.allocated_memory", val);
            }
        }
        if (val == 0 && ![item[@"key"] isEqualToString:@"amethyst_bg_blur"] && ![item[@"key"] isEqualToString:@"amethyst_ui_opacity"] && ![item[@"key"] isEqualToString:@"amethyst_settings_blur"] && ![item[@"key"] isEqualToString:@"general.widget_bg_opacity"] && !disabled) val = [item[@"min"] floatValue] + ([item[@"max"] floatValue] - [item[@"min"] floatValue]) / 2;
        sl.minimumValue = [item[@"min"] floatValue];
        sl.maximumValue = [item[@"max"] floatValue];
        sl.value = val;
        sl.enabled = !disabled;
        sl.thumbTintColor = disabled ? ThemeManager.shared.separatorColor : ThemeManager.shared.accentColor;
        valLabel.text = [NSString stringWithFormat:@"%.0f%@", sl.value, item[@"suffix"] ?: @""];
    } else if ([type isEqualToString:@"text"]) {
        UILabel *label = (UILabel *)[cell.contentView viewWithTag:kLabelTag];
        UITextField *tf = (UITextField *)[cell.contentView viewWithTag:kTextFieldTag];
        label.text = item[@"label"];
        tf.placeholder = item[@"placeholder"] ?: @"";
        tf.text = [getPrefObject(item[@"key"]) description];
    } else if ([type isEqualToString:@"color"]) {
        UIView *preview = [cell.contentView viewWithTag:kColorWellTag] ?: cell.accessoryView;
        if ([preview isKindOfClass:[UIView class]]) {
            UIColor *color = [self colorForKey:item[@"key"]];
            preview.backgroundColor = color;
            preview.layer.borderColor = ThemeManager.shared.separatorColor.CGColor;
        }
    }

    return cell;
}

- (NSString *)logoImageNameForStyle:(NSString *)style {
    if ([style isEqualToString:@"blue"]) {
        return ThemeManager.shared.isDarkMode ? @"logo-main-dark" : @"logo-main-light";
    }
    if ([style isEqualToString:@"dev"]) {
        return @"logo-dev";
    }
    return ThemeManager.shared.isDarkMode ? @"logo-dark" : @"logo-light";
}

- (UIColor *)colorForKey:(NSString *)key {
    ThemeManager *theme = ThemeManager.shared;
    UIColor *override = [theme colorOverrideForKey:key];
    if (override) return override;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *hex = [defaults stringForKey:key];
    if (hex) {
        hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
        if (hex.length == 6) {
            unsigned int rgb = 0;
            [[NSScanner scannerWithString:hex] scanHexInt:&rgb];
            return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                                   green:((rgb >> 8) & 0xFF) / 255.0
                                    blue:(rgb & 0xFF) / 255.0
                                   alpha:1.0];
        }
    }
    if ([key isEqualToString:@"amethyst_accent_color"]) {
        return theme.accentColor;
    }
    if ([key isEqualToString:@"amethyst_text_color"]) {
        return theme.primaryTextColor;
    }
    if ([key isEqualToString:@"amethyst_secondary_text_color"]) {
        return theme.secondaryTextColor;
    }
    return [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = [self itemAtIndexPath:indexPath inTable:tableView];
    NSString *type = item[@"type"];

    if ([type isEqualToString:@"picker"]) {
        [self showPickerForItem:item fromTable:tableView];
    } else if ([type isEqualToString:@"link"]) {
        NSString *urlString = item[@"url"];
        if (urlString.length > 0) {
            NSURL *url = [NSURL URLWithString:urlString];
            if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        }
    } else if ([type isEqualToString:@"credit"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:item[@"label"] message:item[@"license"] preferredStyle:UIAlertControllerStyleAlert];
        if ([item[@"licenseUrl"] length] > 0) {
            [alert addAction:[UIAlertAction actionWithTitle:localize(@"credits.open_license", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSURL *url = [NSURL URLWithString:item[@"licenseUrl"]];
                if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
            }]];
        } else if ([item[@"url"] length] > 0) {
            [alert addAction:[UIAlertAction actionWithTitle:localize(@"credits.open_project", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSURL *url = [NSURL URLWithString:item[@"url"]];
                if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
            }]];
        }
        [alert addAction:[UIAlertAction actionWithTitle:localize(@"Done", nil) style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if ([type isEqualToString:@"navigate"]) {
        [self navigateToVC:item[@"vc"] title:item[@"label"]];
    } else if ([type isEqualToString:@"color"]) {
        if ([item[@"key"] isEqualToString:@"amethyst_reset_appearance"]) {
            [self resetAppearance];
        } else {
            [self showColorPickerForKey:item[@"key"] label:item[@"label"]];
        }
    } else if ([type isEqualToString:@"image"]) {
        [self showImagePicker];
    } else if ([type isEqualToString:@"export"]) {
        [self exportAppearance];
    } else if ([type isEqualToString:@"import"]) {
        [self importAppearance];
    }
}

#pragma mark - Actions

- (UITableView *)tableForCell:(UITableViewCell *)cell {
    UIView *view = cell.superview;
    while (view && ![view isKindOfClass:[UITableView class]]) {
        view = view.superview;
    }
    return (UITableView *)view;
}

- (void)switchChanged:(UISwitch *)sender {
    UITableViewCell *cell = (UITableViewCell *)sender.superview;
    if (![cell isKindOfClass:[UITableViewCell class]]) {
        cell = (UITableViewCell *)sender.superview.superview;
    }
    UITableView *table = [self tableForCell:cell];
    NSIndexPath *ip = [table indexPathForCell:cell];
    if (!ip) return;
    NSDictionary *item = [self itemAtIndexPath:ip inTable:table];
    setPrefBool(item[@"key"], sender.on);
    if ([item[@"key"] isEqualToString:@"java.auto_ram"]) {
        if (!sender.on) {
            CGFloat autoRatio = getEntitlementValue(@"com.apple.private.memorystatus") ? 0.4 : 0.25;
            float autoVal = roundf((NSProcessInfo.processInfo.physicalMemory / 1048576) * autoRatio);
            setPrefFloat(@"java.allocated_memory", autoVal);
        }
        [self reloadTables];
    } else if ([item[@"key"] isEqualToString:@"general.liquid_glass"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LiquidGlassDidChangeNotification" object:nil];
    }
}

- (void)applyOrientationLock {
    [UIViewController attemptRotationToDeviceOrientation];
    UIInterfaceOrientationMask mask = amethyst_orientation_mask();
    if (@available(iOS 16.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                UIWindowSceneGeometryPreferencesIOS *prefs = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask];
                [(UIWindowScene *)scene requestGeometryUpdateWithPreferences:prefs errorHandler:^(NSError *error) {
                    NSLog(@"[OrientationLock] requestGeometryUpdate error: %@", error);
                }];
            }
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OrientationLockDidChange" object:nil];
}

- (void)sliderChanged:(UISlider *)sender {
    UITableViewCell *cell = (UITableViewCell *)sender.superview.superview;
    UITableView *table = [self tableForCell:cell];
    NSIndexPath *ip = [table indexPathForCell:cell];
    if (!ip) return;
    NSDictionary *item = [self itemAtIndexPath:ip inTable:table];
    float val = roundf(sender.value);
    if ([item[@"key"] isEqualToString:@"amethyst_bg_blur"]) {
        ThemeManager.shared.backgroundBlurIntensity = val;
    } else if ([item[@"key"] isEqualToString:@"amethyst_ui_opacity"]) {
        ThemeManager.shared.uiOpacity = val / 100.0;
    } else if ([item[@"key"] isEqualToString:@"amethyst_settings_blur"]) {
        [[NSUserDefaults standardUserDefaults] setFloat:val forKey:@"amethyst_settings_blur"];
        [_panelBlur applyCurrentIntensity];
        [self refreshTableBackdrops];
        [[NSNotificationCenter defaultCenter] postNotificationName:AmethystBlurIntensityDidChangeNotification object:nil];
    } else {
        setPrefFloat(item[@"key"], val);
        if ([item[@"key"] isEqualToString:@"video.resolution"]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ResolutionDidChangeNotification" object:nil];
        }
    }
    UILabel *valLabel = (UILabel *)[cell.contentView viewWithTag:101];
    valLabel.text = [NSString stringWithFormat:@"%.0f%@", val, item[@"suffix"] ?: @""];
}

- (void)textFieldChanged:(UITextField *)sender {
    UITableViewCell *cell = (UITableViewCell *)sender.superview.superview;
    UITableView *table = [self tableForCell:cell];
    NSIndexPath *ip = [table indexPathForCell:cell];
    if (!ip) return;
    NSDictionary *item = [self itemAtIndexPath:ip inTable:table];
    NSString *key = item[@"key"];
    NSString *value = sender.text ?: @"";
    setPrefObject(key, value);
    if ([key isEqualToString:kCurseForgeAPIKeyPrefKey]) {
        [CurseForgeService.shared setAPIKey:value];
    }
}

- (void)reloadTables {
    for (UITableView *tv in _pageTables) {
        [tv reloadData];
    }
}

- (void)showPickerForItem:(NSDictionary *)item fromTable:(UITableView *)table {
    NSArray *options = item[@"options"];
    if (![options isKindOfClass:[NSArray class]] || options.count == 0) {
        showDialog(@"No Options", @"No options available for this setting.");
        return;
    }
    id currentValueObj = getPrefObject(item[@"key"]) ?: item[@"default"];
    NSString *currentValue = [currentValueObj isKindOfClass:[NSString class]] ? currentValueObj : [currentValueObj description];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:item[@"label"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    if ([options.firstObject isKindOfClass:[NSDictionary class]]) {
        for (NSDictionary *opt in options) {
            NSString *key = opt[@"key"];
            NSString *name = opt[@"name"];
            BOOL isSelected = [currentValue isEqualToString:key];
            NSString *label = isSelected ? [NSString stringWithFormat:@"✓ %@", name] : name;
            [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                setPrefObject(item[@"key"], key);
                if ([item[@"key"] isEqualToString:@"general.orientation_lock"]) {
                    [self applyOrientationLock];
                } else if ([item[@"key"] isEqualToString:@"launcher.logo_style"]) {
                    applyLauncherAppIcon();
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"LauncherLogoDidChangeNotification" object:nil];
                }
                [self reloadTables];
            }]];
        }
    } else {
        for (NSString *opt in options) {
            if (![opt isKindOfClass:[NSString class]]) continue;
            NSString *display = opt;
            NSString *cap = [opt stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[opt substringToIndex:1] capitalizedString]];
            display = cap;
            BOOL isSelected = [currentValue isEqualToString:opt];
            NSString *label = isSelected ? [NSString stringWithFormat:@"✓ %@", display] : display;
            [sheet addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                setPrefObject(item[@"key"], opt);
                if ([item[@"key"] isEqualToString:@"launcher.theme"]) {
                    [self handleThemeChange:opt];
                }
                [self reloadTables];
            }]];
        }
    }
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = table;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(table.bounds), CGRectGetMidY(table.bounds), 0, 0);
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)handleThemeChange:(NSString *)themeValue {
    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    if ([themeValue isEqualToString:@"Dark"]) {
        style = UIUserInterfaceStyleDark;
    } else if ([themeValue isEqualToString:@"Light"]) {
        style = UIUserInterfaceStyleLight;
    }
    [ThemeManager.shared applyInterfaceStyle:style];
    [ThemeManager.shared applyThemeToAllWindows];
    [self reloadTables];
}

- (UIColor *)colorFromHexString:(NSString *)hex {
    hex = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (hex.length == 6) {
        unsigned int rgb = 0;
        [[NSScanner scannerWithString:hex] scanHexInt:&rgb];
        return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:1.0];
    }
    return ThemeManager.shared.accentColor;
}

#pragma mark - Export / Import Appearance

- (NSDictionary *)collectAppearanceData {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *colorKeys = @[@"amethyst_accent_color", @"amethyst_bg_color", @"amethyst_card_bg_color",
                           @"amethyst_sidebar_bg_color", @"amethyst_topbar_bg_color", @"amethyst_rightpanel_bg_color",
                           @"amethyst_text_color", @"amethyst_secondary_text_color"];

    NSMutableDictionary *dark = [NSMutableDictionary dictionary];
    NSMutableDictionary *light = [NSMutableDictionary dictionary];
    NSArray *modes = @[@YES, @NO];
    for (NSNumber *num in modes) {
        BOOL isDark = num.boolValue;
        NSString *suffix = isDark ? @"dark" : @"light";
        NSMutableDictionary *target = isDark ? dark : light;
        for (NSString *key in colorKeys) {
            NSString *modeKey = [key stringByAppendingFormat:@".%@", suffix];
            NSString *hex = [defaults stringForKey:modeKey];
            if (hex.length > 0) target[key] = hex;
        }
    }

    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"format"] = @"amethyst-appearance";
    data[@"version"] = @2;
    data[@"dark"] = dark;
    data[@"light"] = light;

    if ([defaults objectForKey:@"amethyst_bg_blur"]) data[@"amethyst_bg_blur"] = @([defaults floatForKey:@"amethyst_bg_blur"]);
    if ([defaults objectForKey:@"amethyst_ui_opacity"]) data[@"amethyst_ui_opacity"] = @([defaults floatForKey:@"amethyst_ui_opacity"]);

    data[@"launcher.theme"] = getPrefObject(@"launcher.theme") ?: @"System";
    data[@"general.liquid_glass"] = @(getPrefBool(@"general.liquid_glass"));

    UIImage *bg = ThemeManager.shared.backgroundImage;
    if (bg) {
        NSData *png = UIImagePNGRepresentation(bg);
        if (png) {
            data[@"amethyst_bg_image_png"] = [png base64EncodedStringWithOptions:0];
        }
    }
    return data;
}

- (void)exportAppearance {
    NSDictionary *data = [self collectAppearanceData];
    NSData *json = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:nil];
    if (!json) {
        showDialog(localize(@"Error", nil), localize(@"Could not create appearance file.", nil));
        return;
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"amethyst-appearance.json"];
    [json writeToFile:path atomically:YES];

    UIActivityViewController *avc = [[UIActivityViewController alloc]
        initWithActivityItems:@[[NSURL fileURLWithPath:path]]
        applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        avc.popoverPresentationController.sourceView = self.view;
        avc.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    [self presentViewController:avc animated:YES completion:nil];
}

- (void)importAppearance {
    if (@available(iOS 14, *)) {
        UTType *jsonType = [UTType typeWithFilenameExtension:@"json"];
        UTType *themeType = [UTType typeWithFilenameExtension:@"amethystappearance"];
        UIDocumentPickerViewController *doc = [[UIDocumentPickerViewController alloc]
            initForOpeningContentTypes:@[jsonType, themeType]];
        doc.delegate = self;
        doc.allowsMultipleSelection = NO;
        [self presentViewController:doc animated:YES completion:nil];
    } else {
        UIDocumentPickerViewController *doc = [[UIDocumentPickerViewController alloc]
            initWithDocumentTypes:@[@"public.json"] inMode:UIDocumentPickerModeImport];
        doc.delegate = self;
        [self presentViewController:doc animated:YES completion:nil];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [controller dismissViewControllerAnimated:YES completion:nil];
    NSURL *url = urls.firstObject;
    if (!url) return;

    BOOL accessing = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:nil];
    if (accessing) [url stopAccessingSecurityScopedResource];

    NSError *err = nil;
    id parsed = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&err] : nil;
    if (!data || !parsed) {
        NSLog(@"[ImportAppearance] read/parse failed for %@ (data=%lu bytes, err=%@, securityScoped=%d)", url, (unsigned long)data.length, err, accessing);
        showDialog(localize(@"Error", nil), localize(@"Could not read the appearance file.", nil));
        return;
    }
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[ImportAppearance] JSON root is not a dictionary: %@", [parsed class]);
        showDialog(localize(@"Error", nil), localize(@"Invalid appearance file.", nil));
        return;
    }
    [self applyAppearanceData:parsed];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)applyModeColors:(NSDictionary *)modeDict keys:(NSArray *)keys darkMode:(BOOL)dark theme:(ThemeManager *)theme {
    for (NSString *key in keys) {
        NSString *hex = modeDict[key];
        if (![hex isKindOfClass:[NSString class]] || hex.length == 0) continue;
        UIColor *color = [self colorFromHexString:hex];
        if ([key isEqualToString:@"amethyst_accent_color"]) {
            [theme applyAccentColor:color darkMode:dark];
        } else {
            [theme applyColor:color forKey:key darkMode:dark];
        }
    }
}

- (void)applyAppearanceData:(NSDictionary *)dict {
    ThemeManager *theme = ThemeManager.shared;

    NSArray *colorKeys = @[@"amethyst_accent_color", @"amethyst_bg_color", @"amethyst_card_bg_color",
                           @"amethyst_sidebar_bg_color", @"amethyst_topbar_bg_color", @"amethyst_rightpanel_bg_color",
                           @"amethyst_text_color", @"amethyst_secondary_text_color"];

    NSDictionary *dark = dict[@"dark"];
    NSDictionary *light = dict[@"light"];
    BOOL modeSplit = [dark isKindOfClass:[NSDictionary class]] && [light isKindOfClass:[NSDictionary class]];
    if (modeSplit) {
        [self applyModeColors:dark keys:colorKeys darkMode:YES theme:theme];
        [self applyModeColors:light keys:colorKeys darkMode:NO theme:theme];
    } else {
        for (NSString *key in colorKeys) {
            NSString *hex = dict[key];
            if (![hex isKindOfClass:[NSString class]] || hex.length == 0) continue;
            UIColor *color = [self colorFromHexString:hex];
            if ([key isEqualToString:@"amethyst_accent_color"]) {
                [theme applyAccentColor:color darkMode:YES];
                [theme applyAccentColor:color darkMode:NO];
            } else {
                [theme applyColor:color forKey:key darkMode:YES];
                [theme applyColor:color forKey:key darkMode:NO];
            }
        }
    }

    if ([dict objectForKey:@"amethyst_bg_blur"]) {
        theme.backgroundBlurIntensity = [dict[@"amethyst_bg_blur"] floatValue];
    }
    if ([dict objectForKey:@"amethyst_ui_opacity"]) {
        theme.uiOpacity = [dict[@"amethyst_ui_opacity"] floatValue];
    }

    NSString *imgB64 = dict[@"amethyst_bg_image_png"];
    if ([imgB64 isKindOfClass:[NSString class]] && imgB64.length > 0) {
        NSData *png = [[NSData alloc] initWithBase64EncodedString:imgB64 options:0];
        UIImage *image = [UIImage imageWithData:png];
        if (image) {
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *imgPath = [paths.firstObject stringByAppendingPathComponent:@"amethyst_bg.png"];
            [UIImagePNGRepresentation(image) writeToFile:imgPath atomically:YES];
            [[NSUserDefaults standardUserDefaults] setObject:imgPath forKey:@"amethyst_bg_image"];
            theme.backgroundImage = image;
        }
    }

    id themeVal = dict[@"launcher.theme"];
    if ([themeVal isKindOfClass:[NSString class]] && [themeVal length] > 0) {
        setPrefObject(@"launcher.theme", themeVal);
        [self handleThemeChange:themeVal];
    }

    id liquidGlass = dict[@"general.liquid_glass"];
    if ([liquidGlass isKindOfClass:[NSNumber class]]) {
        setPrefBool(@"general.liquid_glass", [liquidGlass boolValue]);
        [[NSNotificationCenter defaultCenter] postNotificationName:@"LiquidGlassDidChangeNotification" object:nil];
    }

    [theme applyThemeToAllWindows];
    [self reloadTables];
    showDialog(localize(@"Imported", nil), localize(@"Appearance settings imported.", nil));
}

- (void)showColorPickerForKey:(NSString *)key label:(NSString *)label {
    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    picker.delegate = self;
    picker.title = label;
    picker.supportsAlpha = NO;

    UIColor *current = [self colorForKey:key];
    if (CGColorGetAlpha(current.CGColor) > 0) {
        picker.selectedColor = current;
    }

    self.pendingColorPickCallback = ^(UIColor *color) {
        if ([key isEqualToString:@"amethyst_accent_color"]) {
            [ThemeManager.shared applyAccentColor:color];
        } else {
            [ThemeManager.shared applyColor:color forKey:key];
        }
        [self reloadTables];
    };

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)picker {
    if (self.pendingColorPickCallback) {
        self.pendingColorPickCallback(picker.selectedColor);
        self.pendingColorPickCallback = nil;
    }
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker {
    if (self.pendingColorPickCallback) {
        self.pendingColorPickCallback(picker.selectedColor);
        self.pendingColorPickCallback = nil;
    }
}

- (void)showImagePicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:localize(@"Background", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Choose Image from Library", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openPhotoLibraryWithFilter:[PHPickerFilter imagesFilter]];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Choose Video from Library", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openPhotoLibraryWithFilter:[PHPickerFilter videosFilter]];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Remove Background", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self removeBackgroundImage];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openPhotoLibraryWithFilter:(PHPickerFilter *)filter {
    if (@available(iOS 14, *)) {
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.filter = filter;
        config.selectionLimit = 1;
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.allowsEditing = NO;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;

    PHPickerResult *result = results.firstObject;
    NSItemProvider *provider = result.itemProvider;
    if ([provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
        [provider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier completionHandler:^(NSURL *url, NSError *error) {
            if (error || !url) return;
            NSString *destPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"amethyst_bg.mp4"];
            NSFileManager *fm = [NSFileManager defaultManager];
            [fm removeItemAtPath:destPath error:nil];
            BOOL access = [url startAccessingSecurityScopedResource];
            NSError *copyError = nil;
            BOOL ok = [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:&copyError];
            if (!ok) {
                NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&copyError];
                if (data) {
                    ok = [data writeToFile:destPath atomically:YES];
                }
            }
            if (access) [url stopAccessingSecurityScopedResource];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!ok) {
                    NSLog(@"[saveBackgroundVideo] copy failed in provider handler: %@ (source: %@)", copyError, url);
                    showDialog(localize(@"Error", nil), localize(@"Could not copy the video. Please try another file.", nil));
                    return;
                }
                ThemeManager.shared.backgroundVideoURL = [NSURL fileURLWithPath:destPath];
                [ThemeManager.shared broadcastThemeChange];
            });
        }];
    } else {
        [provider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            if (error || !object) return;
            UIImage *image = (UIImage *)object;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self saveBackgroundImage:image];
            });
        }];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (picker.mediaTypes.count > 1 || [picker.mediaTypes.firstObject isEqualToString:UTTypeMovie.identifier]) {
        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        if (videoURL) {
            [self saveBackgroundVideo:videoURL];
            return;
        }
    }
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) {
        [self saveBackgroundImage:image];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveBackgroundImage:(UIImage *)image {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsPath = paths.firstObject;
    NSString *imgPath = [docsPath stringByAppendingPathComponent:@"amethyst_bg.png"];
    [UIImagePNGRepresentation(image) writeToFile:imgPath atomically:YES];

    ThemeManager.shared.backgroundImage = image;
    [[NSUserDefaults standardUserDefaults] setObject:imgPath forKey:@"amethyst_bg_image"];
    [ThemeManager.shared broadcastThemeChange];
}

- (void)saveBackgroundVideo:(NSURL *)videoURL {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsPath = paths.firstObject;
    NSString *destPath = [docsPath stringByAppendingPathComponent:@"amethyst_bg.mp4"];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:destPath error:nil];

    BOOL access = [videoURL startAccessingSecurityScopedResource];
    NSError *error = nil;
    BOOL ok = [fm copyItemAtURL:videoURL toURL:[NSURL fileURLWithPath:destPath] error:&error];
    if (!ok) {
        NSLog(@"[saveBackgroundVideo] copyItemAtURL failed: %@ (source: %@)", error, videoURL);
        NSData *data = [NSData dataWithContentsOfURL:videoURL options:0 error:&error];
        if (data) {
            ok = [data writeToFile:destPath atomically:YES];
        }
        if (!ok) NSLog(@"[saveBackgroundVideo] data fallback failed: %@", error);
    }
    if (access) [videoURL stopAccessingSecurityScopedResource];

    if (!ok) {
        showDialog(localize(@"Error", nil), localize(@"Could not copy the video. Please try another file.", nil));
        return;
    }
    ThemeManager.shared.backgroundVideoURL = [NSURL fileURLWithPath:destPath];
    [ThemeManager.shared broadcastThemeChange];
}

- (void)removeBackgroundImage {
    ThemeManager.shared.backgroundImage = nil;
    ThemeManager.shared.backgroundVideoURL = nil;

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *imgPath = [paths.firstObject stringByAppendingPathComponent:@"amethyst_bg.png"];
    [[NSFileManager defaultManager] removeItemAtPath:imgPath error:nil];
    NSString *videoPath = [paths.firstObject stringByAppendingPathComponent:@"amethyst_bg.mp4"];
    [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];

    [ThemeManager.shared broadcastThemeChange];
}

- (void)resetAppearance {
    [ThemeManager.shared resetAppearance];
    [self reloadTables];
}

- (void)navigateToVC:(NSString *)vcName title:(NSString *)title {
    Class vcClass = NSClassFromString(vcName);
    if (!vcClass) {
        showDialog(localize(@"Not Available", nil), [NSString stringWithFormat:localize(@"%@ is not available in this build.", nil), title]);
        return;
    }
    UIViewController *vc = [[vcClass alloc] init];
    if (vc) {
        vc.title = title;

        if ([vc isKindOfClass:[CustomControlsViewController class]]) {
            CustomControlsViewController *ccvc = (CustomControlsViewController *)vc;
            ccvc.modalPresentationStyle = UIModalPresentationOverFullScreen;
            ccvc.setDefaultCtrl = ^(NSString *name){
                setPrefObject(@"control.default_ctrl", name);
            };
            ccvc.getDefaultCtrl = ^{
                return getPrefObject(@"control.default_ctrl");
            };
            [self presentViewController:ccvc animated:YES completion:nil];
            return;
        }

        if (self.navigationController) {
            [self.navigationController pushViewController:vc animated:YES];
        } else {
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
            nav.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:nav animated:YES completion:nil];
        }
    } else {
        showDialog(localize(@"Error", nil), [NSString stringWithFormat:localize(@"Failed to create %@.", nil), title]);
    }
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:localize(@"Reset Settings", nil) message:localize(@"Are you sure you want to reset all settings to default?", nil) preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:localize(@"Reset", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        loadPreferences(YES);
        loadPreferences(NO);
        [ThemeManager.shared applyInterfaceStyle:UIUserInterfaceStyleUnspecified];
        [ThemeManager.shared applyThemeToAllWindows];
        [self resetAppearance];
        [self buildSections];
        [self reloadTables];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
