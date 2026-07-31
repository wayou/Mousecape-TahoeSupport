//
//  MCPrefs.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "MCPrefs.h"

NSString *MCPreferencesAppliedCursorKey          = @"MCAppliedCursor";
NSString *MCPreferencesAppliedClickActionKey     = @"MCLibraryClickAction";
NSString *MCPreferencesCursorScaleKey            = @"MCCursorScale";
NSString *MCPreferencesHelperEnabledKey          = @"MCHelperEnabled";
NSString *MCPreferencesDoubleActionKey           = @"MCDoubleAction";
NSString *MCPreferencesHandednessKey             = @"MCHandedness";
NSString *MCSuppressDeleteLibraryConfirmationKey = @"MCSuppressDeleteLibraryConfirmationKey";
NSString *MCSuppressDeleteCursorConfirmationKey  = @"MCSuppressDeleteCursorConfirmationKey";
id MCDefaultFor(NSString *key, NSString *user, NSString *host) {
    NSString *value = (NSString *)CFPreferencesCopyValue((CFStringRef)key, (CFStringRef)kMCDomain, (CFStringRef)user, (CFStringRef)host);
    return [value autorelease];
}

id MCDefault(NSString *key) {
    return [(id)CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)kMCDomain) autorelease];
}

void MCSetAppDefault(id value, NSString *key) {
    CFPreferencesSetAppValue((CFStringRef)key, (CFPropertyListRef)value, (CFStringRef)kMCDomain);
    CFPreferencesAppSynchronize((CFStringRef)kMCDomain);
}

void MCSetDefaultFor(id value, NSString *key, NSString *user, NSString *host) {
    CFPreferencesSetValue((CFStringRef)key, (CFPropertyListRef)value, (CFStringRef)kMCDomain, (CFStringRef)user, (CFStringRef)host);
    CFPreferencesSynchronize((CFStringRef)kMCDomain, (CFStringRef)user, (CFStringRef)host);
}
