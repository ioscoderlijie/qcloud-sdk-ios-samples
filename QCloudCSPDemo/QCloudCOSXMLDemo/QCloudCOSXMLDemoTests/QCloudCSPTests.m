//
//  QCloudCOSCSPTest.m
//  QCloudCOSXMLDemoTests
//
//  Created by karisli(李雪) on 2018/8/28.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "TestCommonDefine.h"

#import <XCTest/XCTest.h>
#import <QCloudCOSXML/QCloudCOSXML.h>
#import <QCloudCore/QCloudServiceConfiguration_Private.h>
#import <QCloudCore/QCloudAuthentationCreator.h>
#import <QCloudCore/QCloudCredential.h>
#import "QCloudTestTempVariables.h"
#import "QCloudCSPCOSXMLTestUtility.h"
#define kOwnerUIN @"100004603008"
//这是一个测试文件的一个全局bucket，请确保该bucket存在，测试环境请确认配置了hosts（可以使用不用创建新的bucket，使用demo中的宏定义的kTestBucket也可以）
#define ktestCSPBucket @"a-appid"
//这是一个测试copy的目的的bucket，请确保该bucket存在，测试环境请确认配置了hosts
#define ktestCopyDesBucket @"bukcet-appid"
//这个bucket是要测试先创建后删除的，请确保该bucket不存在，否则无法创建成功，测试环境请确认配置了hosts
#define kTestPutBucket @"testPutBucket"
//用来测试chunked的文件
#define kTestGetChunkedObject @"2.txt"
//这个bucket是用来测试批量删除对象接口的，请确保该bucket存在，测试环境请确认配置了hosts
#define kTestMuti_Del_Object_Bucket @"testmutidelobjectsbucket"
@interface QCloudCOSCSPTest : XCTestCase<QCloudSignatureProvider>
@property (nonatomic, strong) NSString* authorizedUIN;
@property (nonatomic, strong) NSString* ownerUIN;
@property (nonatomic, strong) NSMutableArray* tempFilePathArray;
@property (nonnull,strong) NSString *bucket;
@end

@implementation QCloudCOSCSPTest
- (void)signatureWithFields:(QCloudSignatureFields *)fileds request:(QCloudBizHTTPRequest *)request urlRequest:(NSMutableURLRequest *)urlRequst compelete:(QCloudHTTPAuthentationContinueBlock)continueBlock {
    NSMutableURLRequest *requestToSigned = urlRequst;
    //请在这里将服务器地址替换为签名服务器的地址
    [[COSXMLGetSignatureTool sharedNewtWorkTool]PutRequestWithUrl:@"服务器地址" request:requestToSigned successBlock:^(NSString * _Nonnull sign) {
        NSLog(@"该requestid是：%lld  sign是: %@",request.requestID,sign);
        QCloudSignature *signature = [[QCloudSignature alloc] initWithSignature:sign expiration:nil];
        continueBlock(signature, nil);
    }];
   
    
}

- (void) setupSpecialCOSXMLShareService {
    QCloudServiceConfiguration* configuration = [[QCloudServiceConfiguration alloc] init];
    QCloudCOSXMLEndPoint* endpoint = [[QCloudCOSXMLEndPoint alloc] init];
    endpoint.regionName = kRegion;
    //设置bucket是前缀还是后缀，默认是yes为前缀（bucket.cos.wh.yun.ccb.com），设置为no即为后缀（cos.wh.yun.ccb.com/bucket）
    //    endpoint.isPrefixURL = NO;
    configuration.appID = kAppID;
    endpoint.serviceName = testserviceName;
    configuration.endpoint = endpoint;
    configuration.signatureProvider = self;
    [QCloudCOSXMLService registerDefaultCOSXMLWithConfiguration:configuration];
    [QCloudCOSTransferMangerService registerDefaultCOSTransferMangerWithConfiguration:configuration];
    [QCloudCOSXMLService registerCOSXMLWithConfiguration:configuration withKey:@"kCSPServiceKey"];
    [QCloudCOSTransferMangerService registerCOSTransferMangerWithConfiguration:configuration withKey:@"kCSPServiceKey"];
}
-(QCloudCOSXMLService *)getCSPCOSXMLService{
    return [QCloudCOSXMLService cosxmlServiceForKey:@"kCSPServiceKey"];
}
-(QCloudCOSTransferMangerService *)getCSPCOSXMLTransferService{
    return [QCloudCOSTransferMangerService costransfermangerServiceForKey:@"kCSPServiceKey"];
}
- (NSString*) uploadTempObject
{
    QCloudPutObjectRequest* put = [QCloudPutObjectRequest new];
    put.object = @"testOptionsObject";
    put.bucket = self.bucket;
    put.body =  [@"1234jdjdjdjjdjdjyuehjshgdytfakjhsghgdhg" dataUsingEncoding:NSUTF8StringEncoding];
    XCTestExpectation* exp = [self expectationWithDescription:@"put object"];
    [put setFinishBlock:^(id outputObject, NSError *error) {
        [exp fulfill];
    }];
    [[self getCSPCOSXMLService] PutObject:put];
    [self waitForExpectationsWithTimeout:80 handler:^(NSError * _Nullable error) {
    }];
    return put.object;
}

