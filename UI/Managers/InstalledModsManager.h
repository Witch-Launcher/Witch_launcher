#import <Foundation/Foundation.h>

extern NSString * const InstalledModsDidChangeNotification;

// Tracks which mods were installed through the launcher, per profile.
// Manifest lives at <modsDir>/installed_mods.json keyed by project_id:
//   { "<project_id>": { title, version_number, filename, installed_at } }
@interface InstalledModsManager : NSObject

@property (class, readonly) InstalledModsManager *shared;

- (NSDictionary *)infoForProjectId:(NSString *)projectId;
- (void)recordProjectId:(NSString *)projectId
                  title:(NSString *)title
          versionNumber:(NSString *)versionNumber
               filename:(NSString *)filename;
- (NSString *)modsDirForCurrentProfile;

@end
