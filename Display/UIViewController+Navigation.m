#import "UIViewController+Navigation.h"

#import "RuntimeUtils.h"
#import <objc/runtime.h>

#import "NSWeakReference.h"

static const void *UIViewControllerIgnoreAppearanceMethodInvocationsKey = &UIViewControllerIgnoreAppearanceMethodInvocationsKey;
static const void *UIViewControllerNavigationControllerKey = &UIViewControllerNavigationControllerKey;
static const void *UIViewControllerPresentingViewControllerKey = &UIViewControllerPresentingViewControllerKey;

static bool notyfyingShiftState = false;

@interface UIKeyboardImpl_65087dc8: UIView

@end

@implementation UIKeyboardImpl_65087dc8

- (void)notifyShiftState {
    static void (*impl)(id, SEL) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method m = class_getInstanceMethod([UIKeyboardImpl_65087dc8 class], @selector(notifyShiftState));
        impl = (typeof(impl))method_getImplementation(m);
    });
    if (impl) {
        notyfyingShiftState = true;
        impl(self, @selector(notifyShiftState));
        notyfyingShiftState = false;
    }
}

@end

@interface UIInputWindowController_65087dc8: UIViewController

@end

@implementation UIInputWindowController_65087dc8

- (void)updateViewConstraints {
    static void (*impl)(id, SEL) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method m = class_getInstanceMethod([UIInputWindowController_65087dc8 class], @selector(updateViewConstraints));
        impl = (typeof(impl))method_getImplementation(m);
    });
    if (impl) {
        if (!notyfyingShiftState) {
            impl(self, @selector(updateViewConstraints));
        }
    }
}

@end

@implementation UIViewController (Navigation)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewWillAppear:) newSelector:@selector(_65087dc8_viewWillAppear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewDidAppear:) newSelector:@selector(_65087dc8_viewDidAppear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewWillDisappear:) newSelector:@selector(_65087dc8_viewWillDisappear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(viewDidDisappear:) newSelector:@selector(_65087dc8_viewDidDisappear:)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(navigationController) newSelector:@selector(_65087dc8_navigationController)];
        [RuntimeUtils swizzleInstanceMethodOfClass:[UIViewController class] currentSelector:@selector(presentingViewController) newSelector:@selector(_65087dc8_presentingViewController)];
        
        //[RuntimeUtils swizzleInstanceMethodOfClass:NSClassFromString(@"UIKeyboardImpl") currentSelector:@selector(notifyShiftState) withAnotherClass:[UIKeyboardImpl_65087dc8 class] newSelector:@selector(notifyShiftState)];
        //[RuntimeUtils swizzleInstanceMethodOfClass:NSClassFromString(@"UIInputWindowController") currentSelector:@selector(updateViewConstraints) withAnotherClass:[UIInputWindowController_65087dc8 class] newSelector:@selector(updateViewConstraints)];
    });
}

- (void)setIgnoreAppearanceMethodInvocations:(BOOL)ignoreAppearanceMethodInvocations
{
    [self setAssociatedObject:@(ignoreAppearanceMethodInvocations) forKey:UIViewControllerIgnoreAppearanceMethodInvocationsKey];
}

- (BOOL)ignoreAppearanceMethodInvocations
{
    return [[self associatedObjectForKey:UIViewControllerIgnoreAppearanceMethodInvocationsKey] boolValue];
}

- (void)_65087dc8_viewWillAppear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewWillAppear:animated];
}

- (void)_65087dc8_viewDidAppear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewDidAppear:animated];
}

- (void)_65087dc8_viewWillDisappear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewWillDisappear:animated];
}

- (void)_65087dc8_viewDidDisappear:(BOOL)animated
{
    if (![self ignoreAppearanceMethodInvocations])
        [self _65087dc8_viewDidDisappear:animated];
}

- (void)navigation_setNavigationController:(UINavigationController * _Nullable)navigationControlller {
    [self setAssociatedObject:[[NSWeakReference alloc] initWithValue:navigationControlller] forKey:UIViewControllerNavigationControllerKey];
}

- (void)navigation_setPresentingViewController:(UIViewController * _Nullable)presentingViewController {
    [self setAssociatedObject:[[NSWeakReference alloc] initWithValue:presentingViewController] forKey:UIViewControllerPresentingViewControllerKey];
}

- (UINavigationController *)_65087dc8_navigationController {
    UINavigationController *navigationController = self._65087dc8_navigationController;
    if (navigationController != nil) {
        return navigationController;
    }
    
    navigationController = self.parentViewController.navigationController;
    if (navigationController != nil) {
        return navigationController;
    }
    
    return ((NSWeakReference *)[self associatedObjectForKey:UIViewControllerNavigationControllerKey]).value;
}

- (UIViewController *)_65087dc8_presentingViewController {
    UINavigationController *navigationController = self.navigationController;
    if (navigationController.presentingViewController != nil) {
        return navigationController.presentingViewController;
    }
    
    return ((NSWeakReference *)[self associatedObjectForKey:UIViewControllerPresentingViewControllerKey]).value;
}

@end

static NSString *TGEncodeText(NSString *string, int key)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < (int)[string length]; i++)
    {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

void applyKeyboardAutocorrection() {
    static Class keyboardClass = NULL;
    static SEL currentInstanceSelector = NULL;
    static SEL applyVariantSelector = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyboardClass = NSClassFromString(TGEncodeText(@"VJLfzcpbse", -1));
        
        currentInstanceSelector = NSSelectorFromString(TGEncodeText(@"bdujwfLfzcpbse", -1));
        applyVariantSelector = NSSelectorFromString(TGEncodeText(@"bddfquBvupdpssfdujpo", -1));
    });
    
    if ([keyboardClass respondsToSelector:currentInstanceSelector])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id currentInstance = [keyboardClass performSelector:currentInstanceSelector];
        if ([currentInstance respondsToSelector:applyVariantSelector])
            [currentInstance performSelector:applyVariantSelector];
#pragma clang diagnostic pop
    }
}
