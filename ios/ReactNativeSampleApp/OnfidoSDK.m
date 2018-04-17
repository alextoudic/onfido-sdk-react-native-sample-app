//
//  OnfidoSDK.m
//  ReactNativeSampleApp
//
//  Created by Anurag Ajwani on 16/04/2018.
//  Copyright © 2018 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OnfidoSDK.h"
#import "AppDelegate.h"
#import <Onfido/Onfido.h>
#import <UIKit/UIKit.h>
#import <AFNetworking/AFNetworking.h>
#import <MBProgressHUD/MBProgressHUD.h>

@interface OnfidoSDK () {
  NSString *token;
  UIViewController *rootViewController;
}
@end

@implementation OnfidoSDK

RCT_EXPORT_MODULE(OnfidoSDK);

RCT_EXPORT_METHOD(startSDK) {
  [OnfidoSDK startSDK];
}

+ (void) startSDK {
  
  OnfidoSDK *sdk = [[OnfidoSDK alloc] init];
  [sdk run];
}

- (id) init {
  self = [super init];
  
  if (self) {
    self->token = @"test_VBT_HMGBQ2GuzMB9flUgjRr8OBiDi1mT";
  }
  
  return self;
}

/**
 Runs Onfido SDK Flow
 */
- (void) run {
  
  dispatch_async(dispatch_get_main_queue(), ^{
    
    // Get view controller on which to present the flow
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self->rootViewController = (UIViewController *)delegate.window.rootViewController;
    
    // Show spinner whilst applicant is being created
    MBProgressHUD *progressDisplay = [MBProgressHUD showHUDAddedTo:self->rootViewController.view animated:YES];
    progressDisplay.label.text = @"Creating applicant";
    
    [self createApplicant:^(NSString *applicantId) {
      
      [progressDisplay removeFromSuperview];
      
      if (applicantId) {
        
        // Configure Onfido SDK Flow
        // more on creating the configuration https://github.com/onfido/onfido-ios-sdk#5-creating-the-sdk-configuration
        // more on flow customization https://github.com/onfido/onfido-ios-sdk#flow-customisation
        
        ONFlowConfigBuilder *configBuilder = [ONFlowConfig builder];
        [configBuilder withToken:self->token];
        [configBuilder withApplicantId:applicantId];
        [configBuilder withDocumentStep];
        [configBuilder withFaceStepOfVariant:ONFaceStepVariantPhoto];
        
        NSError *configError = NULL;
        ONFlowConfig *config = [configBuilder buildAndReturnError:&configError];
        
        if (configError == NULL) {
          
          // if there are no configurations erros run flow
          // more on configuration errors https://github.com/onfido/onfido-ios-sdk#configuration-errors
          [self runSDKFlowWithConfig:config];
          
        } else {
          
          UIAlertController *popup = [self createErrorPopupWithMessage:[NSString stringWithFormat:@"unable to run flow %@", [[configError userInfo] valueForKey:@"message"]]];
          
          [self->rootViewController presentViewController:popup animated:YES completion:NULL];
        }
      } else {
        [self->rootViewController presentViewController:[self createErrorPopupWithMessage:@"unable to create applicant"] animated:YES completion:NULL];
      }
    }];
  });
}

- (void) runSDKFlowWithConfig: (ONFlowConfig *) config {
  
  ONFlow *flow = [[ONFlow alloc] initWithFlowConfiguration:config];
  
  // register callback handler
  [flow withResponseHandler:^(ONFlowResponse * _Nonnull response) {
    // more on handling callbacks https://github.com/onfido/onfido-ios-sdk#handling-callbacks
    [self handleFlowResponse:response];
  }];
  
  NSError *runError = NULL;
  UIViewController *flowVC = [flow runAndReturnError:&runError];
  
  if (runError == NULL) { //more on run exceptions https://github.com/onfido/onfido-ios-sdk#run-exceptions
    
    [self->rootViewController presentViewController:flowVC animated:YES completion:nil];
  } else {
    // Flow may not run
    NSLog(@"Run error %@", [[runError userInfo] valueForKey:@"message"]);
  }
}

- (void) handleFlowResponse: (ONFlowResponse *) response {
  
  [rootViewController dismissViewControllerAnimated:YES completion:^{
    
    if (response.error) {
      
      // Flow encountered error
      [self handleFlowError:response.error];
      
    } else if (response.userCanceled) {
      
      // Flow was canceled by the user
      [self handleUserFlowCancelation];
      
    } else if (response.results) {
      
      // Flow ran successfuly and produced results
      [self handleFlowResults:response.results];
    }
  }];
}

- (void) handleFlowResults: (NSArray *) results {
  
  // Handle results
  // more on success handling https://github.com/onfido/onfido-ios-sdk#success-handling
  for (ONFlowResult *result in results) {
    
    if (result.type == ONFlowResultTypeDocument) {
      ONDocumentResult *docResult = (ONDocumentResult *)(result.result);
      
      /* Document Result
       Onfido api response to the creation of the document result
       More details: https://documentation.onfido.com/#document-object
       */
      NSLog(@"%@", docResult.description);
    } else if (result.type == ONFlowResultTypeFace) {
      ONFaceResult *faceResult = (ONFaceResult *)(result.result);
      
      /* Live Photo / Live Video
       Onfido api response to the creation of the live photo / live video
       More details: https://documentation.onfido.com/#live-photo-object
       */
      NSLog(@"%@", faceResult.description);
    }
  }
  
  UIAlertController *successPopup = [self createFlowRunSuccessPopup];
  [self->rootViewController presentViewController:successPopup animated:YES completion:NULL];
}

- (void) handleFlowError: (NSError *) error {
  
  // handle error here
  // see https://github.com/onfido/onfido-ios-sdk#error-handling
  
  UIAlertController *errorPopup;
  if (error.code == ONFlowErrorCameraPermission) {
    errorPopup = [self createErrorPopupWithMessage:@"Camera permission denied"];
  } else {
    errorPopup = [self createErrorPopupWithMessage:@"Unhandled error"];
  }
  
  [rootViewController presentViewController:errorPopup animated:YES completion:NULL];
}

- (void) handleUserFlowCancelation {
  
  [rootViewController presentViewController:[self createUserCanceledPopup] animated:YES completion:NULL];
}

/**
 Creates applicant, return NULL if unable to create
 */
- (void)createApplicant: (void(^)(NSString *))onResponse {
  
  NSDictionary *parameters = @{@"first_name":@"Frank", @"last_name":@"Abagnale"};
  AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
  manager.requestSerializer = [AFJSONRequestSerializer serializer];
  NSString *tokenHeaderValue = [NSString stringWithFormat:@"Token token=%@", self->token];
  [manager.requestSerializer setValue:tokenHeaderValue forHTTPHeaderField:@"Authorization"];
  [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
  [manager POST:@"https://api.onfido.com/v2/applicants"
     parameters:parameters
       progress:nil
        success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
          onResponse([responseObject valueForKey:@"id"]);
        }
        failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
          NSLog(@"failed to create applicant");
          onResponse(NULL);
        }];
}

- (UIAlertController *)createErrorPopupWithMessage: (NSString *) errorMessage {
  
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
  [alert addAction:action];
  
  return alert;
}

- (UIAlertController *)createFlowRunSuccessPopup {
  
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success" message:@"The SDK flow ran successfully" preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
  [alert addAction:action];
  
  return alert;
}

- (UIAlertController *)createUserCanceledPopup {
  
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Canceled" message:@"The SDK flow was canceled  by the user" preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
  [alert addAction:action];
  
  return alert;
}

@end