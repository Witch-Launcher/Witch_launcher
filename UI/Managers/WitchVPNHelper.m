#import "WitchVPNHelper.h"
#import <UIKit/UIKit.h>
#import <arpa/inet.h>
#import <errno.h>
#import <fcntl.h>
#import <netinet/in.h>
#import <sys/select.h>
#import <sys/socket.h>
#import <unistd.h>

@implementation WitchVPNHelper

+ (BOOL)isInstalled {
    NSURL *url = [NSURL URLWithString:@"localdevvpn://"];
    return url && [UIApplication.sharedApplication canOpenURL:url];
}

+ (void)connect {
    NSURL *url = [NSURL URLWithString:@"localdevvpn://enable?scheme=witch"];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

+ (void)disconnect {
    NSURL *url = [NSURL URLWithString:@"localdevvpn://disable?scheme=witch"];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

+ (void)openAppStore {
    NSURL *url = [NSURL URLWithString:@"https://apps.apple.com/us/app/localdevvpn/id6755608044"];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

static BOOL WitchProbePort(uint16_t port, NSTimeInterval timeout) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return NO;

    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, "10.7.0.1", &addr.sin_addr);

    int rc = connect(fd, (struct sockaddr *)&addr, sizeof(addr));
    if (rc == 0) {
        close(fd);
        return YES;
    }
    if (errno != EINPROGRESS) {
        close(fd);
        return NO;
    }

    fd_set writeSet;
    FD_ZERO(&writeSet);
    FD_SET(fd, &writeSet);
    struct timeval tv;
    tv.tv_sec = (time_t)timeout;
    tv.tv_usec = (suseconds_t)((timeout - (NSTimeInterval)tv.tv_sec) * 1000000.0);
    rc = select(fd + 1, NULL, &writeSet, NULL, &tv);
    BOOL ok = NO;
    if (rc > 0 && FD_ISSET(fd, &writeSet)) {
        int error = 0;
        socklen_t len = sizeof(error);
        ok = getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &len) == 0 && error == 0;
    }
    close(fd);
    return ok;
}

+ (void)probeWithCompletion:(void (^)(BOOL))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        BOOL reachable = WitchProbePort(62078, 0.6) || WitchProbePort(49152, 0.6);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(reachable);
        });
    });
}

@end
