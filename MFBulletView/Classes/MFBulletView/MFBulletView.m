//
//  MFBulletView.m
//  MFBullteView
//
//  Created by Neal on 2022/8/15.
//

#import "MFBulletView.h"
#import "MFBulletViewProtocol.h"
#import "MFBulletViewDefaultItem.h"

@interface MFBulletView ()

/// 轨道
@property(atomic, strong) NSMutableArray <__kindof UIView *> *railList;

/// 轨道速度
@property(nonatomic, strong) NSMutableArray <NSNumber *> *railSpeedList;

/// 轨道速度
@property(nonatomic, strong) NSMutableArray <NSNumber *> *railOffsetList;

/// 空闲中的元素列表
@property(atomic, strong) NSMutableArray <__kindof UIView<MFBulletViewProtocol> *> *relaxElementList;

/// 工作中的元素列表
@property(atomic, strong) NSMutableArray <__kindof UIView<MFBulletViewProtocol> *> *workElementList;

/// 轨道高度
@property(nonatomic, assign) CGFloat railHeight;

/// 弹幕走完无需清除视图
@property(nonatomic, assign) BOOL shouldRemoveWhenEmpty;

/// 轨道数量
@property(nonatomic, assign) int railCount;

/// 轨道间隔
@property(nonatomic, assign) CGFloat railSpacing;

/// 计时器
@property(nonatomic, strong) CADisplayLink *timer;
@property(nonatomic, assign) BOOL didAddElement;

@property(nonatomic, weak) id<MFBulletViewProtocol> viewDelegate;

@end

@implementation MFBulletView

+ (__kindof MFBulletView *(^)(CGRect))initWithFrame {
    return ^__kindof MFBulletView *(CGRect rect) {
        __kindof MFBulletView *view = [[self alloc] initWithFrame:rect];
        return view;
    };
}

- (__kindof MFBulletView *(^)(__kindof UIView *))setSuperView {
    __weak typeof(self) weakSelf = self;
    return ^(__kindof UIView *view) {
        if (view) {
            [view addSubview:weakSelf];
        }
        return weakSelf;
    };
}


- (__kindof MFBulletView *(^)(CGFloat))setRailHeight {
    __weak typeof(self) weakSelf = self;
    return ^(CGFloat railHeight) {
        weakSelf.railHeight = railHeight;
        return weakSelf;
    };
}

- (__kindof MFBulletView *(^)(int))setRailCount {
    __weak typeof(self) weakSelf = self;
    return ^(int railCount) {
        weakSelf.railCount = railCount;
        return weakSelf;
    };
}

- (__kindof MFBulletView *(^)(CGFloat))setRailSpacing {
    __weak typeof(self) weakSelf = self;
    return ^(CGFloat railSpacing) {
        weakSelf.railSpacing = railSpacing;
        return weakSelf;
    };;
}

- (__kindof MFBulletView *(^)(NSArray <NSNumber *> *))setRailOffsetList {
    __weak typeof(self) weakSelf = self;
    return ^(NSArray <NSNumber *> *railOffsetList) {
        weakSelf.railOffsetList = railOffsetList.mutableCopy;
        return weakSelf;
    };
}

- (__kindof MFBulletView *(^)(NSArray <NSNumber *> *))setRailSpeedList {
    __weak typeof(self) weakSelf = self;
    return ^(NSArray <NSNumber *> *railSpeedList) {
        weakSelf.railSpeedList = railSpeedList.mutableCopy;
        return weakSelf;
    };
}

- (__kindof MFBulletView *(^)(NSArray <__kindof MFBulletModel *> *))setAddElements {
    __weak typeof(self) weakSelf = self;
    return ^(NSArray <__kindof MFBulletModel *> *elements) {
        [weakSelf addElements:elements];
        return weakSelf;
    };
}

- (__kindof MFBulletView *(^)(__kindof MFBulletModel *))setAddElement {
    __weak typeof(self) weakSelf = self;
    return ^(__kindof MFBulletModel *element) {
        [weakSelf addElement:element];
        return weakSelf;
    };
}

- (__kindof MFBulletView *(^)(MFBulletModel *, int))setAddElementWithCount {
    __weak typeof(self) weakSelf = self;
    return ^(MFBulletModel *element, int count) {
        [weakSelf addElement:element forCount:count];
        return weakSelf;
    };
}

/**
 * 设置视图上无弹幕时是否remove
 * @return 本体-链式语法调用
 */
