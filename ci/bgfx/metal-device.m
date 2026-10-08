#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            puts("No Metal device is available on this runner.");
        } else {
            printf("Metal device: %s\n", device.name.UTF8String);
        }
        puts("This is a device availability probe; bgfx Metal rendering is not verified by this job.");
    }
    return 0;
}
