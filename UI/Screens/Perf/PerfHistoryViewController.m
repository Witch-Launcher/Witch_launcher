#import "PerfHistoryViewController.h"

#import "AmethystBlurView.h"
#import "AppSheet.h"
#import "ErrorPresenter.h"
#import "HapticManager.h"
#import "PerfChartViewController.h"
#import "PerfSessionStore.h"
#import "ThemeManager.h"
#import "utils.h"

#include <math.h>

@interface PerfHistoryViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) UITableView *tableView;
@property (nonatomic) UIView *actionBar;
@property (nonatomic) UIButton *chartsButton;
@property (nonatomic) UIButton *shareButton;
@property (nonatomic) UIButton *deleteButton;
@property (nonatomic) NSArray<PerfSession *> *sessions;
@property (nonatomic) NSMutableSet<NSString *> *selectedIds;
@property (nonatomic) BOOL selectMode;
@end

@implementation PerfHistoryViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.title = localize(@"perf.history.title", nil);
        _selectedIds = [NSMutableSet new];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    [AmethystBlurView installInView:self.view];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onTheme) name:ThemeDidChangeNotification object:nil];

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_tableView];

    _actionBar = [[UIView alloc] initWithFrame:CGRectZero];
    _actionBar.translatesAutoresizingMaskIntoConstraints = NO;
    _actionBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _actionBar.layer.cornerRadius = 14;
    _actionBar.layer.cornerCurve = kCACornerCurveContinuous;
    _actionBar.hidden = YES;
    [self.view addSubview:_actionBar];

    _chartsButton = [self makeActionButton:localize(@"perf.action.charts", nil) icon:@"chart.xyaxis.line" action:@selector(actionCharts)];
    _shareButton = [self makeActionButton:localize(@"perf.action.share", nil) icon:@"square.and.arrow.up" action:@selector(actionShare)];
    _deleteButton = [self makeActionButton:localize(@"perf.action.delete", nil) icon:@"trash" action:@selector(actionDelete)];
    _deleteButton.tintColor = ThemeManager.shared.errorColor;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_chartsButton, _shareButton, _deleteButton]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.distribution = UIStackViewDistributionFillEqually;
    [_actionBar addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_actionBar.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [_actionBar.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [_actionBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [_actionBar.heightAnchor constraintEqualToConstant:52],

        [stack.topAnchor constraintEqualToAnchor:_actionBar.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:_actionBar.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:_actionBar.leadingAnchor constant:8],
        [stack.trailingAnchor constraintEqualToAnchor:_actionBar.trailingAnchor constant:-8],
    ]];
}

- (UIButton *)makeActionButton:(NSString *)title icon:(NSString *)icon action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = ThemeManager.shared.accentColor;
    [button setTitle:title forState:UIControlStateNormal];
    [button setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 7, 0, 0);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSessions];
}

- (void)onTheme {
    self.view.backgroundColor = ThemeManager.shared.contentBackgroundColor;
    _actionBar.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    _chartsButton.tintColor = ThemeManager.shared.accentColor;
    _shareButton.tintColor = ThemeManager.shared.accentColor;
    _deleteButton.tintColor = ThemeManager.shared.errorColor;
    [_tableView reloadData];
}

#pragma mark - Data

- (void)reloadSessions {
    _sessions = [PerfSessionStore loadSessions];
    NSMutableSet *valid = [NSMutableSet new];
    for (PerfSession *session in _sessions) {
        if ([_selectedIds containsObject:session.sessionId]) {
            [valid addObject:session.sessionId];
        }
    }
    _selectedIds = valid;

    UILabel *emptyLabel = [UILabel new];
    emptyLabel.numberOfLines = 0;
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentCenter;
    style.lineSpacing = 6;
    NSString *emptyText = [NSString stringWithFormat:@"%@\n\n%@",
                           localize(@"perf.history.empty", nil),
                           localize(@"perf.history.empty_hint", nil)];
    emptyLabel.attributedText = [[NSAttributedString alloc] initWithString:emptyText attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightMedium],
        NSForegroundColorAttributeName: ThemeManager.shared.secondaryTextColor,
        NSParagraphStyleAttributeName: style,
    }];
    _tableView.backgroundView = _sessions.count == 0 ? emptyLabel : nil;

    if (_sessions.count == 0 && _selectMode) {
        [self setSelectMode:NO];
    }
    [self updateNavItems];
    [self updateActionBar];
    [_tableView reloadData];
}

