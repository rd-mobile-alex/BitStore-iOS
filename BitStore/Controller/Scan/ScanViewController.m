//
//  ScanViewController.m
//  BitStore
//
//  Created by Dylan Marriott on 16.06.14.
//  Copyright (c) 2014 Dylan Marriott. All rights reserved.
//

#import "ScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "ScanDelegate.h"
#import "URI.h"
#import "UIBAlertView.h"

@interface ScanViewController () <AVCaptureMetadataOutputObjectsDelegate>
@end

@implementation ScanViewController {
    AVCaptureSession* _captureSession;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem* closeItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(close:)];
    self.navigationItem.leftBarButtonItem = closeItem;
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    if ([self isCameraAvailable]) {
        _captureSession = [[AVCaptureSession alloc] init];
        AVCaptureDevice* videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        NSError* error = nil;
        AVCaptureDeviceInput* videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoCaptureDevice error:&error];
        if (videoInput) {
            [_captureSession addInput:videoInput];
            AVCaptureMetadataOutput* metadataOutput = [[AVCaptureMetadataOutput alloc] init];
            [_captureSession addOutput:metadataOutput];
            [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
            [metadataOutput setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
            
            AVCaptureVideoPreviewLayer* previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            previewLayer.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
            [self.view.layer addSublayer:previewLayer];
        } else {
            // camera access failed
            UIBAlertView* av = [[UIBAlertView alloc] initWithTitle:@"Camera error" message:@"Unable to access the camera. Please enable camera access for BitStore inside the privacy settings." cancelButtonTitle:l10n(@"okay") otherButtonTitles:@"Open Settings", nil];
            [av showWithDismissHandler:^(NSInteger selectedIndex, NSString *selectedTitle, BOOL didCancel) {
#ifdef __IPHONE_8_0
                if (!didCancel) {
                    BOOL canOpenSettings = (&UIApplicationOpenSettingsURLString != NULL);
                    if (canOpenSettings) {
                        NSURL* url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                        [[UIApplication sharedApplication] openURL:url];
                    }
                }
#endif
            }];
            [self performSelector:@selector(close:) withObject:self afterDelay:0.01];
        }
    } else {
        self.view.backgroundColor = [UIColor darkGrayColor];
    }
    
    UIImageView* overlay = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scan_overlay"]];
    overlay.frame = CGRectMake(0, ((self.view.frame.size.height - 64) / 2 - overlay.frame.size.height / 2) + 64, overlay.frame.size.width, overlay.frame.size.height);
    [self.view addSubview:overlay];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[PiwikTracker sharedInstance] sendEventWithCategory:@"Events" action:@"Scan" label:@"Scan"];
    [_captureSession startRunning];
}

- (void)close:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
	for (AVMetadataObject *metadataObject in metadataObjects) {
		AVMetadataMachineReadableCodeObject* readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;
		if ([metadataObject.type isEqualToString:AVMetadataObjectTypeQRCode]) {
            NSString* address = readableObject.stringValue;
            NSString* amount = nil;
            if ([address hasPrefix:@"bitcoin:"]) {
                URI* uri = [[URI alloc] initWithString:address];
                address = uri.address;
                amount = uri.amount;
            }
            [_captureSession stopRunning];
            [_delegate scannedAddress:address amount:amount];
        }
	}
}

- (BOOL)isCameraAvailable {
    NSArray* videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    return [videoDevices count] > 0;
}


- (void)reset {
    [_captureSession startRunning];
}

@end