- (NSString*) tempFileWithSize:(int)size
{
    NSString* file4MBPath = QCloudPathJoin(QCloudTempDir(), [NSUUID UUID].UUIDString);
    
    if (!QCloudFileExist(file4MBPath)) {
        [[NSFileManager defaultManager] createFileAtPath:file4MBPath contents:[NSData data] attributes:nil];
    }
    NSFileHandle* handler = [NSFileHandle fileHandleForWritingAtPath:file4MBPath];
    [handler truncateFileAtOffset:size];
    [handler closeFile];
    [self.tempFilePathArray  addObject:file4MBPath];
    
    return file4MBPath;
}


- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [self setupSpecialCOSXMLShareService];
    self.tempFilePathArray = [NSMutableArray array];
    self.bucket = ktestCSPBucket;
    self.ownerUIN = kOwnerUIN;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    //    [[QCloudCSPCOSXMLTestUtility sharedInstance]deleteTestBucket:testBucketCSP];
    //    [[QCloudCSPCOSXMLTestUtility sharedInstance]deleteTestBucket:testCopyBucketCSP];
}

#pragma mark - bukcet
- (void)testHeadBucket{
    XCTestExpectation* exception = [self expectationWithDescription:@"head bucket exception"];
    QCloudHeadBucketRequest* request = [QCloudHeadBucketRequest new];
    request.bucket = self.bucket; //存储桶名称(cos v5 的 bucket格式为：xxx-appid, 如 test-1253960454)
    __block NSError* resultError;
    [request setFinishBlock:^(id outputObject, NSError* error) {
        //设置完成回调。如果没有error，则可以正常访问bucket。如果有error，可以从error code和messasge中获取具体的失败原因。
        NSLog(@"outputObject:  %@ %@",outputObject,error);
        resultError = error;
        [exception fulfill];
    }];
    [[self getCSPCOSXMLService] HeadBucket:request];
    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertNil(resultError);
}
-(void)testGetBucket{
    XCTestExpectation* exception = [self expectationWithDescription:@"Delete bucket exception"];
    __block NSError* responseError ;
    QCloudGetBucketRequest *get = [QCloudGetBucketRequest new];
    get.maxKeys = 1000;
    get.bucket = self.bucket;
    NSLog(@"self.bucket:  %@",self.bucket);
    [get setFinishBlock:^(QCloudListBucketResult * _Nonnull result, NSError * _Nonnull error) {
        XCTAssertNil(error);
        XCTAssertNotNil(result);
        if (!error && result) {
            XCTAssert([result.name isEqual:self.bucket],@"result.name is %@",result.name);
        }
        [exception fulfill];
    }];
    [[self getCSPCOSXMLService ]GetBucket:get];
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
}

- (void)testGetService {
    QCloudGetServiceRequest* request = [[QCloudGetServiceRequest alloc] init];
    XCTestExpectation* expectation = [self expectationWithDescription:@"Get service"];
    [request setFinishBlock:^(QCloudListAllMyBucketsResult* result, NSError* error) {
        QCloudLogInfo(@"setFinishBlock %@  %@",result.buckets,result.buckets.firstObject.name);
        XCTAssertNil(error);
        XCTAssert(result);
        XCTAssertNotNil(result.owner);
        XCTAssertNotNil(result.buckets);
        XCTAssert(result.buckets.count > 0,@"buckets not more than zero, it is %lu",(unsigned long)result.buckets.count);
        XCTAssertNotNil(result.buckets.firstObject.name);
        XCTAssertNotNil(result.buckets.firstObject.createDate);
        [expectation fulfill];
    }];
    [[self getCSPCOSXMLService]GetService:request];
    [self waitForExpectationsWithTimeout:80 handler:nil];
}