- (__kindof MFBulletView *(^)(BOOL))setShouldRemoveWhenEmpty {
    __weak typeof(self) weakSelf = self;
    return ^(BOOL shouldRemove) {
        weakSelf.shouldRemoveWhenEmpty = shouldRemove;
        return weakSelf;
    };
}

/**
 * 设置代理 - 必须
 */
- (__kindof MFBulletView *(^)(id<MFBulletViewProtocol>))setViewDelegate {
    __weak typeof(self) weakSelf = self;
    return ^(id<MFBulletViewProtocol> delegate) {
        weakSelf.viewDelegate = delegate;
        return weakSelf;
    };
}

- (void)addElements:(NSArray<MFBulletModel *> *)elements {
    if (!elements) {return;}
    if (!elements.count) {return;}

    [elements enumerateObjectsUsingBlock:^(MFBulletModel * _Nonnull model, NSUInteger i, BOOL * _Nonnull stop0) {
        __block NSUInteger minIndex = 0;
        __block CGFloat minTrailing = 99999999;
        [self.railList enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop0) {
            __block CGFloat maxTrailing = obj.frame.size.width;
            if (obj.subviews.count < 1) {
                CGFloat offset = 0;
                if (self.railOffsetList.count > 0) {
                    NSNumber *offsetNum = self.railOffsetList[idx % self.railOffsetList.count];
                    offset = offsetNum.floatValue;
                }
                maxTrailing = maxTrailing + offset;
            }
            [obj.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull item, NSUInteger idx1, BOOL * _Nonnull stop1) {
                CGFloat trailing = item.frame.origin.x + item.frame.size.width;
                if (trailing > maxTrailing) {
                    maxTrailing = trailing;
                }
            }];
            if (maxTrailing < minTrailing) {
                minTrailing = maxTrailing;
                minIndex = idx;
            }
        }];
        __kindof UIView *rail = self.railList[minIndex];
        CGFloat railHeight = rail.frame.size.height;
        __kindof UIView<MFBulletItemProtocol> *item = [self safeGetElementFromElementListWithModel:model];
        CGFloat itemWidth = 0;
        CGFloat itemHeight = 0;
        if ([item respondsToSelector:@selector(itemSizeWithModel:)]) {
            CGSize itemSize = [item itemSizeWithModel:model];
            itemWidth = itemSize.width;
            itemHeight = itemSize.height;
        }
        CGFloat itemX = minTrailing + 35;
        CGFloat itemY = (railHeight - itemHeight) / 2.0;
        item.frame = CGRectMake(itemX, itemY, itemWidth, itemHeight);
        [item configureItem];
    }];
    self.didAddElement = YES;
    if (!_timer) {
        _timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(timerChanged)];
        [_timer addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
}

- (void)addElement:(MFBulletModel *)element {
    if (!element) {return;}
    [self addElements:@[element]];
}

- (void)addElement:(MFBulletModel *)element forCount:(int)count {
    if (!element) {return;}
    if (count < 1) {return;}
    NSMutableArray *elements = [NSMutableArray array];
    for (int i = 0; i < count; ++i) {
        [elements addObject:element];
    }
    [self addElements:elements];
}


- (void)configureSubviews {
    _railList = [NSMutableArray array];
    _railSpeedList = [NSMutableArray array];
    _railOffsetList = [NSMutableArray array];
    [_railSpeedList addObjectsFromArray:@[@(1), @(1)]];
    [_railOffsetList addObjectsFromArray:@[@(0), @(60)]];
    _relaxElementList = [NSMutableArray array];
    _workElementList = [NSMutableArray array];
    _railHeight = 28;
    _railSpacing = 16;
    self.railCount = 2;

}

- (void)setRailCount:(int)railCount {
    int newRailCount = railCount < 1 ? 1 : railCount;
    _railCount = railCount;

    [self.workElementList enumerateObjectsUsingBlock:^(__kindof UIView *obj, NSUInteger idx, BOOL *stop) {
        [obj removeFromSuperview];
    }];
    [self.relaxElementList addObjectsFromArray:self.workElementList];
    [self.workElementList removeAllObjects];
    [self.railList enumerateObjectsUsingBlock:^(__kindof UIView *obj, NSUInteger idx, BOOL *stop) {
        [obj.subviews enumerateObjectsUsingBlock:^(__kindof UIView *obj1, NSUInteger idx1, BOOL *stop1) {
            [obj1 removeFromSuperview];
        }];
        [obj removeFromSuperview];
    }];
    [self.railList removeAllObjects];

    for (int i = 0; i < newRailCount; ++i) {
        CGFloat railHeight = self.railHeight;
        CGFloat railSpacing = self.railSpacing;
        CGFloat top = (railHeight + railSpacing) * i;
        UIView *railView = [[UIView alloc] initWithFrame:CGRectMake(0, top, self.frame.size.width, railHeight)];
        [self addSubview:railView];
        railView.backgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0];
        [self.railList addObject:railView];

        NSMutableArray <__kindof UIView<MFBulletViewProtocol> *> *workList = [NSMutableArray array];
        [self.workElementList addObjectsFromArray:workList];
    }
}

