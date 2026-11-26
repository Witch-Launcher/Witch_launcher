#import "CustomControlsViewController.h"
#import "customcontrols/ControlDrawer.h"
#import "customcontrols/ControlJoystick.h"
#import "customcontrols/ControlLayout.h"
#import "utils.h"

static NSMutableDictionary *DeepCopyProperties(NSMutableDictionary *properties) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:properties options:0 error:nil];
    if (data != nil) {
        id copy = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if ([copy isKindOfClass:NSMutableDictionary.class]) return copy;
    }
    return [properties mutableCopy];
}

// Returns the position of the object in the list, or 0 when it is not found.
static NSUInteger IndexOfIdenticalObject(NSArray *list, id object) {
    NSUInteger index = [list indexOfObjectIdenticalTo:object];
    return index == NSNotFound ? 0 : index;
}

@implementation CustomControlsViewController(UndoManager)

- (void)doAddButton:(ControlButton *)button atIndex:(NSNumber *)index {
    NSUndoManager *undo = self.undoManager;

    if ([button isKindOfClass:ControlSubButton.class]) {
        undo.actionName = localize(@"custom_controls.button_menu.add_subbutton", nil);

        [self.ctrlView addSubview:button];
        ControlDrawer *drawer = ((ControlSubButton *)button).parentDrawer;
        [drawer.buttons insertObject:button atIndex:index.intValue]; 
        [drawer.drawerData[@"buttonProperties"] insertObject:button.properties atIndex:index.intValue];
        [drawer syncButtons];
    } else if ([button isKindOfClass:ControlDrawer.class]) {
        undo.actionName = localize(@"custom_controls.control_menu.add_drawer", nil);

        for (ControlSubButton *subButton in ((ControlDrawer *)button).buttons) {
            [self.ctrlView addSubview:subButton];
        }
        [self.ctrlView.layoutDictionary[@"mDrawerDataList"] insertObject:((ControlDrawer *)button).drawerData atIndex:index.intValue];
        [self.ctrlView addSubview:button];
    } else if ([button isKindOfClass:ControlJoystick.class]) {
        undo.actionName = localize(@"custom_controls.control_menu.add_joystick", nil);
        [self.ctrlView.layoutDictionary[@"mJoystickDataList"] insertObject:button.properties atIndex:index.intValue];
        [self.ctrlView addSubview:button];
    } else {
        undo.actionName = localize(@"custom_controls.control_menu.add_button", nil);
        [self.ctrlView.layoutDictionary[@"mControlDataList"] insertObject:button.properties atIndex:index.intValue];
        [self.ctrlView addSubview:button];
    }

    [[undo prepareWithInvocationTarget:self] doRemoveButton:button];
    if (undo.isUndoing) {
        undo.actionName = localize(@"Remove", nil);
    }
}

- (void)doRemoveButton:(ControlButton *)button {
    NSNumber *index;
    // The buttons are compared by identity, as two of them can hold the very
    // same properties and would otherwise be mistaken for each other.
    if ([button isKindOfClass:ControlSubButton.class]) {
        ControlDrawer *parent = ((ControlSubButton *)button).parentDrawer;
        index = @(IndexOfIdenticalObject(parent.drawerData[@"buttonProperties"], button.properties));
        [parent.buttons removeObjectIdenticalTo:button];
        [parent.drawerData[@"buttonProperties"] removeObjectIdenticalTo:button.properties];
        [parent syncButtons];
    } else if ([button isKindOfClass:ControlDrawer.class]) {
        ControlDrawer *drawer = (ControlDrawer *)button;
        index = @(IndexOfIdenticalObject(self.ctrlView.layoutDictionary[@"mDrawerDataList"], drawer.drawerData));
        [drawer.buttons makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self.ctrlView.layoutDictionary[@"mDrawerDataList"] removeObjectIdenticalTo:drawer.drawerData];
    } else if ([button isKindOfClass:ControlJoystick.class]) {
        index = @(IndexOfIdenticalObject(self.ctrlView.layoutDictionary[@"mJoystickDataList"], button.properties));
        [self.ctrlView.layoutDictionary[@"mJoystickDataList"] removeObjectIdenticalTo:button.properties];
    } else {
        index = @(IndexOfIdenticalObject(self.ctrlView.layoutDictionary[@"mControlDataList"], button.properties));
        [self.ctrlView.layoutDictionary[@"mControlDataList"] removeObjectIdenticalTo:button.properties];
    }
    [button removeFromSuperview];
    self.resizeView.hidden = YES;

    NSUndoManager *undo = self.undoManager;
    [[undo prepareWithInvocationTarget:self] undoRemoveButton:button atIndex:index];
    if (!undo.isUndoing) {
        undo.actionName = localize(@"Remove", nil);
    }
}

- (void)undoRemoveButton:(ControlButton *)button atIndex:(NSNumber *)index {
    NSUndoManager *undo = self.undoManager;
    if (!undo.isUndoing) {
        undo.actionName = localize(@"Remove", nil);
    }
    [self doAddButton:button atIndex:index];
}

- (void)doMoveOrResizeButton:(ControlButton *)button from:(CGRect)from to:(CGRect)to
{
    NSUndoManager *undo = self.undoManager;
    [[undo prepareWithInvocationTarget:self] doMoveOrResizeButton:button from:to to:from];
    if (!undo.isUndoing) {
        if (CGSizeEqualToSize(from.size, to.size)) {
            undo.actionName = localize(@"Move", nil);
        } else {
            undo.actionName = localize(@"Resize", nil);
        }
    }

    [button snapAndAlignX:to.origin.x Y:to.origin.y];
    button.properties[@"width"] = @(to.size.width);
    button.properties[@"height"] = @(to.size.height);
    [button update];
    self.resizeView.frame = CGRectMake(CGRectGetMaxX(button.frame), CGRectGetMaxY(button.frame), self.resizeView.frame.size.width, self.resizeView.frame.size.height);
}

