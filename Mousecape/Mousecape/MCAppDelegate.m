//
//  MCAppDelegate.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCAppDelegate.h"
#import <Security/Security.h>
#import <ServiceManagement/ServiceManagement.h>
#import "MCCursorLibrary.h"
#import "create.h"
#import "MASPreferencesWindowController.h"
#import "MCGeneralPreferencesController.h"
#import "scale.h"

static NSString * const MCHelperIdentifier = @"com.alexzielenski.mousecloakhelper";

@interface MCAppDelegate () {
    MASPreferencesWindowController *_preferencesWindowController;
}
@property (readonly) MASPreferencesWindowController *preferencesWindowController;
- (void)configureHelperToolMenuItem;
- (void)ensureHelperToolEnabled;
- (void)showHelperApprovalPrompt;
@end

@implementation MCAppDelegate
@dynamic preferencesWindowController;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    self.libraryWindowController = [[MCLibraryWindowController alloc] initWithWindowNibName:@"Library"];
    [self.libraryWindowController loadWindow];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self ensureHelperToolEnabled];
    [self configureHelperToolMenuItem];
    [self.libraryWindowController showWindow:self];
    
    // Re-apply currently applied cape
    if (self.libraryWindowController.libraryViewController.libraryController.appliedCape != NULL) {
        [self.libraryWindowController.libraryViewController.libraryController applyCape:self.libraryWindowController.libraryViewController.libraryController.appliedCape];
    }

    setCursorScale(defaultCursorScale());
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    BOOL open = [filename.pathExtension.lowercaseString isEqualToString:@"cape"];
    NSURL *url = [NSURL fileURLWithPath:filename];
    if (open) {
        [self.libraryWindowController.libraryViewController.libraryController importCapeAtURL:url];
    }
    return open;
}

- (void)configureHelperToolMenuItem {
    SMAppService *service = [SMAppService loginItemServiceWithIdentifier:MCHelperIdentifier];
    BOOL registered = service.status == SMAppServiceStatusEnabled ||
                      service.status == SMAppServiceStatusRequiresApproval;

    [self.toggleHelperItem setTag:registered ? 1 : 0];
    [self.toggleHelperItem setTitle:registered ?
                    NSLocalizedString(@"Uninstall Helper Tool", "Uninstall Helper Tool Menu Item") :
                    NSLocalizedString(@"Install Helper Tool", "Install Helper Tool Menu Item")];
}

- (void)ensureHelperToolEnabled {
    id savedPreference = MCDefault(MCPreferencesHelperEnabledKey);
    BOOL helperEnabled = savedPreference == nil || [savedPreference boolValue];
    if (!helperEnabled) {
        return;
    }

    SMAppService *service = [SMAppService loginItemServiceWithIdentifier:MCHelperIdentifier];
    if (service.status == SMAppServiceStatusEnabled) {
        return;
    }
    if (service.status == SMAppServiceStatusRequiresApproval) {
        [self showHelperApprovalPrompt];
        return;
    }

    NSError *error = nil;
    if (![service registerAndReturnError:&error]) {
        if (service.status == SMAppServiceStatusRequiresApproval) {
            [self showHelperApprovalPrompt];
        } else {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NSLocalizedString(@"Mousecape Helper Could Not Be Enabled", nil);
            alert.informativeText = error.localizedDescription ?: NSLocalizedString(@"The helper could not be registered.", nil);
            [alert runModal];
        }
    } else if (service.status == SMAppServiceStatusRequiresApproval) {
        [self showHelperApprovalPrompt];
    }
}

- (void)showHelperApprovalPrompt {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Allow Mousecape to Run in the Background", nil);
    alert.informativeText = NSLocalizedString(@"Enable Mousecape in System Settings > General > Login Items so it can restore your cursor scale after login and wake.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Open Login Items", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Not Now", nil)];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [SMAppService openSystemSettingsLoginItems];
    }
}