- (void)timerChanged {
    for (int i = 0; i < self.railCount; ++i) {
        CGFloat speed = 1;
        if (self.railSpeedList.count) {
            NSNumber *speedNum = self.railSpeedList[i % self.railSpeedList.count];
            speed = speedNum.floatValue;
        }
        [self.railList enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj.subviews enumerateObjectsUsingBlock:^(__kindof UIView<MFBulletItemProtocol> * _Nonnull item, NSUInteger idx1, BOOL * _Nonnull stop1) {
                CGFloat itemSpeed = speed;
                if ([item respondsToSelector:@selector(bulletModel)]) {
                    __kindof MFBulletModel *bulletModel = [item bulletModel];
                    if ([bulletModel respondsToSelector:@selector(speed)]) {
                        if (bulletModel.speed > 0) {
                            itemSpeed = bulletModel.speed;
                        }
                    }
                }
                CGFloat left = item.frame.origin.x;
                CGFloat x = left - itemSpeed;
                
                item.frame = CGRectMake(x, item.frame.origin.y, item.frame.size.width, item.frame.size.height);
            }];
        }];
    }

    NSMutableArray *relaxList = [NSMutableArray array];
    NSMutableArray *workList = [NSMutableArray array];
    [self.workElementList enumerateObjectsUsingBlock:^(__kindof UIView<MFBulletViewProtocol> * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        CGFloat right = item.frame.origin.x + item.frame.size.width;
        if (right < -1) {
            [relaxList addObject:item];
        } else {
            [workList addObject:item];
        }
    }];
    
    if (relaxList.count <= 0) {
        return;
    }
    [relaxList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    [self.workElementList removeAllObjects];
    [self.workElementList addObjectsFromArray:workList];
    [self.relaxElementList addObjectsFromArray:relaxList];

    if (self.workElementList.count < 1) {
        [self emptyRailAction];
    }
}

- (void)emptyRailAction {
    if (!self.shouldRemoveWhenEmpty) {
        return;
    }
    if (!self.didAddElement) {
        return;
    }
    if (_timer) {
        [_timer invalidate];
        [_timer removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        _timer = nil;
    }
    [self.workElementList enumerateObjectsUsingBlock:^(__kindof UIView<MFBulletViewProtocol> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];

    [self.workElementList removeAllObjects];
    [self.railList enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull item, NSUInteger idx1, BOOL * _Nonnull stop1) {
            [obj removeFromSuperview];
        }];
        [obj removeFromSuperview];
    }];

    [self.railList removeAllObjects];
    [self.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    [self removeFromSuperview];
}

- (__kindof UIView<MFBulletItemProtocol> *)safeGetElementFromElementListWithModel:(__kindof MFBulletModel *)bulletModel {
    
    if (![self.viewDelegate respondsToSelector:@selector(itemClassWithModel:)]) {
        return [[MFBulletViewDefaultItem alloc] initWithFrame:CGRectZero];
    }
    
    Class itemClass = [self.viewDelegate itemClassWithModel:bulletModel];
    __block int itemIndex = -1;
    __kindof UIView<MFBulletItemProtocol> *item;
    if (self.relaxElementList.count < 1) {
        item = [[itemClass alloc] init];
        [self.workElementList addObject:item];
        return item;
    }
    [self.relaxElementList enumerateObjectsUsingBlock:^(__kindof UIView<MFBulletViewProtocol> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:itemClass]) {
            itemIndex = [@(idx) intValue];
        }
    }];
    if (itemIndex < 0) {
        item = [[itemClass alloc] init];
        [self.workElementList addObject:item];
        return item;
    }
    item = self.relaxElementList[itemIndex];
    [self.workElementList addObject:item];
    [self.relaxElementList removeObjectAtIndex:itemIndex];
    return item;

}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self configureSubviews];
    }
    return self;
}

- (void)dealloc {
    if (_timer) {
        [_timer invalidate];
        [_timer removeFromRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        _timer = nil;
    }
    self.viewDelegate = nil;
    NSLog(@" [%@ dealloc] ", NSStringFromClass(self.class));
}


@end
