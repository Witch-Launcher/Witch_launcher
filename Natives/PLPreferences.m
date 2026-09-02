#import "LauncherPreferences.h"
#import "PLPreferences.h"
#import "UIKit+hook.h"
#import "config.h"
#import "utils.h"
#import "ZinkConfig.h"

@interface PLPreferences()
@end

@implementation PLPreferences

+ (id)defaultPrefForGlobal:(BOOL)global {
    // Preferences that can be isolated
    NSMutableDictionary<NSString *, NSMutableDictionary *> *defaults = @{
        @"general": @{
            @"check_sha": @YES,
            @"cosmetica": @YES,
            @"debug_logging": @(!CONFIG_RELEASE),
            @"liquid_glass": @NO,
            @"widget_menu": @NO,
            @"widget_show_fps": @NO,
            @"widget_show_cpu": @NO,
            @"widget_show_gpu": @NO,
            @"widget_show_temp": @NO,
            @"widget_temp_unit": @"c",
            @"widget_show_batt": @NO,
            @"widget_show_fgfps": @NO,
            @"widget_show_clock": @NO,
            @"widget_show_lowpower": @NO,
            @"widget_bg_opacity": @(0),
            @"widget_ram_style": @"none",
            @"widget_cpu_style": @"percent",
            @"widget_scale": @(100),
            @"widget_position": @"",
        }.mutableCopy,
        @"video": @{ // Video & Audio
            @"renderer": @"auto",
            @"resolution": @(100),
            @"max_framerate": @YES,
            @"performance_hud": @NO,
            @"frame_generation": @NO,
            @"framegen_mode": @"motion_adaptive",
            @"framegen_target_fps": @(60),
            @"framegen_fg2_submode": @"interp",
            @"fullscreen_airplay": @YES,
            @"silence_other_audio": @NO,
            @"silence_with_switch": @NO,
            @"allow_microphone": @NO,
            @"microphone_source": @"auto"
        }.mutableCopy,
        @"control": @{
            @"default_ctrl": @"default.json",
            @"control_safe_area": UIApplication.sharedApplication ? NSStringFromUIEdgeInsets(getDefaultSafeArea()) : @"",
            @"default_gamepad_ctrl": @"default.json",
            @"controller_type": @"xbox",
            @"hardware_hide": @YES,
            @"recording_hide": @YES,
            @"gesture_mouse": @YES,
            @"gesture_hotbar": @YES,
            @"disable_haptics": @NO,
            @"slideable_hotbar": @NO,
            @"press_duration": @(400),
            @"button_scale": @(100),
            @"mouse_scale": @(100),
            @"mouse_speed": @(100),
            @"virtmouse_enable": @NO,
            @"virtmouse_cursor": @"default",
            @"gyroscope_enable": @NO,
            @"gyroscope_invert_x_axis": @NO,
            @"gyroscope_sensitivity": @(100),
            @"gamepad_sensitivity": @(100),
            @"cursor_types_enabled": @YES,
            @"cursortype_normal_enabled": @YES,
            @"cursortype_normal_cursor": @"default",
            @"cursortype_link_enabled": @YES,
            @"cursortype_link_cursor": @"default",
            @"cursortype_text_enabled": @YES,
            @"cursortype_text_cursor": @"default",
            @"cursortype_busy_enabled": @YES,
            @"cursortype_busy_cursor": @"default",
            @"cursortype_working_enabled": @YES,
            @"cursortype_working_cursor": @"default",
            @"cursortype_precision_enabled": @YES,
            @"cursortype_precision_cursor": @"default",
            @"cursortype_unavailable_enabled": @YES,
            @"cursortype_unavailable_cursor": @"default",
            @"cursortype_vresize_enabled": @YES,
            @"cursortype_vresize_cursor": @"default",
            @"cursortype_hresize_enabled": @YES,
            @"cursortype_hresize_cursor": @"default",
            @"cursortype_diagonal_enabled": @YES,
            @"cursortype_diagonal_cursor": @"default",
            @"cursortype_move_enabled": @YES,
            @"cursortype_move_cursor": @"default",
            @"cursortype_help_enabled": @YES,
            @"cursortype_help_cursor": @"default",
            @"cursortype_hidden_enabled": @YES,
            @"cursortype_hidden_cursor": @"default"
        }.mutableCopy,
        @"java": @{
            @"java_homes": @{
                @"0": @{
                    @"1_16_5_older": @"8",
                    @"1_17_newer": @"17",
                    @"execute_jar": @"8"
                }.mutableCopy,
                @"8": @"internal",
                @"17": @"internal",
                @"21": @"internal",
                @"25": @"internal"
            }.mutableCopy,
            @"java_args": @"",
            @"env_variables": @"",
            @"lwjgl_version": @"(auto)",
            @"auto_ram": @(!getEntitlementValue(@"com.apple.private.memorystatus")),
            @"allocated_memory": [NSNumber numberWithFloat:roundf((NSProcessInfo.processInfo.physicalMemory / 1048576) * 0.25)]
        }.mutableCopy,
        @"mobileglues": @{
            @"enable_angle": @NO,
            @"enable_no_error": @(0),
            @"enable_ext_timer_query": @YES,
            @"enable_ext_compute_shader": @NO,
            @"enable_ext_direct_state_access": @NO,
            @"max_glsl_cache_size": @(32),
            @"multidraw_mode": @(0),
            @"angle_depth_clear_fix_mode": @(0),
            @"custom_gl_version": @(0),
            @"fsr1_setting": @(0)
        }.mutableCopy,
        @"zink": @{
            @"optimization_level": @(-1),
            @"gl_override": @(0),
            @"enable_gl_thread": @YES,
            @"glsl_cache_size": @(32),
            @"api_features": @(0xFFFFFFFF)
        }.mutableCopy,
        @"witch": @{
            @"server_enabled": @YES,
            @"proxy_base_url": @"",
            @"proxy_token": @"",
            @"proxy_hmac": @"",
            @"curseforge_source": @"server",
            @"curseforge_own_key": @"",
            @"ai_enabled": @YES,
            @"ai_source": @"server",
            @"ai_own_key": @"",
            @"ai_own_base": @"",
            @"ai_own_model": @"",
            @"ai_language": @"auto"
        }.mutableCopy,
        @"internal": @{
            @"isolated": @NO,
            @"latest_version": [NSDictionary new]
        }.mutableCopy
    }.mutableCopy;

    if (global) {
        // Preferences that cannot be isolated
        NSDictionary *general = @{
            @"game_directory": @"default",
            @"orientation_lock": @"off"
        };
        [defaults[@"general"] addEntriesFromDictionary:general];
        defaults[@"debug"] = @{
            @"debug_always_attached_jit": @NO,
            @"debug_mirror_mapped_code_cache": @(-1),
            @"debug_force_txm": @NO,
            @"debug_skip_wait_jit": @NO,
            @"debug_hide_home_indicator": @NO,
            @"debug_ipad_ui": @(realUIIdiom == UIUserInterfaceIdiomPad),
            @"debug_auto_correction": @YES,
            @"debug_server_enabled": @NO,
            @"debug_server_port": @(9090),
            @"debug_server_token": @"",
            @"debug_server_localhost_only": @NO
        }.mutableCopy;
        defaults[@"launcher"] = @{
            @"language": @"en",
            @"theme": @"System",
            @"logo_style": (CONFIG_RELEASE ? @"purple" : @"dev")
        }.mutableCopy;
        defaults[@"curseforge"] = @{
            @"api_key": @""
        }.mutableCopy;
        defaults[@"warnings"] = @{
            @"local_warn": @YES
        }.mutableCopy;
        // TODO: isolate this or add account picker into profile editor(?)
        defaults[@"internal"][@"selected_account"] = @"";
        defaults[@"internal"][@"ely_client_token"] = @"";
    }

    return defaults;
}

