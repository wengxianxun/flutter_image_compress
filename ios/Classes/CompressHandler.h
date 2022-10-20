//
// Created by cjl on 2018/9/8.
//

#import <Foundation/Foundation.h>


@interface CompressHandler : NSObject

+ (NSData *)compressSizeWithUIImage:(UIImage *)image minWidth:(int)minWidth minHeight:(int)minHeight format:(int)format;

+ (NSData *)compressWithData:(NSData *)data minWidth:(int)minWidth minHeight:(int)minHeight quality:(int)quality
                      rotate:(int)rotate format:(int)format compressSize:(int)compressSize;

+ (NSData *)compressWithUIImage:(UIImage *)image quality:(int)quality
                          format:(int)format compressSize:(int)compressSize;

+ (NSData *)compressDataWithUIImage:(UIImage *)image minWidth:(int)minWidth minHeight:(int)minHeight
                            quality:(int)quality rotate:(int)rotate format:(int)format compressSize:(int)compressSize;
@end
