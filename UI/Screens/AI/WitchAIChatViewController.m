#import "WitchAIChatViewController.h"
#import "ThemeManager.h"
#import "WitchAIService.h"
#import "WitchLogReporter.h"
#import "CustomButton.h"
#import "utils.h"

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
@property (nonatomic, strong) CustomButton *sendButton;
@property (nonatomic, strong) CustomButton *sendLogButton;
@property (nonatomic, strong) CustomButton *sendFileButton;
@property (nonatomic, strong) NSMutableArray<ChatMessage*> *messages;
@property (nonatomic, strong) UIActivityIndicatorView *typingIndicator;
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

    UIView *inputContainer = [[UIView alloc] init];
    inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    inputContainer.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    inputContainer.layer.cornerRadius = 12;
    [self.view addSubview:inputContainer];

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

    _sendButton = [[CustomButton alloc] initWithStyle:CustomButtonStylePrimary title:localize(@"Send", nil)];
    _sendButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_sendButton addTarget:self action:@selector(actionSend) forControlEvents:UIControlEventTouchUpInside];
    [inputContainer addSubview:_sendButton];

    _sendLogButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"ai.send_log", nil)];
    _sendLogButton.translatesAutoresizingMaskIntoConstraints = NO;
    _sendLogButton.hidden = (_analysis == nil);
    [_sendLogButton addTarget:self action:@selector(actionSendLog) forControlEvents:UIControlEventTouchUpInside];
    [inputContainer addSubview:_sendLogButton];

    _sendFileButton = [[CustomButton alloc] initWithStyle:CustomButtonStyleSecondary title:localize(@"ai.send_full_file", nil)];
    _sendFileButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_sendFileButton addTarget:self action:@selector(actionSendFile) forControlEvents:UIControlEventTouchUpInside];
    [inputContainer addSubview:_sendFileButton];

    _typingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _typingIndicator.hidesWhenStopped = YES;
    _typingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_typingIndicator];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [_tableView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:8],
        [_tableView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-8],
        [_tableView.bottomAnchor constraintEqualToAnchor:inputContainer.topAnchor constant:-8],

        [inputContainer.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:8],
        [inputContainer.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-8],
        [inputContainer.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8],
        [inputContainer.heightAnchor constraintGreaterThanOrEqualToConstant:90],

        [_inputView.topAnchor constraintEqualToAnchor:inputContainer.topAnchor constant:8],
        [_inputView.leadingAnchor constraintEqualToAnchor:inputContainer.leadingAnchor constant:8],
        [_inputView.trailingAnchor constraintEqualToAnchor:_sendButton.leadingAnchor constant:-8],
        [_inputView.bottomAnchor constraintEqualToAnchor:inputContainer.bottomAnchor constant:-8],
        [_inputView.heightAnchor constraintGreaterThanOrEqualToConstant:36],

        [_sendButton.trailingAnchor constraintEqualToAnchor:inputContainer.trailingAnchor constant:-8],
        [_sendButton.bottomAnchor constraintEqualToAnchor:inputContainer.bottomAnchor constant:-8],
        [_sendButton.widthAnchor constraintEqualToConstant:70],
        [_sendButton.heightAnchor constraintEqualToConstant:36],

        [_sendLogButton.leadingAnchor constraintEqualToAnchor:_sendButton.leadingAnchor],
        [_sendLogButton.trailingAnchor constraintEqualToAnchor:_sendButton.trailingAnchor],
        [_sendLogButton.bottomAnchor constraintEqualToAnchor:_sendButton.topAnchor constant:-6],
        [_sendLogButton.heightAnchor constraintEqualToConstant:28],

        [_sendFileButton.leadingAnchor constraintEqualToAnchor:_sendButton.leadingAnchor],
        [_sendFileButton.trailingAnchor constraintEqualToAnchor:_sendButton.trailingAnchor],
        [_sendFileButton.bottomAnchor constraintEqualToAnchor:_sendLogButton.topAnchor constant:-6],
        [_sendFileButton.heightAnchor constraintEqualToConstant:28],

        [_typingIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_typingIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)updateColors {
    self.view.backgroundColor = ThemeManager.shared.backgroundColor;
    _tableView.backgroundColor = [UIColor clearColor];
    _inputView.textColor = ThemeManager.shared.primaryTextColor;
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
    if (text.length == 0) return;
    ChatMessage *userMsg = [ChatMessage new]; userMsg.isUser = YES; userMsg.text = text;
    [_messages addObject:userMsg];
    _inputView.text = @"";
    [self.tableView reloadData];
    [self scrollToBottom];
    [self sendToAI:text isLog:NO];
}

