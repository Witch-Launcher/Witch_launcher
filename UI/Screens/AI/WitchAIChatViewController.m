#import "WitchAIChatViewController.h"
#import "ThemeManager.h"
#import "WitchAIService.h"
#import "WitchLogReporter.h"
#import "CustomButton.h"
#import "utils.h"
#import <QuartzCore/QuartzCore.h>

@interface ChatMessage : NSObject
@property (nonatomic) BOOL isUser;
@property (nonatomic, copy) NSString *text;
@end
@implementation ChatMessage
@end

@interface WitchAIChatViewController () <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate>
@property (nonatomic, strong) CrashLogAnalyzerResult *analysis;
@property (nonatomic) int exitCode;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextView *inputView;
@property (nonatomic, strong) UIView *inputContainer;
@property (nonatomic, strong) UIStackView *buttonStack;
@property (nonatomic, strong) CustomButton *sendButton;
@property (nonatomic, strong) CustomButton *sendLogButton;
@property (nonatomic, strong) CustomButton *sendFileButton;
@property (nonatomic, strong) UIProgressView *uploadProgress;
@property (nonatomic, strong) NSMutableArray<ChatMessage*> *messages;
@property (nonatomic, strong) UIActivityIndicatorView *typingIndicator;
@property (nonatomic, strong) WitchLogUploadJob *deepJob;
// Unified AI busy state: counts concurrent ask/analyze requests sharing one
// spinner. Watchdog (aiSeq) guarantees the spinner can never stick forever
// if the network layer hangs without calling back.
@property (nonatomic) NSInteger activeAIRequests;
@property (nonatomic) NSUInteger aiSeq;
@end

@implementation WitchAIChatViewController

- (instancetype)initWithAnalysis:(CrashLogAnalyzerResult *)analysis exitCode:(int)code {
    self = [super init];
    if (self) {
        _analysis = analysis;
        _exitCode = code;
        _messages = [NSMutableArray array];
    }
    return self;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        _messages = [NSMutableArray array];
        _exitCode = -1;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = localize(@"AI Chat", nil);
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;
    [self setupViews];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateColors) name:ThemeDidChangeNotification object:nil];
    [self updateColors];
    // If opened from crash, auto add a system message with log context
    if (_analysis) {
        ChatMessage *sys = [ChatMessage new];
        sys.isUser = NO;
        sys.text = localize(@"ai.welcome_log", nil);
        [_messages addObject:sys];
        [self.tableView reloadData];
    }
}