- (void)testPutBucket {
    XCTestExpectation* exception = [self expectationWithDescription:@"put bucket exception"];

    QCloudPutBucketRequest* putBucketRequest = [[QCloudPutBucketRequest alloc] init];
    putBucketRequest.bucket = kTestPutBucket;
    [putBucketRequest setFinishBlock:^(id outputObject, NSError* error) {
        XCTAssertNil(error);
        [exception fulfill];
    }];
    [[self getCSPCOSXMLService] PutBucket:putBucketRequest];
    [self waitForExpectationsWithTimeout:100 handler:nil];

}


#pragma mark - bucket cors

- (void) testCORS_Put_Get_DelBucketCORS {
    QCloudPutBucketCORSRequest* putCORS = [QCloudPutBucketCORSRequest new];
    QCloudCORSConfiguration* cors = [QCloudCORSConfiguration new];
    QCloudCORSRule* rule = [QCloudCORSRule new];
    rule.identifier = @"sdk";
    rule.allowedHeader = @[@"origin",@"host",@"accept",@"content-type",@"authorization"];
    rule.exposeHeader = @"ETag";
    rule.allowedMethod = @[@"GET",@"PUT",@"POST", @"DELETE", @"HEAD"];
    rule.maxAgeSeconds = 3600;
    rule.allowedOrigin = @"*";
    cors.rules = @[rule];
    putCORS.corsConfiguration = cors;
    putCORS.bucket = self.bucket;
    __block NSError* localError;
    __block QCloudCORSConfiguration* cors1;
    XCTestExpectation* exp = [self expectationWithDescription:@"putacl"];
    [putCORS setFinishBlock:^(id outputObject, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(outputObject);
        QCloudGetBucketCORSRequest* corsReqeust = [QCloudGetBucketCORSRequest new];
        corsReqeust.bucket = self.bucket;
        [corsReqeust setFinishBlock:^(QCloudCORSConfiguration * _Nonnull result, NSError * _Nonnull error) {
            XCTAssertNil(error);
            cors1 = result;
            XCTAssertNotNil(result);
            QCloudDeleteBucketCORSRequest *delCors = [QCloudDeleteBucketCORSRequest new];
            delCors.bucket = self.bucket;
            [delCors setFinishBlock:^(id outputObject, NSError *error) {
                XCTAssertNil(error);
                XCTAssertNotNil(outputObject);
                [exp fulfill];
            }];
            [[self getCSPCOSXMLService] DeleteBucketCORS:delCors];
        }];
        [[self getCSPCOSXMLService] GetBucketCORS:corsReqeust];
    }];
    [[self getCSPCOSXMLService] PutBucketCORS:putCORS];
    [self waitForExpectationsWithTimeout:20 handler:nil];
    
}


#pragma mark - bucket acl
- (void) testPut_And_Get_BucketACL {
    QCloudPutBucketACLRequest* putACL = [QCloudPutBucketACLRequest new];
    putACL.runOnService = [self getCSPCOSXMLService];
    NSString *ownerIdentifier = [NSString stringWithFormat:@"qcs::cam::uin/%@:uin/%@", self.ownerUIN,self.ownerUIN];
    NSString *grantString = [NSString stringWithFormat:@"id=\"%@\"",ownerIdentifier];
    putACL.grantFullControl = grantString;
    putACL.grantRead = grantString;
    putACL.grantWrite = grantString;
    putACL.bucket = self.bucket;
    XCTestExpectation* exp = [self expectationWithDescription:@"putacl"];
    __block NSError* localError;
    [putACL setFinishBlock:^(id outputObject, NSError *error) {
        XCTAssertNil(error);
        QCloudGetBucketACLRequest* getBucketACLRequest = [[QCloudGetBucketACLRequest alloc] init];
        getBucketACLRequest.bucket = self.bucket;
        [getBucketACLRequest setFinishBlock:^(QCloudACLPolicy* result, NSError* error) {
            XCTAssertNil(error);
            XCTAssertNotNil(result);
            NSString* ownerIdentifiler = [NSString identifierStringWithID:self.ownerUIN :self.ownerUIN];
            XCTAssert([result.owner.identifier isEqualToString:ownerIdentifiler],@"result Owner Identifier is%@",result.owner.identifier);
            [exp fulfill];
        }];
        [[self getCSPCOSXMLService] GetBucketACL:getBucketACLRequest];
    }];
    [[self getCSPCOSXMLService] PutBucketACL:putACL];
    [self waitForExpectationsWithTimeout:100 handler:nil];
    XCTAssertNil(localError);
    
}



