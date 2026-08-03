//
//  scale.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/2/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "scale.h"
#import "MCPrefs.h"

float cursorScale() {
    float value;
    CGSGetCursorScale(CGSMainConnectionID(), &value);
    return value;
}

float defaultCursorScale() {
    // The listener is long-lived while the app writes this preference, so drop any
    // cached copy before reading or it keeps restoring a stale scale.
    CFPreferencesAppSynchronize((CFStringRef)kMCDomain);

    float scale = [MCDefault(MCPreferencesCursorScaleKey) floatValue];
    if (scale < .5 || scale > 16)
        scale = .5;
    return scale;
}

BOOL setCursorScale(float dbl) {
    if (dbl > 32) {
        MMLog("Not a good idea...");
        return NO;
    } else if (CGSSetCursorScale(CGSMainConnectionID(), dbl) == noErr) {
        MMLog("Successfully set cursor scale!");
        return YES;
    } else {
        MMLog("Somehow failed to set cursor scale!");
        return NO;
    }
}
