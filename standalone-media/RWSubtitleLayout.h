#pragma once
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <stdbool.h>
// Measured text, not a fixed three-line box. Keep the entire bounded caption
// inside the screen and above transport/next-episode controls when visible.
static inline CGRect RWSubtitleFrame(CGSize screen, CGSize text, CGFloat pictureBottom, bool controls) {
    if (screen.width<120 || screen.height<120 || text.width<=0 || text.height<=0) return CGRectZero;
    CGFloat width=fmin(screen.width-64,ceil(text.width)+24);
    CGFloat height=fmin(screen.height*.35,ceil(text.height)+12);
    CGFloat bottom=fmin(screen.height-(controls?205:32),pictureBottom-16);
    bottom=fmax(64,bottom);height=fmin(height,fmax(0,bottom-64));
    return CGRectMake(floor((screen.width-width)/2),floor(bottom-height),width,height);
}