- (IBAction)toggleInstall:(NSMenuItem *)sender {
    SMAppService *service = [SMAppService loginItemServiceWithIdentifier:MCHelperIdentifier];
    NSError *error = nil;
    BOOL success;

    if (self.toggleHelperItem.tag != 0) { // Uninstall
        success = [service unregisterAndReturnError:&error];
        if (success) {
            MCSetAppDefault(@NO, MCPreferencesHelperEnabledKey);
        }
    } else {
        success = [service registerAndReturnError:&error];
        if (success) {
            MCSetAppDefault(@YES, MCPreferencesHelperEnabledKey);
        }
    }
    
    // ServiceManagement.framework takes a while to actually register the job dictionary so if the return value is all good we
    // can be on our merry way
    if (success && service.status == SMAppServiceStatusRequiresApproval) {
        [self showHelperApprovalPrompt];
    } else if (success && self.toggleHelperItem.tag == 0) {
        // Successfully Installed
        [self.toggleHelperItem setTag: 1];
        [self.toggleHelperItem setTitle:NSLocalizedString(@"Uninstall Helper Tool", "Uninstall Helper Tool Menu Item")];
    
        NSRunAlertPanel(NSLocalizedString(@"Sucess", "Helper Tool Install Result Title Success"),
                        NSLocalizedString(@"The Mousecape helper was successfully installed", "Helper Tool Install Success Result useless description"),
                        NSLocalizedString(@"Sweet", "Helper Tool Install Result Gratitude 1"),
                        NSLocalizedString(@"Thanks", "Helper Tool Install Result Gratitude 2"), nil);
    } else if (success) {
        // Successfully Uninstalled
        [self.toggleHelperItem setTag: 0];
        [self.toggleHelperItem setTitle:NSLocalizedString(@"Install Helper Tool", "Install Helper Tool Menu Item")];
        
        NSRunAlertPanel(NSLocalizedString(@"Sucess", "Helper Tool Uninstall Result Title Success"),
                        NSLocalizedString(@"The Mousecape helper was successfully uninstalled", "Helper Tool Uninstall Success Result useless description"),
                        NSLocalizedString(@"Sweet", "Helper Tool Uninstall Result Gratitude 1"),
                        NSLocalizedString(@"Thanks", "Helper Tool Uninstall Result Gratitude 2"), nil);
    } else {
        NSString *message = error.localizedDescription ?: NSLocalizedString(@"The action did not complete successfully", "Helper Tool Result Useless Failure Description");
        if (service.status == SMAppServiceStatusRequiresApproval) {
            [self showHelperApprovalPrompt];
        } else {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NSLocalizedString(@"Failure", "Helper Tool Result Title Failure");
            alert.informativeText = message;
            [alert runModal];
        }
    }

    [self configureHelperToolMenuItem];
}

- (MASPreferencesWindowController *)preferencesWindowController {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSViewController *general = [[MCGeneralPreferencesController alloc] init];
        _preferencesWindowController = [[MASPreferencesWindowController alloc] initWithViewControllers:@[ general ] title:NSLocalizedString(@"Preferences", "Preferences Window Title")];
    });
    
    return _preferencesWindowController;
}

#pragma mark - Interface Actions

- (IBAction)restoreCape:(id)sender {
    [self.libraryWindowController.libraryViewController.libraryController restoreCape];
}

- (IBAction)convertCape:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes  = @[ @"MightyMouse" ];
    panel.title             = NSLocalizedString(@"Import", "MightyMouse Import Panel Title");
    panel.message           = NSLocalizedString(@"Choose a MightyMouse file to import", "MightyMouse Import Panel useless description");
    panel.prompt            = NSLocalizedString(@"Import", "MightyMouse Import Panel Prompt");
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
        NSString *name = panel.URL.lastPathComponent.stringByDeletingPathExtension;
        NSDictionary *metadata = @{
                                   @"name": name,
                                   @"version": @1.0,
                                   @"author": NSLocalizedString(@"Unknown", "MightyMouse Import Default Author"),
                                   @"identifier": [NSString stringWithFormat:@"local.import.%@.%f", name, [NSDate timeIntervalSinceReferenceDate]]
                                   };
        
        NSDictionary *cape = createCapeFromMightyMouse([NSDictionary dictionaryWithContentsOfURL:panel.URL], metadata);
        MCCursorLibrary *library = [MCCursorLibrary cursorLibraryWithDictionary:cape];
        [self.libraryWindowController.libraryViewController.libraryController importCape:library];
    }
}

- (IBAction)newDocument:(id)sender {
    [self.libraryWindowController.libraryViewController.libraryController importCape:[[MCCursorLibrary alloc] init]];
}

- (IBAction)openDocument:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes  = @[ @"cape" ];
    panel.title             = NSLocalizedString(@"Import", "Mousecape Import Title");
    panel.message           = NSLocalizedString(@"Choose a Mousecape to import", "Mousecape Import useless description");
    panel.prompt            = NSLocalizedString(@"Import", "Mousecape Import Prompt");
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
        [self.libraryWindowController.libraryViewController.libraryController importCapeAtURL:panel.URL];
    }
}

- (IBAction)showPreferences:(id)sender {
    [self.preferencesWindowController showWindow:sender];
}

- (IBAction)showAboutPanel:(id)sender {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSString *build = info[@"CFBundleVersion"];
    NSString *gitCommit = info[@"MCGitCommit"];
    NSString *displayBuild = gitCommit.length > 0 ? gitCommit : build;

    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionVersion: displayBuild
    }];
}

@end