- (void)setupViews {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.estimatedRowHeight = 60;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    [self.view addSubview:_tableView];

    _inputContainer = [[UIView alloc] init];
    _inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _inputContainer.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _inputContainer.layer.cornerRadius = 12;
    [self.view addSubview:_inputContainer];
    UIView *inputContainer = _inputContainer;

    _inputView = [[UITextView alloc] init];
    _inputView.translatesAutoresizingMaskIntoConstraints = NO;
    _inputView.font = [UIFont systemFontOfSize:15];
    _inputView.backgroundColor = [UIColor clearColor];
    _inputView.textColor = ThemeManager.shared.primaryTextColor;
    _inputView.layer.cornerRadius = 8;
    _inputView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    _inputView.delegate = self;
    _inputView.scrollEnabled = YES;
    [inputContainer addSubview:_inputView];

    // Vertical stack so hidden buttons collapse instead of leaving a dead
    // gap / pushing siblings outside the container (untappable).
    _buttonStack = [[UIStackView alloc] init];
    _buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    _buttonStack.axis = UILayoutConstraintAxisVertical;
    _buttonStack.spacing = 6;
    _buttonStack.alignment = UIStackViewAlignmentFill;
    _buttonStack.distribution = UIStackViewDistributionFill;
    [inputContainer addSubview:_buttonStack];

    _sendFileButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"ai.deep", nil)];
    _sendFileButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_sendFileButton addTarget:self action:@selector(actionSendFile) forControlEvents:UIControlEventTouchUpInside];
    [_buttonStack addArrangedSubview:_sendFileButton];

    _sendLogButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"ai.quick", nil)];
    _sendLogButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_sendLogButton addTarget:self action:@selector(actionSendLog) forControlEvents:UIControlEventTouchUpInside];
    [_buttonStack addArrangedSubview:_sendLogButton];

    _sendButton = [[CustomButton alloc] initWithStyle:CustomButtonStylePrimary title:localize(@"Send", nil)];
    _sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_sendButton addTarget:self action:@selector(actionSend) forControlEvents:UIControlEventTouchUpInside];
    [_buttonStack addArrangedSubview:_sendButton];

    // In empty chat (launcher, no crash) there is no log to analyse — hide
    // both log buttons so only Send remains. Stack collapses the gap.
    BOOL hasLog = (_analysis != nil && _analysis.latestLogPath.length > 0);
    _sendLogButton.hidden = (_analysis == nil);
    _sendFileButton.hidden = !hasLog;

    _typingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _typingIndicator.hidesWhenStopped = YES;
    _typingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_typingIndicator];

    _uploadProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _uploadProgress.translatesAutoresizingMaskIntoConstraints = NO;
    _uploadProgress.hidden = YES;
    [self.view addSubview:_uploadProgress];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [_tableView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:8],
        [_tableView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-8],
        [_tableView.bottomAnchor constraintEqualToAnchor:_uploadProgress.topAnchor constant:-4],

        [_uploadProgress.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [_uploadProgress.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [_uploadProgress.bottomAnchor constraintEqualToAnchor:inputContainer.topAnchor constant:-6],

        [inputContainer.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:8],
        [inputContainer.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-8],
        [inputContainer.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8],
        [inputContainer.heightAnchor constraintGreaterThanOrEqualToConstant:90],

        [_inputView.topAnchor constraintEqualToAnchor:inputContainer.topAnchor constant:8],
        [_inputView.leadingAnchor constraintEqualToAnchor:inputContainer.leadingAnchor constant:8],
        [_inputView.trailingAnchor constraintEqualToAnchor:_buttonStack.leadingAnchor constant:-8],
        [_inputView.bottomAnchor constraintEqualToAnchor:inputContainer.bottomAnchor constant:-8],
        [_inputView.heightAnchor constraintGreaterThanOrEqualToConstant:36],

        [_buttonStack.trailingAnchor constraintEqualToAnchor:inputContainer.trailingAnchor constant:-8],
        [_buttonStack.bottomAnchor constraintEqualToAnchor:inputContainer.bottomAnchor constant:-8],
        [_buttonStack.widthAnchor constraintEqualToConstant:86],
        [_buttonStack.topAnchor constraintGreaterThanOrEqualToAnchor:inputContainer.topAnchor constant:8],

        [_sendButton.heightAnchor constraintEqualToConstant:36],
        [_sendLogButton.heightAnchor constraintEqualToConstant:28],
        [_sendFileButton.heightAnchor constraintEqualToConstant:28],

        [_typingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_typingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

#pragma mark - Unified busy state + watchdog

- (void)setAIButtonsEnabled:(BOOL)enabled {
    _sendButton.enabled = enabled;
    _sendLogButton.enabled = enabled;
    // Deep button doubles as Cancel while uploading — keep it tappable then.
    BOOL deepUploading = (_deepJob && (_deepJob.state == WitchUploadStateUploading || _deepJob.state == WitchUploadStatePreparing));
    _sendFileButton.enabled = deepUploading ? YES : enabled;
    _sendButton.alpha = enabled ? 1.0 : 0.5;
    _sendLogButton.alpha = enabled ? 1.0 : 0.5;
    if (!deepUploading) _sendFileButton.alpha = enabled ? 1.0 : 0.5;
}

- (NSUInteger)beginAIRequest {
    _activeAIRequests += 1;
    _aiSeq += 1;
    NSUInteger seq = _aiSeq;
    [_typingIndicator startAnimating];
    [self setAIButtonsEnabled:NO];
    // Watchdog: never let the spinner stick forever if the network layer
    // hangs without calling back (user saw "xoay vòng vòng xong đứng").
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.aiSeq == seq && self.activeAIRequests > 0) {
            [self endAIRequestWithSeq:seq timeout:YES];
            ChatMessage *bot = [ChatMessage new]; bot.isUser = NO;
            bot.text = [NSString stringWithFormat:@"%@: %@", localize(@"Error", nil), localize(@"ai.timeout", nil)];
            [self.messages addObject:bot];
            [self.tableView reloadData];
            [self scrollToBottom];
        }
    });
    return seq;
}

- (void)endAIRequestWithSeq:(NSUInteger)seq timeout:(BOOL)isTimeout {
    if (_activeAIRequests > 0) _activeAIRequests -= 1;
    if (_activeAIRequests < 0) _activeAIRequests = 0;
    if (_activeAIRequests == 0) {
        [_typingIndicator stopAnimating];
        [self setAIButtonsEnabled:YES];
    }
    (void)seq; (void)isTimeout;
}

- (void)endAIRequestWithSeq:(NSUInteger)seq {
    [self endAIRequestWithSeq:seq timeout:NO];
}