- (NSArray<PerfSession *> *)selectedSessions {
    NSMutableArray *result = [NSMutableArray new];
    for (PerfSession *session in _sessions) {
        if ([_selectedIds containsObject:session.sessionId]) {
            [result addObject:session];
        }
    }
    return result;
}

- (void)updateActionBar {
    _actionBar.hidden = !_selectMode;
    if (!_selectMode) {
        return;
    }
    BOOL hasSelection = _selectedIds.count > 0;
    _chartsButton.enabled = hasSelection;
    _shareButton.enabled = hasSelection;
    _deleteButton.enabled = hasSelection;
    _chartsButton.alpha = hasSelection ? 1 : 0.4;
    _shareButton.alpha = hasSelection ? 1 : 0.4;
    _deleteButton.alpha = hasSelection ? 1 : 0.4;
    UIEdgeInsets insets = _tableView.contentInset;
    insets.bottom = 84;
    _tableView.contentInset = insets;
    _tableView.scrollIndicatorInsets = insets;
}

- (void)updateNavItems {
    UIBarButtonItem *selectItem = [[UIBarButtonItem alloc]
        initWithTitle:_selectMode ? localize(@"perf.done", nil) : localize(@"perf.select", nil)
        style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelectMode)];
    self.navigationItem.rightBarButtonItem = _sessions.count > 0 ? selectItem : nil;

    if (_selectMode) {
        BOOL allSelected = _sessions.count > 0 && _selectedIds.count == _sessions.count;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithTitle:allSelected ? localize(@"perf.deselect_all", nil) : localize(@"perf.select_all", nil)
            style:UIBarButtonItemStylePlain target:self action:@selector(toggleSelectAll)];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
}

#pragma mark - Selection

- (void)toggleSelectMode {
    [self setSelectMode:!_selectMode];
}

- (void)setSelectMode:(BOOL)mode {
    _selectMode = mode;
    if (!mode) {
        [_selectedIds removeAllObjects];
    }
    if (!mode) {
        UIEdgeInsets insets = _tableView.contentInset;
        insets.bottom = 0;
        _tableView.contentInset = insets;
        _tableView.scrollIndicatorInsets = insets;
    }
    [self updateNavItems];
    [self updateActionBar];
    [_tableView reloadData];
}

- (void)toggleSelectAll {
    if (_selectedIds.count == _sessions.count) {
        [_selectedIds removeAllObjects];
    } else {
        for (PerfSession *session in _sessions) {
            [_selectedIds addObject:session.sessionId];
        }
    }
    [self updateNavItems];
    [self updateActionBar];
    [_tableView reloadData];
}

- (void)toggleSelectionForSession:(PerfSession *)session {
    if ([_selectedIds containsObject:session.sessionId]) {
        [_selectedIds removeObject:session.sessionId];
    } else {
        [_selectedIds addObject:session.sessionId];
    }
    [HapticManager.shared play:HapticTypeLight];
    [self updateNavItems];
    [self updateActionBar];
    [_tableView reloadData];
}

#pragma mark - Actions

- (void)actionCharts {
    NSArray<PerfSession *> *selected = [self selectedSessions];
    if (selected.count == 0) {
        return;
    }
    PerfChartViewController *vc = [[PerfChartViewController alloc] initWithSessions:selected];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)actionShare {
    NSArray<PerfSession *> *selected = [self selectedSessions];
    if (selected.count == 0) {
        return;
    }
    NSMutableArray<NSURL *> *urls = [NSMutableArray new];
    for (PerfSession *session in selected) {
        for (NSString *name in @[@"samples.csv", @"meta.json"]) {
            NSString *path = [session.directory stringByAppendingPathComponent:name];
            if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
                [urls addObject:[NSURL fileURLWithPath:path]];
            }
        }
    }
    if (urls.count == 0) {
        [ErrorPresenter showWarning:localize(@"perf.share.empty_title", nil) message:nil];
        return;
    }
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil];
    avc.popoverPresentationController.sourceView = _shareButton;
    avc.popoverPresentationController.sourceRect = _shareButton.bounds;
    [self presentViewController:avc animated:YES completion:nil];
}