#pragma mark - obejct
- (void) testHeadeObject   {
    QCloudPutObjectRequest* put = [QCloudPutObjectRequest new];
    __block NSString *object = [NSUUID UUID].UUIDString;
    put.object = object;
    put.bucket = self.bucket;
    put.body =  [@"This is test content" dataUsingEncoding:NSUTF8StringEncoding];
    XCTestExpectation* exp = [self expectationWithDescription:@"delete"];
    __block NSError* resultError;
    __block  NSDictionary *dic;
    [put setFinishBlock:^(id outputObject, NSError *error) {
        XCTAssertNil(error,@"put Object fail!");
        QCloudHeadObjectRequest* headerRequest = [QCloudHeadObjectRequest new];
        headerRequest.object = object;
        headerRequest.bucket = self.bucket;
        [headerRequest setFinishBlock:^(NSDictionary* result, NSError *error) {
            XCTAssertNil(error);
            XCTAssertNotNil(result);
            [exp fulfill];
        }];
        
        [[self getCSPCOSXMLService] HeadObject:headerRequest];
        
    }];
    [[self getCSPCOSXMLService] PutObject:put];
    [self waitForExpectationsWithTimeout:200 handler:nil];
    
}

-(void)testGetObjectWithChunked{
    XCTestExpectation* exp = [self expectationWithDescription:@"get chunked object expectation"];
    QCloudGetObjectRequest* request = [QCloudGetObjectRequest new];
    request.downloadingURL = [NSURL URLWithString:QCloudTempFilePathWithExtension(@"downloading-1111111")];
    QCloudLogInfo(@"%@",request.downloadingURL);
    request.bucket = self.bucket;
    request.object = kTestGetChunkedObject;
    [request setFinishBlock:^(id outputObject, NSError *error) {
        QCloudLogInfo(@"outputObject: %@",outputObject);
        XCTAssertNil(error);
        [exp fulfill];
    }];
    [request setDownProcessBlock:^(int64_t bytesDownload, int64_t totalBytesDownload, int64_t totalBytesExpectedToDownload) {
        NSLog(@"⏬⏬⏬⏬DOWN [Total]%lld  [Downloaded]%lld [Download]%lld", totalBytesExpectedToDownload, totalBytesDownload, bytesDownload);
    }];
    [[self getCSPCOSXMLService] GetObject:request];
    [self waitForExpectationsWithTimeout:80 handler:nil];
}

-(void)testGetObjectWithMD5{
    QCloudPutObjectRequest* put = [QCloudPutObjectRequest new];
    NSString* object =  [NSUUID UUID].UUIDString;
    put.object =object;
    put.bucket = self.bucket;
    NSURL* fileURL = [NSURL fileURLWithPath:[self tempFileWithSize:1024*1024*3]];
    put.body = fileURL;
    NSLog(@"fileURL  %@",fileURL.absoluteString);
    XCTestExpectation* exp = [self expectationWithDescription:@"get Object expectation"];
    __block QCloudGetObjectRequest* request = [QCloudGetObjectRequest new];
    request.downloadingURL = [NSURL URLWithString:QCloudTempFilePathWithExtension(@"downloading")];
    [put setFinishBlock:^(id outputObject, NSError *error) {
        request.bucket = ktestCSPBucket;
        request.object = object;
        request.enableMD5Verification = YES;
        [request setFinishBlock:^(id outputObject, NSError *error) {
            QCloudLogInfo(@"outputObject: %@",outputObject);
            XCTAssertNil(error);
            [exp fulfill];
        }];
        [request setDownProcessBlock:^(int64_t bytesDownload, int64_t totalBytesDownload, int64_t totalBytesExpectedToDownload) {
            NSLog(@"⏬⏬⏬⏬DOWN [Total]%lld  [Downloaded]%lld [Download]%lld", totalBytesExpectedToDownload, totalBytesDownload, bytesDownload);
        }];
        [[self getCSPCOSXMLService] GetObject:request];
        
    }];
    [[self getCSPCOSXMLService] PutObject:put];
    [self waitForExpectationsWithTimeout:80 handler:nil];
    XCTAssertEqual(QCloudFileSize(request.downloadingURL.path), QCloudFileSize(fileURL.path));
    
}