+ (id)getPreference:(NSString *)key from:(NSDictionary *)pref {
    for (NSDictionary *section in pref.allValues) {
        if ([section isKindOfClass:NSDictionary.class] && section[key]) {
            return section[key];
        }
    }
    return nil;
}

+ (id)getOldLayoutPreference:(NSString *)key from:(NSDictionary *)pref {
    // Find preference in the root dictionary first
    if (pref[key]) {
        return pref[key];
    }
    // Find preference in subdictionaries
    id value = [self getPreference:key from:pref];
    if (!value) {
        NSLog(@"[PLPreferences] Migrator could not find preference %@", key);
    }
    return value;
}

- (id)initWithGlobalPath:(NSString *)path {
    self = [super init];
    self.globalPath = path;
    self.globalPref = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    [self saveGlobalPref];
    return self;
}

- (id)initWithAutomaticMigrator {
    self = [super init];
    self.globalPath = [@(getenv("POJAV_HOME")) stringByAppendingPathComponent:@"launcher_preferences_v2.plist"];
    NSMutableDictionary *pref = [NSMutableDictionary dictionaryWithContentsOfFile:self.globalPath];

    NSString *oldPath = [@(getenv("POJAV_HOME")) stringByAppendingPathComponent:@"launcher_preferences.plist"];
    NSMutableDictionary *oldPref = [NSMutableDictionary dictionaryWithContentsOfFile:oldPath];

    if (pref || !oldPref[@"env_vars"]) {
        // Initialize or load existing v2 layout
        self.globalPref = pref;
    } else {
        NSDebugLog(@"[PLPreferences] Migrating to %@", self.globalPath.lastPathComponent);
        // Perform migration from v1 layout
        self.globalPref = [NSMutableDictionary new];
        for (NSString *section in self.globalPref.allKeys) {
            for (NSString *key in self.globalPref[section].allKeys) {
                id value = [PLPreferences getOldLayoutPreference:key from:oldPref];
                if (value) {
                    self.globalPref[section][key] = value;
                }
            }
        }
    }

    [self saveGlobalPref];
    return self;
}

