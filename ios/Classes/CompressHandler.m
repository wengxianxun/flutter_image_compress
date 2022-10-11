//
// Created by cjl on 2018/9/8.
//

#import "CompressHandler.h"
#import "UIImage+scale.h"
#import "UIImage+WebP.h"
#import "ImageCompressPlugin.h"
#import <SDWebImageWebPCoder/SDImageWebPCoder.h>

@implementation CompressHandler {

}

+ (NSData *)compressWithData:(NSData *)data quality:(int)quality
                       format:(int)format  compressSize:(int)compressSize{
    UIImage *img = [self isWebP:data] ? [UIImage sd_imageWithWebPData:data] : [[UIImage alloc] initWithData:data];
    return [CompressHandler compressWithUIImage:img quality:quality format:format compressSize:compressSize];
}

+ (NSData *)compressWithUIImage:(UIImage *)image quality:(int)quality
                         format:(int)format compressSize:(int)compressSize {
    if([ImageCompressPlugin showLog]){
        NSLog(@"width = %.0f",[image size].width);
        NSLog(@"height = %.0f",[image size].height);
        
        NSLog(@"format = %d", format);
    }

    
    NSData *resultData = [self compressDataWithImage:image quality:quality format:format compressSize:compressSize];

    return resultData;
}


+ (NSData *)compressDataWithUIImage:(UIImage *)image minWidth:(int)minWidth minHeight:(int)minHeight
                            quality:(int)quality rotate:(int)rotate format:(int)format compressSize:(int)compressSize{
    image = [image scaleWithMinWidth:minWidth minHeight:minHeight];
    if(rotate % 360 != 0){
        image = [image rotate: rotate];
    }
    return [self compressDataWithImage:image quality:quality format:format compressSize:compressSize];
}

+ (NSData *)compressDataWithImage:(UIImage *)image quality:(float)quality format:(int)format compressSize:(int)compressSize{
    NSData *data;
    
    // webp和png都是用jpg的代码
    
    if (format == 2) { // heic
        CIImage *ciImage = [CIImage imageWithCGImage:image.CGImage];
        CIContext *ciContext = [[CIContext alloc]initWithOptions:nil];
        NSString *tmpDir = NSTemporaryDirectory();
        double time = [[NSDate alloc]init].timeIntervalSince1970;
        NSString *target = [NSString stringWithFormat:@"%@%.0f.heic",tmpDir, time * 1000];
        NSURL *url = [NSURL fileURLWithPath:target];
        
        NSMutableDictionary *options = [NSMutableDictionary new];
        NSString *qualityKey = (__bridge NSString *)kCGImageDestinationLossyCompressionQuality;
//        CIImageRepresentationOption
        [options setObject:@(quality / 100) forKey: qualityKey];
        
        if (@available(iOS 11.0, *)) {
            [ciContext writeHEIFRepresentationOfImage:ciImage toURL:url format: kCIFormatARGB8 colorSpace: ciImage.colorSpace options:options error:nil];
            data = [NSData dataWithContentsOfURL:url];
        } else {
            // Fallback on earlier versions
            data = nil;
        }
//    } else if(format == 3 || f){ // webp
//        SDImageCoderOptions *option = @{SDImageCoderEncodeCompressionQuality: @(quality / 100)};
//        data = [[SDImageWebPCoder sharedCoder]encodedDataWithImage:image format:SDImageFormatWebP options:option];
//    } else if(format == 1){ // png
//        data = UIImagePNGRepresentation(image);
    }else { // 0 or other is jpeg
//        data = UIImageJPEGRepresentation(image, (CGFloat) quality / 100);
        data = [self compressedImageFiles:image imageKB:compressSize];
    }

    return data;
}


+ (NSData *)compressedImageFiles:(UIImage *)image imageKB:(CGFloat)fImageKBytes {
    //二分法压缩图片
    CGFloat compression = 1;
    NSData *imageData = UIImageJPEGRepresentation(image, compression);
    NSUInteger fImageBytes = fImageKBytes * 1000;//需要压缩的字节Byte，iOS系统内部的进制1000
    if (imageData.length <= fImageBytes){
        return imageData;
    }
    CGFloat max = 1;
    CGFloat min = 0;
    //指数二分处理，s首先计算最小值
    compression = pow(2, -6);
    imageData = UIImageJPEGRepresentation(image, compression);
    if (imageData.length < fImageBytes) {
        //二分最大10次，区间范围精度最大可达0.00097657；最大6次，精度可达0.015625
        for (int i = 0; i < 6; ++i) {
            compression = (max + min) / 2;
            imageData = UIImageJPEGRepresentation(image, compression);
            //容错区间范围0.9～1.0
            if (imageData.length < fImageBytes * 0.9) {
                min = compression;
            } else if (imageData.length > fImageBytes) {
                max = compression;
            } else {
                break;
            }
        }
        
        return imageData;
    }
    
    // 对于图片太大上面的压缩比即使很小压缩出来的图片也是很大，不满足使用。
    //然后再一步绘制压缩处理
    UIImage *resultImage = [UIImage imageWithData:imageData];
    while (imageData.length > fImageBytes) {
        @autoreleasepool {
            CGFloat ratio = (CGFloat)fImageBytes / imageData.length;
            //使用NSUInteger不然由于精度问题，某些图片会有白边
            NSLog(@">>>>>>>>>>>>>>>>>%f>>>>>>>>>>>>%f>>>>>>>>>>>%f",resultImage.size.width,sqrtf(ratio),resultImage.size.height);
            CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)),
                                     (NSUInteger)(resultImage.size.height * sqrtf(ratio)));
            resultImage = [self createImageForData:imageData maxPixelSize:MAX(size.width, size.height)];
            imageData = UIImageJPEGRepresentation(resultImage, compression);
        }
    }
    
    //   整理后的图片尽量不要用UIImageJPEGRepresentation方法转换，后面参数1.0并不表示的是原质量转换。
    return imageData;
}


+ (UIImage *)createImageForData:(NSData *)data maxPixelSize:(NSUInteger)size {
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageSourceRef source = CGImageSourceCreateWithDataProvider(provider, NULL);
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef) @{
                                                                                                      (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                                                                      (NSString *)kCGImageSourceThumbnailMaxPixelSize : @(size),
                                                                                                      (NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                                                                      });
    CFRelease(source);
    CFRelease(provider);
    if (!imageRef) {
        return nil;
    }
    UIImage *toReturn = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);
    return toReturn;
}



+ (NSData *)compressImageQuality:(UIImage *)image toByte:(NSInteger)maxLength {
    
    NSInteger maxLengthByte = maxLength * 1000;
    
    CGFloat compression = 1;
    
    compression = pow(2, -6);
    NSData *data = UIImageJPEGRepresentation(image, compression);
    if (data.length < maxLengthByte) return data;
    CGFloat max = 1;
    CGFloat min = 0;
    for (int i = 0; i < 6; ++i) {
        compression = (max + min) / 2;
        data = UIImageJPEGRepresentation(image, compression);
        if (data.length < maxLengthByte * 0.9) {
            min = compression;
        } else if (data.length > maxLengthByte) {
            max = compression;
        } else {
            break;
        }
    }
//    UIImage *resultImage = [UIImage imageWithData:data];
    return data;
}


+ (BOOL)isWebP:(NSData *)data {
    if (data.length < 12) return false;

    NSData *riff = [data subdataWithRange:NSMakeRange(8, 4)];
    NSString* format = [[NSString alloc] initWithData:riff encoding:(NSASCIIStringEncoding)];

    return [format isEqualToString:@"WEBP"];
}

@end