- (void)shakeInputForEmpty {
    UIView *v = _inputContainer ?: _inputView;
    [v.layer removeAnimationForKey:@"witch.shake"];
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.values = @[@0, @-8, @8, @-6, @6, @0];
    shake.duration = 0.35;
    [v.layer addAnimation:shake forKey:@"witch.shake"];
}

- (void)updateColors {
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;
    _tableView.backgroundColor = [UIColor clearColor];
    _inputView.textColor = ThemeManager.shared.primaryTextColor;
    _inputContainer.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    [_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return _messages.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *kId = @"ChatCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kId];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
        cell.contentView.layer.cornerRadius = 12;
        cell.contentView.layer.masksToBounds = YES;
    }
    ChatMessage *m = _messages[indexPath.row];
    cell.textLabel.text = m.text;
    cell.contentView.backgroundColor = m.isUser ? [ThemeManager.shared.accentColor colorWithAlphaComponent:0.2] : ThemeManager.shared.cardBackgroundColor;
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    return cell;
}

- (void)actionSend {
    NSString *text = [_inputView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) {
        // Visible feedback instead of silent no-op ("bấm nút gửi không có gì xảy ra").
        [self shakeInputForEmpty];
        [_inputView becomeFirstResponder];
        return;
    }
    // Guard against double-tap while a request is already running: the
    // unified busy state disables buttons, but ignore the tap explicitly too.
    if (_activeAIRequests > 0) return;
    ChatMessage *userMsg = [ChatMessage new]; userMsg.isUser = YES; userMsg.text = text;
    [_messages addObject:userMsg];
    _inputView.text = @"";
    [self.tableView reloadData];
    [self scrollToBottom];
    NSUInteger seq = [self beginAIRequest];
    __weak typeof(self) weakSelf = self;
    [WitchAIService askWithPrompt:text lang:nil completion:^(NSString *answer, NSError *error) {
        // Service already hops to main; keep one hop here (no nested dispatch).
        typeof(self) strong = weakSelf;
        if (!strong) return;
        [strong endAIRequestWithSeq:seq];
        ChatMessage *bot = [ChatMessage new]; bot.isUser = NO;
        bot.text = error ? [NSString stringWithFormat:@"%@: %@", localize(@"Error", nil), error.localizedDescription] : answer;
        if (!bot.text.length) bot.text = [NSString stringWithFormat:@"%@: %@", localize(@"Error", nil), @"Empty response"];
        [strong.messages addObject:bot];
        [strong.tableView reloadData];
        [strong scrollToBottom];
    }];
}

- (void)actionSendLog {
    if (_activeAIRequests > 0) return;
    if (!_analysis) return;
    // Quick Analysis: bounded crash snapshot (metadata + modloader message +
    // error context + tail). Never the whole file — no main-thread IO.
    NSString *snapshot = _analysis.snapshot ?: _analysis.excerpt ?: @"";
    NSString *excerpt = snapshot.length > 5000 ? [snapshot substringToIndex:5000] : snapshot;
    if (excerpt.length == 0) {
        ChatMessage *bot = [ChatMessage new]; bot.isUser = NO; bot.text = localize(@"ai.no_log_file", nil);
        [_messages addObject:bot];
        [self.tableView reloadData];
        [self scrollToBottom];
        return;
    }
    ChatMessage *userMsg = [ChatMessage new]; userMsg.isUser = YES;
    userMsg.text = [NSString stringWithFormat:localize(@"ai.sent_quick", nil),
                    (unsigned long)snapshot.length, _exitCode];
    [_messages addObject:userMsg];
    [self.tableView reloadData];
    [self scrollToBottom];
    [self sendToAI:excerpt snapshot:snapshot];
}

