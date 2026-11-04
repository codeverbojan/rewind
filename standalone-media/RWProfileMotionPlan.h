#import <Foundation/Foundation.h>
// Shared, bounded vector timeline used by native Core Animation and the local
// preview renderer. A frame is [seconds, x, y, scaleX, scaleY, radians, opacity].
NSDictionary *RWProfileMotionPlan(double width, double height, BOOL kids);