- (void)doUpdateButton:(ControlButton *)button from:(NSMutableDictionary *)from to:(NSMutableDictionary *)to
{
    NSUndoManager *undo = self.undoManager;
    [[undo prepareWithInvocationTarget:self] doUpdateButton:button from:to to:from];
    if (!undo.isUndoing) {
        undo.actionName = localize(@"Edit", nil);
    }

    for (NSString *key in to) {
        button.properties[key] = to[key];
    }

    @try {
        [button update];
    } @catch (NSException *exception) {
        button.properties[@"dynamicX"] = to[@"dynamicX"] = from[@"dynamicX"];
        button.properties[@"dynamicY"] = to[@"dynamicY"] = from[@"dynamicY"];
        @throw exception;
    }
}

- (void)doCopyButton:(ControlButton *)sourceButton {
    NSUndoManager *undo = self.undoManager;
    undo.actionName = localize(@"Copy", nil);

    if ([sourceButton isKindOfClass:[ControlSubButton class]]) {
        ControlSubButton *srcSub = (ControlSubButton *)sourceButton;
        ControlDrawer *parentDrawer = srcSub.parentDrawer;

        NSMutableDictionary *newProps = DeepCopyProperties(srcSub.properties);
        newProps[@"dynamicX"] = [NSString stringWithFormat:@"(%@) + ${margin}", srcSub.properties[@"dynamicX"]];
        newProps[@"dynamicY"] = [NSString stringWithFormat:@"(%@) + ${margin}", srcSub.properties[@"dynamicY"]];

        ControlSubButton *newButton = [ControlSubButton buttonWithProperties:newProps];
        newButton.parentDrawer = parentDrawer;

        NSUInteger index = IndexOfIdenticalObject(parentDrawer.buttons, sourceButton) + 1;
        [self doAddButton:newButton atIndex:@(index)];
        [newButton update];
        [parentDrawer syncButtons];

        [newButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showControlPopover:)]];
        [newButton addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onTouch:)]];

    } else if ([sourceButton isKindOfClass:[ControlDrawer class]]) {
        ControlDrawer *srcDrawer = (ControlDrawer *)sourceButton;

        NSMutableDictionary *newDrawerData = DeepCopyProperties(srcDrawer.drawerData);

        NSMutableDictionary *props = newDrawerData[@"properties"];
        props[@"dynamicX"] = [NSString stringWithFormat:@"(%@) + ${margin}", srcDrawer.properties[@"dynamicX"]];
        props[@"dynamicY"] = [NSString stringWithFormat:@"(%@) + ${margin}", srcDrawer.properties[@"dynamicY"]];

        ControlDrawer *newDrawer = [ControlDrawer buttonWithData:newDrawerData];
        newDrawer.areButtonsVisible = YES;

        NSUInteger index = IndexOfIdenticalObject(self.ctrlView.layoutDictionary[@"mDrawerDataList"], srcDrawer.drawerData) + 1;
        [self doAddButton:newDrawer atIndex:@(index)];
        [newDrawer update];

        [newDrawer addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showControlPopover:)]];
        [newDrawer addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onTouch:)]];

        for (int i = 0; i < [newDrawerData[@"buttonProperties"] count]; i++) {
            NSMutableDictionary *subProps = newDrawerData[@"buttonProperties"][i];
            ControlSubButton *subView = [ControlSubButton buttonWithProperties:subProps];
            subView.parentDrawer = newDrawer;
            [newDrawer addButton:subView];
            [self.ctrlView addSubview:subView];
            [subView update];

            [subView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showControlPopover:)]];
            [subView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onTouch:)]];
        }
        [newDrawer syncButtons];

    } else if ([sourceButton isKindOfClass:[ControlJoystick class]]) {
        NSMutableDictionary *newProps = DeepCopyProperties(sourceButton.properties);
        newProps[@"dynamicX"] = [NSString stringWithFormat:@"(%@) + ${margin}", sourceButton.properties[@"dynamicX"]];
        newProps[@"dynamicY"] = [NSString stringWithFormat:@"(%@) + ${margin}", sourceButton.properties[@"dynamicY"]];

        ControlJoystick *newButton = [ControlJoystick buttonWithProperties:newProps];

        NSUInteger index = IndexOfIdenticalObject(self.ctrlView.layoutDictionary[@"mJoystickDataList"], sourceButton.properties) + 1;
        [self doAddButton:newButton atIndex:@(index)];
        [newButton update];

        [newButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showControlPopover:)]];
        [newButton addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onTouch:)]];

    } else {
        NSMutableDictionary *newProps = DeepCopyProperties(sourceButton.properties);
        newProps[@"dynamicX"] = [NSString stringWithFormat:@"(%@) + ${margin}", sourceButton.properties[@"dynamicX"]];
        newProps[@"dynamicY"] = [NSString stringWithFormat:@"(%@) + ${margin}", sourceButton.properties[@"dynamicY"]];

        ControlButton *newButton = [ControlButton buttonWithProperties:newProps];

        NSUInteger index = IndexOfIdenticalObject(self.ctrlView.layoutDictionary[@"mControlDataList"], sourceButton.properties) + 1;
        [self doAddButton:newButton atIndex:@(index)];
        [newButton update];

        [newButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showControlPopover:)]];
        [newButton addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onTouch:)]];
    }
}

@end