- (id)setDefaultsForPref:(NSMutableDictionary *)pref global:(BOOL)global {
    NSMutableDictionary<NSString *, NSMutableDictionary *> *defaults = [PLPreferences defaultPrefForGlobal:global];
    if (!pref) {
        NSLog(@"[PLPreferences] Initializing default values for %@ preferences", global ? @"global" : @"isolated");
        return defaults;
    }

    for (NSString *section in defaults.allKeys) {
        if (!pref[section]) {
            NSDebugLog(@"[PLPreferences] Set default values for section %@", section);
            pref[section] = defaults[section];
            continue;
        }
        for (NSString *key in defaults[section].allKeys) {
            if (pref[section][key]) continue;
            id value = defaults[section][key];
            NSDebugLog(@"[PLPreferences] Set default vaule: %@: %@", key, value);
            pref[section][key] = value;
        }
    }

    if (pref[@"java"] && pref[@"java"][@"allocated_memory"]) {
        float currentMem = [pref[@"java"][@"allocated_memory"] floatValue];
        if (currentMem < 256.0) {
            CGFloat autoRatio = getEntitlementValue(@"com.apple.private.memorystatus") ? 0.4 : 0.25;
            float correctMem = roundf((NSProcessInfo.processInfo.physicalMemory / 1048576) * autoRatio);
            NSLog(@"[PLPreferences] Migrated allocated_memory from %.0f to %.0f", currentMem, correctMem);
            pref[@"java"][@"allocated_memory"] = @(correctMem);
        }
    }

    return pref;
}

- (void)setGlobalPref:(NSMutableDictionary *)pref {
    _globalPref = [self setDefaultsForPref:pref global:YES];
}

- (void)setInstancePref:(NSMutableDictionary *)pref {
    _instancePref = [self setDefaultsForPref:pref global:NO];
}

- (void)toggleIsolationForced:(BOOL)force {
    NSMutableDictionary *instancePref = [NSMutableDictionary dictionaryWithContentsOfFile:self.instancePath];
    if (force || [instancePref[@"internal"][@"isolated"] boolValue]) {
        NSLog(@"[PLPreferences] Using isolated preferences from %@", self.instancePath.stringByResolvingSymlinksInPath);
        self.instancePref = instancePref;
        if (!instancePref) {
            // Copy preferences from the global one
            for (NSString *section in self.instancePref) {
                for (NSString *key in self.instancePref[section].allKeys) {
                    self.instancePref[section][key] = self.globalPref[section][key];
                }
            }
        }

        // Declare that itself is isolated
        self.instancePref[@"internal"][@"isolated"] = @YES;

        [self saveInstancePref];
    } else if (self.instancePref) {
        NSLog(@"[PLPreferences] Using global preferences");
        _instancePref = nil;
    }
}

- (id)getObject:(NSString *)key {
    id value = [self.instancePref valueForKeyPath:key];
    if (!value) {
        value = [self.globalPref valueForKeyPath:key];
    }
    if (!value) {
        NSLog(@"[PLPreferences] Getter could not find preference %@", key);
    }
    return value;
}

- (BOOL)setObject:(NSString *)key value:(id)value {
    if ([self.instancePref valueForKeyPath:key]) {
        [self.instancePref setValue:value forKeyPath:key];
        [self saveInstancePref];
        return YES;
    } else if ([self.globalPref valueForKeyPath:key]) {
        [self.globalPref setValue:value forKeyPath:key];
        [self saveGlobalPref];
        return YES;
    }
    // Key doesn't exist yet — create it in the correct section
    // Key path format: "section.keyname" (e.g. "video.framegen_mode")
    NSRange dotRange = [key rangeOfString:@"."];
    if (dotRange.location != NSNotFound) {
        NSString *section = [key substringToIndex:dotRange.location];
        NSString *keyName = [key substringFromIndex:dotRange.location + 1];
        NSMutableDictionary *target = self.instancePref ?: self.globalPref;
        if (target[section]) {
            target[section][keyName] = value;
            if (target == self.instancePref) {
                [self saveInstancePref];
            } else {
                [self saveGlobalPref];
            }
            NSLog(@"[PLPreferences] Created new preference %@ = %@", key, value);
            return YES;
        }
    }
    NSLog(@"[PLPreferences] Setter could not find preference %@", key);
    return NO;
}

- (void)reset {
    if (self.instancePref) {
        [NSFileManager.defaultManager removeItemAtPath:self.instancePath error:nil];
        [self toggleIsolationForced:YES];
        // Only reset isolated values
        return;
    }

    self.globalPref = nil;
    [self saveGlobalPref];
}

- (void)saveGlobalPref {
    [self.globalPref writeToFile:self.globalPath atomically:YES];
}

- (void)saveInstancePref {
    [self.instancePref writeToFile:self.instancePath atomically:YES];
}

@end