- (void)actionSendFile {
    // Deep Analysis: tap toggles between start and cancel.
    if (_deepJob && (_deepJob.state == WitchUploadStateUploading || _deepJob.state == WitchUploadStatePreparing)) {
        [_deepJob cancel];
        _deepJob = nil;
        _uploadProgress.hidden = YES;
        [_sendFileButton setTitle:localize(@"ai.deep", nil) forState:UIControlStateNormal];
        [self setAIButtonsEnabled:YES];
        ChatMessage *bot = [ChatMessage new]; bot.isUser = NO; bot.text = localize(@"ai.deep_cancelled", nil);
        [_messages addObject:bot];
        [self.tableView reloadData];
        [self scrollToBottom];
        return;
    }
    if (_activeAIRequests > 0) return;
    if (!_analysis || !_analysis.latestLogPath) {
        ChatMessage *bot = [ChatMessage new]; bot.isUser = NO; bot.text = localize(@"ai.no_log_file", nil);
        [_messages addObject:bot];
        [self.tableView reloadData];
        [self scrollToBottom];
        return;
    }
    ChatMessage *userMsg = [ChatMessage new]; userMsg.isUser = YES;
    userMsg.text = [NSString stringWithFormat:localize(@"ai.deep_started", nil),
                    (unsigned long long)_analysis.totalBytes];
    [_messages addObject:userMsg];
    [self.tableView reloadData];
    [self scrollToBottom];
    _uploadProgress.hidden = NO;
    _uploadProgress.progress = 0;
    // Lock Quick/Send while Deep streams so spinners can't stack.
    _sendButton.enabled = NO; _sendLogButton.enabled = NO;
    _sendButton.alpha = 0.5; _sendLogButton.alpha = 0.5;
    __weak typeof(self) weakSelf = self;
    // Gzip + chunked resumable upload on background queues; UI gets progress.
    // Falls back to single-shot multipart on old servers.
    _deepJob = [WitchLogReporter sendDeepReportWithAnalysis:_analysis
                                                   exitCode:_exitCode
                                                       note:localize(@"ai.note_send_full", nil)
                                                   progress:^(double f) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.uploadProgress.progress = f;
            [weakSelf.sendFileButton setTitle:[NSString stringWithFormat:@"%d%%", (int)(f * 100)]
                                     forState:UIControlStateNormal];
        });
    } completion:^(BOOL success, NSString *serverID, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strong = weakSelf;
            if (!strong) return;
            strong.deepJob = nil;
            strong.uploadProgress.hidden = YES;
            [strong.sendFileButton setTitle:localize(@"ai.deep", nil) forState:UIControlStateNormal];
            // Deep finished (or failed) — unlock Quick/Send.
            strong.sendButton.enabled = YES; strong.sendLogButton.enabled = YES;
            strong.sendButton.alpha = 1.0; strong.sendLogButton.alpha = 1.0;
            strong.sendFileButton.alpha = 1.0;
            ChatMessage *bot = [ChatMessage new]; bot.isUser = NO;
            NSString *detail = error.localizedDescription ?: @"Unknown error";
            bot.text = success
                ? [NSString stringWithFormat:localize(@"ai.deep_done", nil), serverID ?: @""] 
                : [NSString stringWithFormat:localize(@"ai.send_discord_fail", nil), detail];
            [strong.messages addObject:bot];
            [strong.tableView reloadData];
            [strong scrollToBottom];
            if (success) {
                // Full log is now on the server for forensics; give AI the
                // snapshot immediately so the user gets an answer right away.
                NSString *snapshot = strong.analysis.snapshot ?: strong.analysis.excerpt ?: @"";
                NSString *excerpt = snapshot.length > 5000 ? [snapshot substringToIndex:5000] : snapshot;
                if (excerpt.length > 0) [strong sendToAI:excerpt snapshot:snapshot];
            }
        });
    }];
}

- (void)sendToAI:(NSString*)text snapshot:(NSString*)snapshot {
    if (_activeAIRequests > 0) {
        // Queue behind the running request instead of stacking spinners:
        // retry once the current one finishes.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.activeAIRequests == 0) [self sendToAI:text snapshot:snapshot];
        });
        return;
    }
    NSUInteger seq = [self beginAIRequest];
    int category = _analysis ? (int)_analysis.category : 2;
    NSDictionary *meta = @{@"exitCode": @(_exitCode), @"category": @(category)};
    // Both strings are bounded (snapshot ≤ ~500KB server-side, excerpt ≤ 5KB
    // here), so request building stays off the critical path.
    __weak typeof(self) weakSelf = self;
    [WitchAIService analyzeLogWithExcerpt:text fullLog:snapshot meta:meta completion:^(NSString *answer, NSError *error) {
        typeof(self) strong = weakSelf;
        if (!strong) return;
        [strong endAIRequestWithSeq:seq];
        ChatMessage *bot = [ChatMessage new]; bot.isUser = NO;
        bot.text = error ? [NSString stringWithFormat:@"%@: %@", localize(@"Error", nil), error.localizedDescription] : answer;
        if (!bot.text.length) bot.text = [NSString stringWithFormat:@"%@: %@", localize(@"Error", nil), @"Empty response"];
        [strong.messages addObject:bot];
        [strong.tableView reloadData];
        [strong scrollToBottom];
    }];
}

- (void)scrollToBottom {
    if (_messages.count == 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:_messages.count-1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_deepJob cancel];
}

@end
