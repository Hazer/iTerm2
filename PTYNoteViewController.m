//
//  PTYNoteViewController.m
//  iTerm
//
//  Created by George Nachman on 11/18/13.
//
//

#import "PTYNoteViewController.h"
#import "IntervalTree.h"
#import "PTYNoteView.h"

NSString * const PTYNoteViewControllerShouldUpdatePosition = @"PTYNoteViewControllerShouldUpdatePosition";

@interface PTYNoteViewController ()
@property(nonatomic, retain) NSTextView *textView;
@property(nonatomic, retain) NSScrollView *scrollView;
@property(nonatomic, assign) BOOL watchForUpdate;
@end

@implementation PTYNoteViewController

@synthesize noteView = noteView_;
@synthesize textView = textView_;
@synthesize scrollView = scrollView_;
@synthesize anchor = anchor_;
@synthesize watchForUpdate = watchForUpdate_;
@synthesize entry;
@synthesize delegate;

- (void)dealloc {
    [noteView_ removeFromSuperview];
    noteView_.delegate = nil;
    [noteView_ release];
    [textView_ release];
    [scrollView_ release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)setNoteView:(PTYNoteView *)noteView {
    [noteView_ autorelease];
    noteView_ = [noteView retain];
    [self setView:noteView];
}

- (void)loadView {
    const CGFloat kWidth = 300;
    const CGFloat kHeight = 10;
    self.noteView = [[[PTYNoteView alloc] initWithFrame:NSMakeRect(0, 0, kWidth, kHeight)] autorelease];
    self.noteView.autoresizesSubviews = YES;
    self.noteView.delegate = self;
    NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
    shadow.shadowColor = [NSColor blackColor];
    shadow.shadowOffset = NSMakeSize(1, -1);
    shadow.shadowBlurRadius = 1.0;
    self.noteView.wantsLayer = YES;
    self.noteView.shadow = shadow;

    NSRect frame = NSMakeRect(0,
                              0,
                              kWidth,
                              kHeight);
    self.scrollView = [[[NSScrollView alloc] initWithFrame:frame] autorelease];
    scrollView_.drawsBackground = NO;
    scrollView_.hasVerticalScroller = YES;
    scrollView_.hasHorizontalScroller = NO;
    scrollView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.textView = [[[NSTextView alloc] initWithFrame:NSMakeRect(0,
                                                                  0,
                                                                  scrollView_.contentSize.width,
                                                                  scrollView_.contentSize.height)]
                     autorelease];
    textView_.allowsUndo = YES;
    textView_.minSize = scrollView_.frame.size;
    textView_.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    textView_.verticallyResizable = YES;
    textView_.horizontallyResizable = NO;
    textView_.autoresizingMask = NSViewWidthSizable;
    textView_.drawsBackground = NO;
    textView_.textContainer.containerSize = NSMakeSize(scrollView_.frame.size.width, FLT_MAX);
    textView_.textContainer.widthTracksTextView = YES;
    textView_.delegate = self;
    scrollView_.documentView = textView_;

    noteView_.contentView = scrollView_;
    [self sizeToFit];
}

- (void)beginEditing {
    [[textView_ window] makeFirstResponder:textView_];
}

- (void)setAnchor:(NSPoint)anchor {
    anchor_ = anchor;

    NSRect superViewFrame = noteView_.superview.frame;
    CGFloat xOffset = 0;
    if (anchor_.x + noteView_.frame.size.width > superViewFrame.size.width) {
        xOffset = anchor_.x + noteView_.frame.size.width - superViewFrame.size.width;
    }
    noteView_.tipEdge = kPTYNoteViewTipEdgeTop;
    NSSize size = [noteView_ sizeThatFitsContentView];
    noteView_.point = NSMakePoint(xOffset, 0);
    noteView_.frame = NSMakeRect(anchor_.x - xOffset,
                                 anchor_.y,
                                 size.width,
                                 size.height);

    CGFloat superViewMaxY = superViewFrame.origin.y + superViewFrame.size.height;
    if (NSMaxY(noteView_.frame) > superViewMaxY) {
        noteView_.tipEdge = kPTYNoteViewTipEdgeBottom;
        noteView_.point = NSMakePoint(xOffset, noteView_.frame.size.height - 1);
        noteView_.frame = NSMakeRect(anchor_.x - xOffset,
                                     anchor_.y - noteView_.frame.size.height,
                                     size.width,
                                     size.height);
    }

    [noteView_ layoutSubviews];
}

- (void)checkForUpdate {
    [self setAnchor:anchor_];
}

- (void)setWatchForUpdate:(BOOL)watchForUpdate {
    if (watchForUpdate == watchForUpdate_) {
        return;
    }
    watchForUpdate_ = watchForUpdate;
    if (watchForUpdate) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(checkForUpdate)
                                                     name:PTYNoteViewControllerShouldUpdatePosition
                                                   object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)finalizeToggleOfHide {
    [noteView_ setHidden:hidden_];
    noteView_.alphaValue = hidden_ ? 0 : 1;
}

- (void)setNoteHidden:(BOOL)hidden {
    if (hidden == hidden_) {
        return;
    }
    hidden_ = hidden;
    [noteView_ setHidden:NO];
    noteView_.animator.alphaValue = hidden ? 0 : 1;
    [self performSelector:@selector(finalizeToggleOfHide)
               withObject:nil
               afterDelay:[[NSAnimationContext currentContext] duration]];
}

- (BOOL)isEmpty {
    return [[textView_.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0;
}

- (void)setString:(NSString *)string {
    [self view];  // Ensure textView exists.
    textView_.string = string;
}

- (BOOL)isNoteHidden {
    return hidden_;
}

- (void)noteViewPositionNeedsUpdate {
    self.anchor = anchor_;
}

- (void)noteViewMoveBy:(NSSize)distance {
    anchor_.x += distance.width;
    anchor_.y += distance.height;
    [self setAnchor:anchor_];
}

- (void)noteSetAnchor:(NSPoint)point {
    anchor_ = point;
}

- (void)sizeToFit {
    NSLayoutManager *layoutManager = textView_.layoutManager;
    NSTextContainer *textContainer = textView_.textContainer;
    [layoutManager ensureLayoutForTextContainer:textContainer];
    NSRect usedRect = [layoutManager usedRectForTextContainer:textContainer];

    const CGFloat kMinTextViewWidth = 250;
    usedRect.size.width = MAX(usedRect.size.width, kMinTextViewWidth);

    NSSize scrollViewSize = [NSScrollView frameSizeForContentSize:usedRect.size
                                          horizontalScrollerClass:[[scrollView_ horizontalScroller] class]
                                            verticalScrollerClass:[[scrollView_ verticalScroller] class]
                                                       borderType:NSNoBorder
                                                      controlSize:NSRegularControlSize
                                                    scrollerStyle:[scrollView_ scrollerStyle]];
    scrollView_.frame = NSMakeRect(NSMinX(scrollView_.frame),
                                   NSMinY(scrollView_.frame),
                                   scrollViewSize.width,
                                   scrollViewSize.height);

    textView_.minSize = usedRect.size;
    textView_.frame = NSMakeRect(0, 0, usedRect.size.width, usedRect.size.height);

    [self setAnchor:anchor_];
}

- (void)makeFirstResponder {
    [self.view.window makeFirstResponder:textView_];
}

#pragma mark - PTYNoteViewDelegate

- (PTYNoteViewController *)noteViewController {
    return self;
}

- (void)killNote {
    [self.delegate noteDidRequestRemoval:self];
}

#pragma mark - NSControlTextEditingDelegate

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector {
    if (aSelector == @selector(cancelOperation:)) {
        [self.delegate noteDidEndEditing:self];
        return YES;
    }
    return NO;
}

@end