-(void)testDelObject{
    QCloudPutObjectRequest* put = [QCloudPutObjectRequest new];
    __block NSString *object = @"karisTestPutbejct1";
    put.object = object;
    put.bucket = self.bucket;
    put.body =  [@"This is test content" dataUsingEncoding:NSUTF8StringEncoding];
    XCTestExpectation* ObjectExpectation = [self expectationWithDescription:@"delete object expectation"];
    [put setFinishBlock:^(id outputObject, NSError *error) {
        XCTAssertNil(error,@"put Object fail!");
        QCloudDeleteObjectRequest* deleteObjectRequest = [[QCloudDeleteObjectRequest alloc] init];
        deleteObjectRequest.bucket = self.bucket;
        deleteObjectRequest.object = @"putobejct";
        [deleteObjectRequest setFinishBlock:^(id outputObject, NSError *error) {
            XCTAssertNil(error,@"delete Object Fail!");
            XCTAssertNotNil(outputObject);
            [ObjectExpectation fulfill];
        }];
        [[self getCSPCOSXMLService] DeleteObject:deleteObjectRequest];
        
    }];
    [[self getCSPCOSXMLService] PutObject:put];
    [self waitForExpectationsWithTimeout:200 handler:nil];
}
-(void)testOptionsObject{
    
    XCTestExpectation* ObjectExpectation = [self expectationWithDescription:@"options object"];
    QCloudOptionsObjectRequest* request = [[QCloudOptionsObjectRequest alloc] init];
    request.bucket = self.bucket;
    request.origin = @"http://www.yun.ccb.com";
    request.accessControlRequestMethod = @"GET";
    request.accessControlRequestHeaders = @"origin";
    request.object = @"a.png";
    [request setFinishBlock:^(id outputObject, NSError* error) {
        XCTAssertNil(error);
        XCTAssertNotNil(outputObject);
        [ObjectExpectation fulfill];
    }];
    [[self getCSPCOSXMLService] OptionsObject:request];
    [self waitForExpectationsWithTimeout:200 handler:nil];
    
}

#pragma mark - object acl

-(void)testPut_GetObjectACL{
    QCloudPutObjectACLRequest* request = [QCloudPutObjectACLRequest new];
    request.bucket = self.bucket;
    __block NSString *object = [self uploadTempObject];
    request.object = object;
    NSString *ownerIdentifier = [NSString stringWithFormat:@"qcs::cam::uin/%@:uin/%@",self.ownerUIN, self.ownerUIN];
    NSString *grantString = [NSString stringWithFormat:@"id=\"%@\"",ownerIdentifier];
    request.grantFullControl = grantString;
    XCTestExpectation* exp = [self expectationWithDescription:@"acl"];
    __block NSError* localError;
    [request setFinishBlock:^(id outputObject, NSError *error) {
        XCTAssertNil(error);
        QCloudGetObjectACLRequest* request = [QCloudGetObjectACLRequest new];
        request.bucket = self.bucket;
        request.object = object;
        [request setFinishBlock:^(QCloudACLPolicy * _Nonnull policy, NSError * _Nonnull error) {
            XCTAssertNil(error);
            XCTAssertNotNil(policy);
            NSString* expectedIdentifier = [NSString identifierStringWithID:self.ownerUIN :self.ownerUIN];
            XCTAssert([policy.owner.identifier isEqualToString:expectedIdentifier]);
            XCTAssert(policy.accessControlList.ACLGrants.count == 1);
            NSLog(@"testObject : %@",policy.owner.identifier);
            XCTAssert([[policy.accessControlList.ACLGrants firstObject].grantee.identifier isEqualToString:[NSString identifierStringWithID:self.ownerUIN :self.ownerUIN]]);
            [exp fulfill];
        }];
        [[QCloudCOSXMLService defaultCOSXML] GetObjectACL:request];
    }];
    
    [[self getCSPCOSXMLService] PutObjectACL:request];
    [self waitForExpectationsWithTimeout:200 handler:nil];
}