- (void)actionDelete {
    NSArray<PerfSession *> *selected = [self selectedSessions];
    if (selected.count == 0) {
        return;
    }
    NSString *message = [NSString stringWithFormat:localize(@"perf.delete.confirm", nil), (unsigned long)selected.count];
    [AppSheet showConfirmWithTitle:localize(@"perf.action.delete", nil)
                           message:message
                      confirmTitle:localize(@"perf.action.delete", nil)
                       destructive:YES
                         onConfirm:^{
        for (PerfSession *session in selected) {
            [PerfSessionStore deleteSession:session];
        }
        [ErrorPresenter showToast:localize(@"perf.delete.done", nil) success:YES];
        [self reloadSessions];
    }];
}

- (void)deleteSessionAtIndexPath:(NSIndexPath *)indexPath {
    PerfSession *session = _sessions[indexPath.row];
    NSString *message = [NSString stringWithFormat:localize(@"perf.delete.confirm", nil), (unsigned long)1];
    [AppSheet showConfirmWithTitle:localize(@"perf.action.delete", nil)
                           message:message
                      confirmTitle:localize(@"perf.action.delete", nil)
                       destructive:YES
                         onConfirm:^{
        [PerfSessionStore deleteSession:session];
        [self reloadSessions];
    }];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _sessions.count;
}

- (NSString *)detailTextForSession:(PerfSession *)session {
    NSMutableArray<NSString *> *parts = [NSMutableArray new];
    [parts addObject:[session localizedReason]];
    double fps = [session metricValue:@"fps" aggregate:@"avg"];
    if (!isnan(fps)) {
        [parts addObject:[NSString stringWithFormat:@"%.0f FPS", fps]];
    }
    double cpu = [session metricValue:@"cpu" aggregate:@"avg"];
    if (!isnan(cpu)) {
        [parts addObject:[NSString stringWithFormat:@"%.0f%% CPU", cpu]];
    }
    return [parts componentsJoinedByString:@" · "];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PerfSession *session = _sessions[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = ThemeManager.shared.cardBackgroundColor;
    cell.textLabel.textColor = ThemeManager.shared.primaryTextColor;
    cell.detailTextLabel.textColor = ThemeManager.shared.secondaryTextColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"dd/MM/yyyy HH:mm";
    });
    NSInteger totalSeconds = (NSInteger)llround(session.duration);
    NSString *duration = [NSString stringWithFormat:@"%ld:%02ld", (long)(totalSeconds / 60), (long)(totalSeconds % 60)];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@", [formatter stringFromDate:session.startedAt], duration];

    BOOL crashed = ![session.status isEqualToString:@"done"];
    if (crashed) {
        NSMutableAttributedString *detail = [[NSMutableAttributedString alloc] initWithString:[self detailTextForSession:session] attributes:@{
            NSFontAttributeName: cell.detailTextLabel.font,
            NSForegroundColorAttributeName: ThemeManager.shared.errorColor,
        }];
        cell.detailTextLabel.attributedText = detail;
    } else {
        cell.detailTextLabel.text = [self detailTextForSession:session];
    }

    if (_selectMode) {
        BOOL selected = [_selectedIds containsObject:session.sessionId];
        UIImage *icon = [UIImage systemImageNamed:selected ? @"checkmark.circle.fill" : @"circle"];
        UIImageView *check = [[UIImageView alloc] initWithImage:icon];
        check.tintColor = selected ? ThemeManager.shared.accentColor : ThemeManager.shared.separatorColor;
        cell.accessoryView = check;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    PerfSession *session = _sessions[indexPath.row];
    if (_selectMode) {
        [self toggleSelectionForSession:session];
        return;
    }
    PerfChartViewController *vc = [[PerfChartViewController alloc] initWithSessions:@[session]];
    [self.navigationController pushViewController:vc animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_selectMode) {
        return nil;
    }
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                         title:localize(@"perf.action.delete", nil)
                                                                       handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [self deleteSessionAtIndexPath:indexPath];
        completionHandler(YES);
    }];
    delete.image = [UIImage systemImageNamed:@"trash"];
    return [UISwipeActionsConfiguration configurationWithActions:@[delete]];
}

@end