- (void)actionSendLog {
    if (!_analysis) return;
    // Chỉ gửi đoạn ngắn (100 dòng) để AI dùng tool đọc thêm nếu cần — tiết kiệm quota, tránh đơ
    NSString *excerpt = _analysis.excerpt ?: @"";
    if (excerpt.length == 0) excerpt = [_analysis.fullLog substringToIndex:MIN(_analysis.fullLog.length, 5000)] ?: @"";
    // Giới hạn 5000 chars cho lần gửi đầu, AI sẽ dùng tool read_log để lấy thêm
    if (excerpt.length > 5000) excerpt = [excerpt substringToIndex:5000];
    ChatMessage *userMsg = [ChatMessage new]; userMsg.isUser = YES; userMsg.text = [NSString stringWithFormat:localize(@"ai.sent_excerpt", nil), (unsigned long)excerpt.length, _exitCode];
    [_messages addObject:userMsg];
    [self.tableView reloadData];
    [self scrollToBottom];
    [self sendToAI:excerpt isLog:YES];
}

- (void)actionSendFile {
    // Gửi cả file log + các file liên quan (crash-report, hs_err, .ips) lên Discord và cho AI
    NSString *fullLog = _analysis.fullLog ?: _analysis.excerpt ?: @"";
    NSString *latestPath = _analysis.latestLogPath ?: [NSString stringWithFormat:@"%s/latestlog.txt", getenv("POJAV_HOME")];
    if (fullLog.length == 0 && latestPath) {
        fullLog = [NSString stringWithContentsOfFile:latestPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
        if (!_analysis) {
            _analysis = [CrashLogAnalyzerResult new];
            _analysis.fullLog = fullLog;
            _analysis.excerpt = [fullLog length] > 10000 ? [fullLog substringFromIndex:fullLog.length-10000] : fullLog;
            _analysis.latestLogPath = latestPath;
        }
    }
    if (fullLog.length == 0) {
        ChatMessage *bot = [ChatMessage new]; bot.isUser = NO; bot.text = localize(@"ai.no_log_file", nil);
        [_messages addObject:bot];
        [self.tableView reloadData];
        [self scrollToBottom];
        return;
    }
    ChatMessage *userMsg = [ChatMessage new]; userMsg.isUser = YES;
    NSUInteger extra = (_analysis.crashReportPath?1:0) + (_analysis.hsErrPath?1:0);
    userMsg.text = [NSString stringWithFormat:localize(@"ai.sent_full_file", nil), (unsigned long)fullLog.length, (unsigned long)extra];
    [_messages addObject:userMsg];
    [self.tableView reloadData];
    [self scrollToBottom];
    // Gửi cho AI với full log (AI sẽ biết có các file crash/hs_err/.ips qua system prompt)
    [self sendToAI:fullLog isLog:YES];
    // Đồng thời gửi lên Discord dạng file đính kèm
    CrashLogAnalyzerResult *toSend = _analysis ?: [CrashLogAnalyzerResult new];
    if (!toSend.fullLog) toSend.fullLog = fullLog;
    [WitchLogReporter sendReportWithAnalysis:toSend exitCode:_exitCode note:localize(@"ai.note_send_full", nil) completion:^(BOOL success, NSString *logId, NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            ChatMessage *bot = [ChatMessage new]; bot.isUser = NO;
            bot.text = success ? [NSString stringWithFormat:localize(@"ai.sent_discord_ok", nil), logId ?: @""] : [NSString stringWithFormat:localize(@"ai.send_discord_fail", nil), error.localizedDescription];
            [self.messages addObject:bot];
            [self.tableView reloadData];
            [self scrollToBottom];
        });
    }];
}

- (void)sendToAI:(NSString*)text isLog:(BOOL)isLog {
    [_typingIndicator startAnimating];
    _sendButton.enabled = NO;
    if (isLog) {
        NSDictionary *meta = @{@"exitCode": @(_exitCode), @"category": @(_analysis.category)};
        [WitchAIService analyzeLogWithExcerpt:text fullLog:_analysis.fullLog meta:meta completion:^(NSString *answer, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_typingIndicator stopAnimating];
                self->_sendButton.enabled = YES;
                ChatMessage *bot = [ChatMessage new]; bot.isUser = NO;
                bot.text = error ? [NSString stringWithFormat:@"%@: %@", localize(@"Error", nil), error.localizedDescription] : answer;
                [self.messages addObject:bot];
                [self.tableView reloadData];
                [self scrollToBottom];
            });
        }];
    } else {
        [WitchAIService askWithPrompt:text lang:nil completion:^(NSString *answer, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_typingIndicator stopAnimating];
                self->_sendButton.enabled = YES;
                ChatMessage *bot = [ChatMessage new]; bot.isUser = NO;
                bot.text = error ? [NSString stringWithFormat:@"%@: %@", localize(@"Error", nil), error.localizedDescription] : answer;
                [self.messages addObject:bot];
                [self.tableView reloadData];
                [self scrollToBottom];
            });
        }];
    }
}

- (void)scrollToBottom {
    if (_messages.count == 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:_messages.count-1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

@end