-(void)testMutipartUpload{
    QCloudCOSXMLUploadObjectRequest* put = [QCloudCOSXMLUploadObjectRequest new];
    int randomNumber = arc4random()%100;
    NSURL* url = [NSURL fileURLWithPath:[self tempFileWithSize:2*1024*1024]];
    put.object = [NSUUID UUID].UUIDString;
    put.bucket = self.bucket;
    put.body =  url;
    [put setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"upload %lld totalSend %lld aim %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
    }];
    XCTestExpectation* exp = [self expectationWithDescription:@"delete33"];
    __block QCloudUploadObjectResult* result;
    [put setFinishBlock:^(id outputObject, NSError *error) {
        result = outputObject;
        XCTAssertNil(error);
        [exp fulfill];
    }];
    [[self getCSPCOSXMLTransferService] UploadObject:put];
    [self waitForExpectationsWithTimeout:100 handler:^(NSError * _Nullable error) {
    }];
    XCTAssertNotNil(result);
    XCTAssertNotNil([result location]);
    
    XCTestExpectation* exp1 = [self expectationWithDescription:@"GetPresignedURL"];
    QCloudGetPresignedURLRequest *request = [QCloudGetPresignedURLRequest new];
    request.bucket = put.bucket;
    request.object = put.object;
    request.HTTPMethod = @"PUT";
    [request setFinishBlock:^(QCloudGetPresignedURLResult * _Nonnull result, NSError * _Nonnull error) {
        NSLog(@"presienedURL :  %@",result.presienedURL);
        [exp1 fulfill];
    }];
    [[self getCSPCOSXMLService]getPresignedURL:request];
    [self waitForExpectationsWithTimeout:100 handler:nil];
}
-(void)testAbortMutipart{
    QCloudCOSXMLUploadObjectRequest* put = [QCloudCOSXMLUploadObjectRequest new];
    int randomNumber = arc4random()%100;
    NSURL* url = [NSURL fileURLWithPath:[self tempFileWithSize:304*1024*1024 + randomNumber]];
    put.object = [NSUUID UUID].UUIDString;
    put.bucket = self.bucket;
    put.body =  url;
    
    XCTestExpectation* exp = [self expectationWithDescription:@"UploadObject exp"];
    __block QCloudUploadObjectResult* result;
    [put setFinishBlock:^(id outputObject, NSError *error) {
        result = outputObject;
        [exp fulfill];
    }];
    
    [put setInitMultipleUploadFinishBlock:^(QCloudInitiateMultipartUploadResult *multipleUploadInitResult, QCloudCOSXMLUploadObjectResumeData resumeData) {
        XCTAssertNotNil(multipleUploadInitResult.uploadId,@"UploadID is null!");
        
        QCloudCOSXMLUploadObjectRequest* uploadObjectRequest = [QCloudCOSXMLUploadObjectRequest requestWithRequestData:resumeData];
        XCTAssertNotNil([uploadObjectRequest valueForKey:@"uploadId"],@"request produce from resume data is nil!");
        NSLog(@"pause here");
        
    }];
    [put setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"upload %lld totalSend %lld aim %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
    }];
    [[self getCSPCOSXMLTransferService] UploadObject:put];
    
    XCTestExpectation* hintExp = [self expectationWithDescription:@"abort"];
    __block id abortResult = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [put abort:^(id outputObject, NSError *error) {
            abortResult = outputObject;
            XCTAssertNil(error,@"Abort error is not nil! it is %@",error);
            [hintExp fulfill];
        }];
        
    });
    [self waitForExpectationsWithTimeout:100000 handler:nil];
    XCTAssertNotNil(abortResult);
}
- (void)testPutObjectCopy {
    NSString* copyObjectSourceName = @"1111copy";
    QCloudPutObjectRequest* put = [QCloudPutObjectRequest new];
    put.object = copyObjectSourceName;
    put.bucket = self.bucket;
    put.body =  [@"4324ewr325" dataUsingEncoding:NSUTF8StringEncoding];
    __block XCTestExpectation* exception = [self expectationWithDescription:@"Put Object Copy Exception"];
    __block NSError* putObjectCopyError;
    __block NSError* resultError;
    __block QCloudCopyObjectResult* copyObjectResult;
    [put setFinishBlock:^(id outputObject, NSError *error) {
        NSURL* serviceURL = [[self getCSPCOSXMLService].configuration.endpoint serverURLWithBucket:self.bucket appID:kAppID regionName:put.regionName];
        NSMutableString* objectCopySource = [serviceURL.absoluteString mutableCopy] ;
        [objectCopySource appendFormat:@"/%@",copyObjectSourceName];
        objectCopySource = [[objectCopySource substringFromIndex:7] mutableCopy];
        QCloudPutObjectCopyRequest* request = [[QCloudPutObjectCopyRequest alloc] init];
        request.bucket = ktestCopyDesBucket;
        request.object = @"1111copy";
        request.objectCopySource = objectCopySource;
        [request setFinishBlock:^(QCloudCopyObjectResult* result, NSError* error) {
            putObjectCopyError = result;
            resultError = error;
            [exception fulfill];
        }];
        [[self getCSPCOSXMLService] PutObjectCopy:request];
    }];
    [[self getCSPCOSXMLService] PutObject:put];
    [self waitForExpectationsWithTimeout:100 handler:nil];
    XCTAssertNil(resultError);
    
}

//如果使用该接口的接口进行copy，文件大小不可以超过5MB，因为CSP目前不支持分片上传，如果文件大小超过了5MBm，该接口就会走分块copy的逻辑，从而造成scopy失败
- (void)testMultiplePutObjectCopy {
    
    NSString* tempBucket = self.bucket;
    
    XCTestExpectation* uploadExpectation = [self expectationWithDescription:@"upload temp object"];
    QCloudCOSXMLUploadObjectRequest* uploadObjectRequest = [[QCloudCOSXMLUploadObjectRequest alloc] init];
    NSString* tempFileName =  @"5MBBigFile";
    uploadObjectRequest.bucket = tempBucket;
    uploadObjectRequest.object = tempFileName;
    uploadObjectRequest.body = [NSURL fileURLWithPath:[self tempFileWithSize:5*1024*1024]];
    [uploadObjectRequest setFinishBlock:^(QCloudUploadObjectResult *result, NSError *error) {
        XCTAssertNil(error,@"error occures on uploading");
        [uploadExpectation fulfill];
    }];
    [[self getCSPCOSXMLTransferService] UploadObject:uploadObjectRequest];
    [self waitForExpectationsWithTimeout:80 handler:nil];
    
    QCloudCOSXMLCopyObjectRequest* request = [[QCloudCOSXMLCopyObjectRequest alloc] init];
    
    request.bucket = ktestCSPBucket;
    request.object = @"copy-5MBBigFile";
    request.sourceBucket = tempBucket;
    request.sourceObject = tempFileName;
    request.sourceAPPID = [self getCSPCOSXMLTransferService].configuration.appID;
    request.sourceRegion= [self getCSPCOSXMLTransferService].configuration.endpoint.regionName;
    
    XCTestExpectation* expectation = [self expectationWithDescription:@"Put Object Copy"];
    [request setFinishBlock:^(QCloudCopyObjectResult* result, NSError* error) {
        XCTAssert(result);
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [request setCopyProgressBlock:^(int64_t partsSent, int64_t totalPartsExpectedToSent) {
        NSLog(@"partsSent: %lld totalPartsExpectedToSent:%lld",partsSent,totalPartsExpectedToSent);
    }];
    [[self getCSPCOSXMLTransferService] CopyObject:request];
    [self waitForExpectationsWithTimeout:10000 handler:nil];
    
}

- (void) testInitMultipartUpload {
    QCloudInitiateMultipartUploadRequest* initrequest = [QCloudInitiateMultipartUploadRequest new];
    initrequest.bucket = self.bucket;
    initrequest.object = [NSUUID UUID].UUIDString;
    
    XCTestExpectation* exp = [self expectationWithDescription:@"delete"];
    __block QCloudInitiateMultipartUploadResult* initResult;
    [initrequest setFinishBlock:^(QCloudInitiateMultipartUploadResult* outputObject, NSError *error) {
        initResult = outputObject;
        [exp fulfill];
    }];
    
    [[self getCSPCOSXMLService] InitiateMultipartUpload:initrequest];
    
    [self waitForExpectationsWithTimeout:80 handler:^(NSError * _Nullable error) {
    }];
    XCTAssert([initResult.bucket isEqualToString:self.bucket]);
    XCTAssert([initResult.key isEqualToString:initrequest.object]);
    
}


//批量删除对象
-(void)testMutiDelObjects{
    QCloudCOSXMLUploadObjectRequest* put = [QCloudCOSXMLUploadObjectRequest new];
    int randomNumber = arc4random()%100;
    NSURL* url = [NSURL fileURLWithPath:[self tempFileWithSize:2*1024*1024]];
    put.object = @"test1";
    put.bucket = kTestMuti_Del_Object_Bucket;
    put.body =  url;
    [put setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"upload %lld totalSend %lld aim %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
    }];
    XCTestExpectation* exp = [self expectationWithDescription:@"upload test1"];
    __block QCloudUploadObjectResult* result;
    [put setFinishBlock:^(id outputObject, NSError *error) {
        XCTAssertNil(error);
        [exp fulfill];
    }];
    [[self getCSPCOSXMLTransferService] UploadObject:put];
    
    QCloudCOSXMLUploadObjectRequest* put1 = [QCloudCOSXMLUploadObjectRequest new];
    int randomNumber1 = arc4random()%100;
    NSURL* url1 = [NSURL fileURLWithPath:[self tempFileWithSize:3*1024*1024]];
    put1.object = @"test2";
    put1.bucket = kTestMuti_Del_Object_Bucket;
    put1.body =  url1;
    [put1 setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"upload %lld totalSend %lld aim %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
    }];
    [put setFinishBlock:^(id outputObject, NSError *error) {
        XCTAssertNil(error);
        
        __block NSArray<QCloudBucketContents*>* listBucketContents;
        QCloudGetBucketRequest* getBucketRequest = [[QCloudGetBucketRequest alloc] init];
        getBucketRequest.bucket = kTestMuti_Del_Object_Bucket;
        getBucketRequest.maxKeys = 500;
        //批量删除对象
        QCloudDeleteMultipleObjectRequest* deleteMultipleObjectRequest = [[QCloudDeleteMultipleObjectRequest alloc] init];
        deleteMultipleObjectRequest.bucket = kTestMuti_Del_Object_Bucket;
        [getBucketRequest setFinishBlock:^(QCloudListBucketResult * _Nonnull result, NSError * _Nonnull error) {
            XCTAssertNil(error);
            XCTAssertNotNil(result.contents);
            listBucketContents = result.contents;
            
            deleteMultipleObjectRequest.deleteObjects = [[QCloudDeleteInfo alloc] init];
            NSMutableArray* deleteObjectInfoArray = [[NSMutableArray alloc] init];
            for (QCloudBucketContents* bucketContents in listBucketContents) {
                QCloudDeleteObjectInfo* objctInfo = [[QCloudDeleteObjectInfo alloc] init];
                objctInfo.key = bucketContents.key;
                [deleteObjectInfoArray addObject:objctInfo];
            }
            deleteMultipleObjectRequest.deleteObjects.objects = [deleteObjectInfoArray copy];
            [deleteMultipleObjectRequest setFinishBlock:^(QCloudDeleteResult * _Nonnull result, NSError * _Nonnull error) {
                if (error == nil) {
                    NSLog(@"Delete ALL Object Success!");
                } else {
                    NSLog(@"Delete all object fail! error:%@",error);
                }
                XCTAssertNil(error);
                [exp fulfill];
            }];
            [[self getCSPCOSXMLService] DeleteMultipleObject:deleteMultipleObjectRequest];
            
        }];
        [[self getCSPCOSXMLService] GetBucket:getBucketRequest];
        
    }];
    [[self getCSPCOSXMLTransferService] UploadObject:put1];
    [self waitForExpectationsWithTimeout:500 handler:^(NSError * _Nullable error) {
    }];
    
}
@end
