//
//  PubNub.m
//  pubnub
//
//  This is base and main class which is
//  responsible for communication with
//  PubNub services and handle all events
//  and notifications.
//
//
//  Created by Sergey Mamontov.
//
//

#import "PubNub+Protected.h"
#import "PNObservationCenter+Protected.h"
#import "PNConnectionChannelDelegate.h"
#import "PNPresenceEvent+Protected.h"
#import "PNConfiguration+Protected.h"
#import "PNServiceChannelDelegate.h"
#import "PNConnection+Protected.h"
#import "PNHereNow+Protected.h"
#import "PNMessage+Protected.h"
#import "PNChannel+Protected.h"
#import "PNMessagingChannel.h"
#import "PNError+Protected.h"
#import "PNServiceChannel.h"
#import "PNRequestsImport.h"
#import "PNHereNowRequest.h"
#import "PNCryptoHelper.h"


#pragma mark Static

// Stores reference on singleton PubNub instance
static PubNub *_sharedInstance = nil;

// Stores reference on list of invocation instances which is used to
// support synchronous library methods call (connect/disconnect/subscribe/unsubscribe)
static NSMutableArray *pendingInvocations = nil;


#pragma mark - Private interface methods

@interface PubNub () <PNConnectionChannelDelegate, PNMessageChannelDelegate, PNServiceChannelDelegate>


#pragma mark - Properties

// Stores reference on flag which specufy whether client
// identifier was passed by user or generated on demand
@property (nonatomic, assign, getter = isUserProvidedClientIdentifier) BOOL userProvidedClientIdentifier;

// Stores whether client should connect as soon as services
// will be checked for reachability
@property (nonatomic, assign, getter = shouldConnectOnServiceReachabilityCheck) BOOL connectOnServiceReachabilityCheck;

// Stores whether client is restoring connection after
// network failure or not
@property (nonatomic, assign, getter = isRestoringConnection) BOOL restoringConnection;

// Stores reference on configuration which was used to
// perform initial PubNub client initialization
@property (nonatomic, strong) PNConfiguration *temporaryConfiguration;

// Reference on channels which is used to communicate
// with PubNub service
@property (nonatomic, strong) PNMessagingChannel *messagingChannel;

// Stores reference on client delegate
@property (nonatomic, pn_desired_weak) id<PNDelegate> delegate;

// Stores unique client initialization session identifier
// (created each time when PubNub stack is configured
// after application launch)
@property (nonatomic, strong) NSString *launchSessionIdentifier;

// Reference on channels which is used to send service
// messages to PubNub service
@property (nonatomic, strong) PNServiceChannel *serviceChannel;

// Stores reference on configuration which was used to
// perform initial PubNub client initialization
@property (nonatomic, strong) PNConfiguration *configuration;

// Stores reference on service reachability monitoring
// instance
@property (nonatomic, strong) PNReachability *reachability;

// Stores reference on current client identifier
@property (nonatomic, strong) NSString *clientIdentifier;

// Stores current client state
@property (nonatomic, assign) PNPubNubClientState state;

// Stores whether library is performing one of async locking
// methods or not (if yes, other calls will be placed into pending set)
@property (nonatomic, assign, getter = isAsyncLockingOperationInProgress) BOOL asyncLockingOperationInProgress;


#pragma mark - Class methods

#pragma mark - Client connection management methods

+ (void)postponeConnectWithSuccessBlock:(PNClientConnectionSuccessBlock)success
                             errorBlock:(PNClientConnectionFailureBlock)failure;
+ (void)postponeDisconnect;
+ (void)disconnectForConfigurationChange;
+ (void)postponeDisconnectForConfigurationChange;


#pragma mark - Client identification

+ (void)postponeSetClientIdentifier:(NSString *)identifier;


#pragma mark - Channels subscription management

+ (void)postponeSubscribeOnChannels:(NSArray *)channels
                  withPresenceEvent:(BOOL)withPresenceEvent
         andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock;

+ (void)postponeUnsubscribeFromChannels:(NSArray *)channels
                      withPresenceEvent:(BOOL)withPresenceEvent
             andCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock;


#pragma mark - Presence management

+ (void)postponeEnablePresenceObservationForChannels:(NSArray *)channels;
+ (void)postponeDisablePresenceObservationForChannels:(NSArray *)channels;


#pragma mark - Time token

+ (void)postponeRequestServerTimeTokenWithCompletionBlock:(PNClientTimeTokenReceivingCompleteBlock)success;


#pragma mark - Messages processing methods

+ (PNMessage *)postponeSendMessage:(id)message
                         toChannel:(PNChannel *)channel
               withCompletionBlock:(PNClientMessageProcessingBlock)success;


#pragma mark - History methods

+ (void)postponeRequestHistoryForChannel:(PNChannel *)channel
                                    from:(NSDate *)startDate
                                      to:(NSDate *)endDate
                                   limit:(NSUInteger)limit
                          reverseHistory:(BOOL)shouldReverseMessageHistory
                     withCompletionBlock:(PNClientHistoryLoadHandlingBlock)handleBlock;


#pragma mark - Participant methods

+ (void)postponeRequestParticipantsListForChannel:(PNChannel *)channel
                              withCompletionBlock:(PNClientParticipantsHandlingBlock)handleBlock;


#pragma mark - Misc methods

/**
 * Allow to perform code which should lock asynchronous methods
 * execution till it ends and in case if code itself should be
 * postponed, corresponding block is passed.
 */
+ (void)performAsyncLockingBlock:(void(^)(void))codeBlock postponedExecutionBlock:(void(^)(void))postponedCodeBlock;


#pragma mark - Instance methods

#pragma mark - Client connection management methods

/**
 * Configure client connection state observer with 
 * handling blocks
 */
- (void)setClientConnectionObservationWithSuccessBlock:(PNClientConnectionSuccessBlock)success
                                          failureBlock:(PNClientConnectionFailureBlock)failure;

/**
 * This method allow to schedule initial requests on
 * connections to tell server that we are really
 * interested in persistent connection
 */
- (void)warmUpConnection;


#pragma mark - Requests management methods

/**
 * Sends message over corresponding communication
 * channel
 */
- (void)sendRequest:(PNBaseRequest *)request shouldObserveProcessing:(BOOL)shouldObserveProcessing;;

/**
 * Send message over specified communication channel
 */
- (void)    sendRequest:(PNBaseRequest *)request
              onChannel:(PNConnectionChannel *)channel
shouldObserveProcessing:(BOOL)shouldObserveProcessing;


#pragma mark - Handler methods

/**
 * Handling error which occurred while PubNub client
 * tried establish connection and lost internet connection
 */
- (void)handleConnectionErrorOnNetworkFailure;

/**
 * Handle locking operation completino and pop new one from
 * pending invocations list.
 */
- (void)handleLockingOperationComplete:(BOOL)shouldStartNext;


#pragma mark - Misc methods

/**
 * Will prepare crypto helper it is possible
 */
- (void)prepareCryptoHelper;

/**
 * Check whether whether call to specific method should be postponed
 * or not. This will allot to perform synchronous call on specific
 * library methods.
 */
- (BOOL)shouldPostponeMethodCall;

/**
 * Place selector into list of postponed calls with corresponding parameters
 * If 'placeOutOfOrder' is specified, selectore will be placed first in FIFO
 * queue and will be executed as soon as it will be possible.
 */
- (void)postponeSelector:(SEL)calledMethodSelector
               forObject:(id)object
          withParameters:(NSArray *)parameters
              outOfOrder:(BOOL)placeOutOfOrder;

/**
 * This method will notify delegate about that
 * connection to the PubNub service is established
 * and send notification about it
 */
- (void)notifyDelegateAboutConnectionToOrigin:(NSString *)originHostName;

/**
 * This method will notify delegate about that
 * subscription failed with error
 */
- (void)notifyDelegateAboutSubscriptionFailWithError:(PNError *)error;

/**
 * This method will notify delegate about that
 * unsubscription failed with error
 */
- (void)notifyDelegateAboutUnsubscriptionFailWithError:(PNError *)error;

/**
 * This method will notify delegate about that
 * time token retrieval failed because of error
 */
- (void)notifyDelegateAboutTimeTokenRetrievalFailWithError:(PNError *)error;

/**
 * This method will notify delegate about that
 * message sending failed because of error
 */
- (void)notifyDelegateAboutMessageSendingFailedWithError:(PNError *)error;

/**
 * This method will notify delegate about that
 * history loading error occurred
 */
- (void)notifyDelegateAboutHistoryDownloadFailedWithError:(PNError *)error;

/**
 * This method will notify delegate about that
 * participants list download error occurred
 */
- (void)notifyDelegateAboutParticipantsListDownloadFailedWithError:(PNError *)error;

/**
 * This method allow to ensure that delegate can
 * process errors and will send error to the
 * delegate
 */
- (void)notifyDelegateAboutError:(PNError *)error;

/**
 * This method allow notify delegate that client is about to close
 * connection because of speficied error
 */
- (void)notifyDelegateClientWillDisconnectWithError:(PNError *)error;

- (void)sendNotification:(NSString *)notificationName withObject:(id)object;

/**
 * Check whether client should restore connection after
 * network went down and restored now
 */
- (BOOL)shouldRestoreConnection;

/**
 * Retrieve request execution possibility code.
 * If everything is fine, than 0 will be returned, in
 * other case it will be treated as error and mean
 * that request execution is impossible
 */
- (NSInteger)requestExecutionPossibilityStatusCode;


@end


#pragma mark - Public interface methods

@implementation PubNub


#pragma mark - Class methods

+ (PubNub *)sharedInstance {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _sharedInstance = [[[self class] alloc] init];
    });
    
    
    return _sharedInstance;
}


#pragma mark - Client connection management methods

+ (void)connect {
    
    [self connectWithSuccessBlock:nil errorBlock:nil];
}

+ (void)connectWithSuccessBlock:(PNClientConnectionSuccessBlock)success
                     errorBlock:(PNClientConnectionFailureBlock)failure {

    __block BOOL shouldAddStateObservation = NO;
    __block BOOL methodCallPostponed = NO;

    // Check whether instance already connected or not
    if ([self sharedInstance].state == PNPubNubClientStateConnected ||
        [self sharedInstance].state == PNPubNubClientStateConnecting) {

        PNError *connectionError = [PNError errorWithCode:kPNClientTriedConnectWhileConnectedError];
        [[self sharedInstance] notifyDelegateAboutError:connectionError];
        
        if (failure) {

            failure(connectionError);
        }
    }
    else {
        
        // Check whether client configuration was provided
        // or not
        if ([self sharedInstance].configuration == nil) {

            PNError *connectionError = [PNError errorWithCode:kPNClientConfigurationError];
            [[self sharedInstance] notifyDelegateAboutError:connectionError];
            
            
            if(failure) {
                
                failure(connectionError);
            }
        }
        else {
            
            // Check whether user identifier was provided by
            // user or not
            if(![self sharedInstance].isUserProvidedClientIdentifier) {
                
                // Change user identifier before connect to the
                // PubNub services
                [self sharedInstance].clientIdentifier = PNUniqueIdentifier();
            }
            
            
            [self sharedInstance].connectOnServiceReachabilityCheck = NO;
            
            
            // Check whether services are available or not
            if ([[self sharedInstance].reachability isServiceReachabilityChecked]) {

                // Checking whether remote PubNub services is reachable or not
                // (if they are not reachable, this mean that probably there is no
                // connection)
                if ([[self sharedInstance].reachability isServiceAvailable]) {

                    [self performAsyncLockingBlock:^{

                        // Notify PubNub delegate about that it will try to
                        // establish connection with remote PubNub origin
                        // (notify if delegate implements this method)
                        if ([[self sharedInstance].delegate respondsToSelector:@selector(pubnubClient:willConnectToOrigin:)]) {

                            [[self sharedInstance].delegate performSelector:@selector(pubnubClient:willConnectToOrigin:)
                                                                 withObject:[self sharedInstance]
                                                                 withObject:[self sharedInstance].configuration.origin];
                        }

                        [[self sharedInstance] sendNotification:kPNClientWillConnectToOriginNotification
                                                     withObject:[self sharedInstance].configuration.origin];


                        // Check whether PubNub client was just created and there
                        // is no resources for reuse or not
                        if ([self sharedInstance].state == PNPubNubClientStateCreated ||
                            [self sharedInstance].state == PNPubNubClientStateDisconnected) {

                            [self sharedInstance].state = PNPubNubClientStateConnecting;

                            // Initialize communication channels
                            [self sharedInstance].messagingChannel = [PNMessagingChannel messageChannelWithDelegate:[self sharedInstance]];
                            [self sharedInstance].messagingChannel.messagingDelegate = [self sharedInstance];
                            [self sharedInstance].serviceChannel = [PNServiceChannel serviceChannelWithDelegate:[self sharedInstance]];
                            [self sharedInstance].serviceChannel.serviceDelegate = [self sharedInstance];
                        }
                        else {

                            [self sharedInstance].state = PNPubNubClientStateConnecting;


                            // Reuse existing communication channels and reconnect
                            // them to remote origin server
                            [[self sharedInstance].messagingChannel connect];
                            [[self sharedInstance].serviceChannel connect];
                        }

                        shouldAddStateObservation = YES;
                    }
                           postponedExecutionBlock:^{

                               [self postponeConnectWithSuccessBlock:success errorBlock:failure];
                               methodCallPostponed = YES;
                           }];
                }
                else {
                    
                    // Mark that client should try to connect when network will be available
                    // again
                    [self sharedInstance].connectOnServiceReachabilityCheck = YES;
                    
                    [[self sharedInstance] handleConnectionErrorOnNetworkFailure];
                    
                    
                    if(failure) {
                        
                        failure([PNError errorWithCode:kPNClientConnectionFailedOnInternetFailureError]);
                    }
                }
            }
            // Looks like reachability manager was unable to check services reachability
            // (user still not configured client or just not enough time to check passed
            // since client configuration)
            else {
                
                [self sharedInstance].connectOnServiceReachabilityCheck = YES;
                
                shouldAddStateObservation = YES;
            }
        }
    }

    if (!methodCallPostponed) {

        [self sharedInstance].asyncLockingOperationInProgress = YES;


        // Remove PubNub client from connection state observers list
        [[PNObservationCenter defaultCenter] removeClientConnectionStateObserver:self oneTimeEvent:YES];


        if (shouldAddStateObservation) {

            // Subscribe and wait for client connection state change notification
            [[self sharedInstance] setClientConnectionObservationWithSuccessBlock:success failureBlock:failure];
        }
    }
}

+ (void)postponeConnectWithSuccessBlock:(PNClientConnectionSuccessBlock)success
                             errorBlock:(PNClientConnectionFailureBlock)failure {

    [[self sharedInstance] postponeSelector:@selector(connectWithSuccessBlock:errorBlock:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(success), PNNillIfNotSet(failure)]
                                 outOfOrder:NO];
}

+ (void)disconnect {

    [self performAsyncLockingBlock:^{

        // Remove PubNub client from list which help to observe various events
        [[PNObservationCenter defaultCenter] removeClientConnectionStateObserver:self oneTimeEvent:YES];
        if ([self sharedInstance].state != PNPubNubClientStateDisconnectingOnConfigurationChange) {

            [[PNObservationCenter defaultCenter] removeClientAsTimeTokenReceivingObserver];
            [[PNObservationCenter defaultCenter] removeClientAsMessageProcessingObserver];
            [[PNObservationCenter defaultCenter] removeClientAsSubscriptionObserver];
            [[PNObservationCenter defaultCenter] removeClientAsUnsubscribeObserver];

            [[self sharedInstance].configuration shouldKillDNSCache:NO];
        }

        // Check whether client disconnected at this moment (maybe previously was
        // disconnected because connection loss)
        BOOL isDisconnected = ![[self sharedInstance] isConnected];

        // Check whether should update state to 'disconnecting'
        if (!isDisconnected) {

            // Mark that client is disconnecting from remote PubNub services on
            // user request (or by internal client request when updating configuration)
            [self sharedInstance].state = PNPubNubClientStateDisconnecting;
        }

        // Reset client runtime flags and properties
        [self sharedInstance].connectOnServiceReachabilityCheck = NO;
        [self sharedInstance].restoringConnection = NO;


        // Empty connection pool after connection will
        // be closed
        [PNConnection closeAllConnections];


        // Destroy communication channels
        [self sharedInstance].messagingChannel = nil;
        [self sharedInstance].serviceChannel = nil;
    }
           postponedExecutionBlock:^{

               [self postponeDisconnect];
           }];
}

+ (void)postponeDisconnect {

    BOOL outOfOrder = [self sharedInstance].state == PNPubNubClientStateDisconnectingOnConfigurationChange;

    [[self sharedInstance] postponeSelector:@selector(disconnect) forObject:self withParameters:nil outOfOrder:outOfOrder];
}

+ (void)disconnectForConfigurationChange {

    [self performAsyncLockingBlock:^{

        // Mark that client is closing connection because of settings update
        [self sharedInstance].state = PNPubNubClientStateDisconnectingOnConfigurationChange;


        // Empty connection pool after connection will
        // be closed
        [PNConnection closeAllConnections];
    }
           postponedExecutionBlock:^{

               [self postponeDisconnectForConfigurationChange];
           }];
}

+ (void)postponeDisconnectForConfigurationChange {

    [[self sharedInstance] postponeSelector:@selector(disconnectForConfigurationChange)
                                  forObject:self
                             withParameters:nil
                                 outOfOrder:NO];
}


#pragma mark - Client configuration methods

+ (void)setConfiguration:(PNConfiguration *)configuration {
    
    [self setupWithConfiguration:configuration andDelegate:[self sharedInstance].delegate];
}

+ (void)setupWithConfiguration:(PNConfiguration *)configuration andDelegate:(id<PNDelegate>)delegate {
    
    // Ensure that configuration is valid before update/set
    // client configuration to it
    if ([configuration isValid]) {
        
        [self setDelegate:delegate];


        BOOL canUpdateConfiguration = YES;

        // Check whether PubNub client is connected to remote
        // PubNub services or not
        if ([[self sharedInstance] isConnected]) {

            // Check whether new configuration changed critical properties
            // of client configuration or not
            if([[self sharedInstance].configuration requiresConnectionResetWithConfiguration:configuration]) {

                canUpdateConfiguration = NO;

                // Store new configuration while client is disconnecting
                [self sharedInstance].temporaryConfiguration = configuration;


                // Disconnect before client configuration update
                [self disconnectForConfigurationChange];
            }
        }

        if (canUpdateConfiguration) {

            [self sharedInstance].configuration = configuration;
            
            [[self sharedInstance] prepareCryptoHelper];
        }
        
        
        // Restart reachability monitor
        [[self sharedInstance].reachability startServiceReachabilityMonitoring];
    }
    else {
        
        // Notify delegate about client configuration error
        [[self sharedInstance] notifyDelegateAboutError:[PNError errorWithCode:kPNClientConfigurationError]];
    }
}

+ (void)setDelegate:(id<PNDelegate>)delegate {
    
    [self sharedInstance].delegate = delegate;
}


#pragma mark - Client identification methods

+ (void)setClientIdentifier:(NSString *)identifier {

    // Check whether identifier has been changed since last
    // method call or not
    if ([[self sharedInstance] isConnected]) {

        // Checking whether new identifier was provided or not
        NSString *clientIdentifier = [self sharedInstance].clientIdentifier;
        if (![clientIdentifier isEqualToString:identifier]) {

            [self performAsyncLockingBlock:^{

                [self sharedInstance].userProvidedClientIdentifier = identifier != nil;


                NSArray *allChannels = [[self sharedInstance].messagingChannel fullSubscribedChannelsList];
                [self unsubscribeFromChannels:allChannels
                            withPresenceEvent:YES
                   andCompletionHandlingBlock:^(NSArray *leavedChannels, PNError *leaveError) {

                       if (leaveError == nil) {

                           // Check whether user identifier was provided by
                           // user or not
                           if (identifier == nil) {

                               // Change user identifier before connect to the
                               // PubNub services
                               [self sharedInstance].clientIdentifier = PNUniqueIdentifier();
                           }
                           else {

                               [self sharedInstance].clientIdentifier = identifier;
                           }

                           [self subscribeOnChannels:allChannels
                                   withPresenceEvent:YES
                          andCompletionHandlingBlock:^(PNSubscriptionProcessState state,
                                  NSArray *subscribedChannels,
                                  PNError *subscribeError) {

                              [[self sharedInstance] handleLockingOperationComplete:YES];
                          }];
                       }
                       else {

                           [self subscribeOnChannels:allChannels withPresenceEvent:NO];
                       }
                   }];
            }
                   postponedExecutionBlock:^{

                       [self postponeSetClientIdentifier:identifier];
                   }];
        }
    }
    else {

        [self sharedInstance].clientIdentifier = identifier;
        [self sharedInstance].userProvidedClientIdentifier = identifier != nil;
    }
}

+ (void)postponeSetClientIdentifier:(NSString *)identifier {

    [[self sharedInstance] postponeSelector:@selector(setClientIdentifier:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(identifier)]
                                 outOfOrder:NO];
}

+ (NSString *)clientIdentifier {
    
    NSString *identifier = [self sharedInstance].clientIdentifier;
    if (identifier == nil) {
        
        [self sharedInstance].userProvidedClientIdentifier = NO;
    }
    
    
    return [self sharedInstance].clientIdentifier;
}

+ (NSString *)escapedClientIdentifier {

    return [[self clientIdentifier] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}


#pragma mark - Channels subscription management

+ (NSArray *)subscribedChannels {

    return [[self sharedInstance].messagingChannel subscribedChannels];
}

+ (BOOL)isSubscribedOnChannel:(PNChannel *)channel {

    BOOL isSubscribed = NO;

    // Ensure that PubNub client currently connected to
    // remote PubNub services
    if([[self sharedInstance] isConnected]) {

        isSubscribed = [[self sharedInstance].messagingChannel isSubscribedForChannel:channel];
    }


    return isSubscribed;
}

+ (void)subscribeOnChannel:(PNChannel *)channel {

    [self subscribeOnChannels:@[channel]];
}

+ (void) subscribeOnChannel:(PNChannel *)channel
withCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {

    [self subscribeOnChannels:@[channel] withCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannel:(PNChannel *)channel withPresenceEvent:(BOOL)withPresenceEvent {

    [self subscribeOnChannels:@[channel] withPresenceEvent:withPresenceEvent];
}

+ (void)subscribeOnChannel:(PNChannel *)channel
         withPresenceEvent:(BOOL)withPresenceEvent
andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {

    [self subscribeOnChannels:@[channel] withPresenceEvent:withPresenceEvent andCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannels:(NSArray *)channels {

    [self subscribeOnChannels:channels withCompletionHandlingBlock:nil];
}

+ (void)subscribeOnChannels:(NSArray *)channels
withCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {

    [self subscribeOnChannels:channels withPresenceEvent:YES andCompletionHandlingBlock:handlerBlock];
}

+ (void)subscribeOnChannels:(NSArray *)channels withPresenceEvent:(BOOL)withPresenceEvent {

    [self subscribeOnChannels:channels withPresenceEvent:withPresenceEvent andCompletionHandlingBlock:nil];
}

+ (void)subscribeOnChannels:(NSArray *)channels
          withPresenceEvent:(BOOL)withPresenceEvent
 andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {

    [[PNObservationCenter defaultCenter] removeClientAsSubscriptionObserver];
    [[PNObservationCenter defaultCenter] removeClientAsUnsubscribeObserver];

    [self performAsyncLockingBlock:^{

        // Check whether client is able to send request or not
        NSInteger statusCode = [[self sharedInstance] requestExecutionPossibilityStatusCode];
        if (statusCode == 0) {

            if (handlerBlock != nil) {

                [[PNObservationCenter defaultCenter] addClientAsSubscriptionObserverWithBlock:handlerBlock];
            }


            [[self sharedInstance].messagingChannel subscribeOnChannels:channels withPresenceEvent:withPresenceEvent];
        }
        // Looks like client can't send request because of some reasons
        else {

            PNError *subscriptionError = [PNError errorWithCode:statusCode];
            subscriptionError.associatedObject = channels;

            [[self sharedInstance] notifyDelegateAboutSubscriptionFailWithError:subscriptionError];


            if (handlerBlock) {

                handlerBlock(PNSubscriptionProcessNotSubscribedState, channels, subscriptionError);
            }
        }
    }
           postponedExecutionBlock:^{

               [self postponeSubscribeOnChannels:channels
                               withPresenceEvent:withPresenceEvent
                      andCompletionHandlingBlock:handlerBlock];
           }];
}

+ (void)postponeSubscribeOnChannels:(NSArray *)channels
                  withPresenceEvent:(BOOL)withPresenceEvent
         andCompletionHandlingBlock:(PNClientChannelSubscriptionHandlerBlock)handlerBlock {

    [[self sharedInstance] postponeSelector:@selector(subscribeOnChannels:withPresenceEvent:andCompletionHandlingBlock:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(channels),
                                              [NSNumber numberWithBool:withPresenceEvent],
                                              PNNillIfNotSet(handlerBlock)]
                                 outOfOrder:NO];
}

+ (void)unsubscribeFromChannel:(PNChannel *)channel {

    [self unsubscribeFromChannels:@[channel]];
}

+ (void)unsubscribeFromChannel:(PNChannel *)channel withPresenceEvent:(BOOL)withPresenceEvent {

    [self unsubscribeFromChannel:channel withPresenceEvent:withPresenceEvent andCompletionHandlingBlock:nil];
}

+ (void)unsubscribeFromChannel:(PNChannel *)channel
   withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {

    [self unsubscribeFromChannel:channel withPresenceEvent:YES andCompletionHandlingBlock:handlerBlock];
}

+ (void)unsubscribeFromChannel:(PNChannel *)channel
             withPresenceEvent:(BOOL)withPresenceEvent
    andCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {

    [self unsubscribeFromChannels:@[channel]
                withPresenceEvent:withPresenceEvent
       andCompletionHandlingBlock:handlerBlock];
}

+ (void)unsubscribeFromChannels:(NSArray *)channels {

    [self unsubscribeFromChannels:channels withPresenceEvent:YES];
}

+ (void)unsubscribeFromChannels:(NSArray *)channels withPresenceEvent:(BOOL)withPresenceEvent {

    [self unsubscribeFromChannels:channels withPresenceEvent:withPresenceEvent andCompletionHandlingBlock:nil];
}

+ (void)unsubscribeFromChannels:(NSArray *)channels
    withCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {

    [self unsubscribeFromChannels:channels withPresenceEvent:YES andCompletionHandlingBlock:handlerBlock];
}

+ (void)unsubscribeFromChannels:(NSArray *)channels
              withPresenceEvent:(BOOL)withPresenceEvent
     andCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {

    [[PNObservationCenter defaultCenter] removeClientAsSubscriptionObserver];
    [[PNObservationCenter defaultCenter] removeClientAsUnsubscribeObserver];

    [self performAsyncLockingBlock:^{

        // Check whether client is able to send request or not
        NSInteger statusCode = [[self sharedInstance] requestExecutionPossibilityStatusCode];
        if (statusCode == 0) {

            if (handlerBlock) {

                [[PNObservationCenter defaultCenter] addClientAsUnsubscribeObserverWithBlock:handlerBlock];
            }


            [[self sharedInstance].messagingChannel unsubscribeFromChannels:channels withPresenceEvent:withPresenceEvent];
        }
                // Looks like client can't send request because of some reasons
        else {

            PNError *unsubscriptionError = [PNError errorWithCode:statusCode];
            unsubscriptionError.associatedObject = channels;

            [[self sharedInstance] notifyDelegateAboutUnsubscriptionFailWithError:unsubscriptionError];


            if (handlerBlock) {

                handlerBlock(channels, unsubscriptionError);
            }
        }
    }
           postponedExecutionBlock:^{

               [self postponeUnsubscribeFromChannels:channels withPresenceEvent:withPresenceEvent andCompletionHandlingBlock:handlerBlock];
           }];
}

+ (void)postponeUnsubscribeFromChannels:(NSArray *)channels
                      withPresenceEvent:(BOOL)withPresenceEvent
             andCompletionHandlingBlock:(PNClientChannelUnsubscriptionHandlerBlock)handlerBlock {

    [[self sharedInstance] postponeSelector:@selector(unsubscribeFromChannels:withPresenceEvent:andCompletionHandlingBlock:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(channels),
                                             [NSNumber numberWithBool:withPresenceEvent],
                                             PNNillIfNotSet(handlerBlock)]
                                 outOfOrder:NO];
}


#pragma mark - Presence management

+ (BOOL)isPresenceObservationEnabledForChannel:(PNChannel *)channel {
    
    BOOL observingPresence = NO;

    // Ensure that PubNub client currently connected to
    // remote PubNub services
    if ([[self sharedInstance] isConnected]) {

        observingPresence = [[self sharedInstance].messagingChannel isPresenceObservationEnabledForChannel:channel];
    }
    
    
    return observingPresence;
}

+ (void)enablePresenceObservationForChannel:(PNChannel *)channel {

    [self enablePresenceObservationForChannels:@[channel]];
}

+ (void)enablePresenceObservationForChannels:(NSArray *)channels {

    [self performAsyncLockingBlock:^{

        // Enumerate over the list of channels and mark that it should observe for presence
        [channels enumerateObjectsUsingBlock:^(PNChannel *channel, NSUInteger channelIdx, BOOL *channelEnumeratorStop) {

            channel.observePresence = YES;
            channel.userDefinedPresenceObservation = YES;
        }];

        [[self sharedInstance].messagingChannel enablePresenceObservationForChannels:channels];

    }
            postponedExecutionBlock:^{

                [self postponeEnablePresenceObservationForChannels:channels];
            }];
}

+ (void)postponeEnablePresenceObservationForChannels:(NSArray *)channels {

    [[self sharedInstance] postponeSelector:@selector(enablePresenceObservationForChannels:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(channels)]
                                 outOfOrder:NO];
}

+ (void)disablePresenceObservationForChannel:(PNChannel *)channel {

    [self disablePresenceObservationForChannels:@[channel]];
}

+ (void)disablePresenceObservationForChannels:(NSArray *)channels {

    [self performAsyncLockingBlock:^{

        // Enumerate over the list of channels and mark that it should observe for presence
        [channels enumerateObjectsUsingBlock:^(PNChannel *channel, NSUInteger channelIdx, BOOL *channelEnumeratorStop) {

            channel.observePresence = NO;
            channel.userDefinedPresenceObservation = YES;
        }];

        [[self sharedInstance].messagingChannel disablePresenceObservationForChannels:channels];
    }
           postponedExecutionBlock:^{

               [self postponeDisablePresenceObservationForChannels:channels];
           }];
}

+ (void)postponeDisablePresenceObservationForChannels:(NSArray *)channels {

    [[self sharedInstance] postponeSelector:@selector(disablePresenceObservationForChannels:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(channels)]
                                 outOfOrder:NO];
}


#pragma mark - Time token

+ (void)requestServerTimeToken {

    [self requestServerTimeTokenWithCompletionBlock:nil];
}

+ (void)requestServerTimeTokenWithCompletionBlock:(PNClientTimeTokenReceivingCompleteBlock)success {

    [self performAsyncLockingBlock:^{
        // Check whether client is able to send request or not
        NSInteger statusCode = [[self sharedInstance] requestExecutionPossibilityStatusCode];
        if (statusCode == 0) {

            [[PNObservationCenter defaultCenter] removeClientAsTimeTokenReceivingObserver];
            if (success) {
                [[PNObservationCenter defaultCenter] addClientAsTimeTokenReceivingObserverWithCallbackBlock:success];
            }


            [[self sharedInstance] sendRequest:[PNTimeTokenRequest new] shouldObserveProcessing:YES];
        }
                // Looks like client can't send request because of some reasons
        else {

            PNError *timeTokenError = [PNError errorWithCode:statusCode];

            [[self sharedInstance] notifyDelegateAboutTimeTokenRetrievalFailWithError:timeTokenError];


            if (success) {

                success(nil, timeTokenError);
            }
        }
    }
           postponedExecutionBlock:^{

               [self postponeRequestServerTimeTokenWithCompletionBlock:success];
           }];
}

+ (void)postponeRequestServerTimeTokenWithCompletionBlock:(PNClientTimeTokenReceivingCompleteBlock)success {

    [[self sharedInstance] postponeSelector:@selector(requestServerTimeTokenWithCompletionBlock:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(success)]
                                 outOfOrder:NO];
}


#pragma mark - Messages processing methods

+ (PNMessage *)sendMessage:(id)message toChannel:(PNChannel *)channel {

    return [self sendMessage:message toChannel:channel withCompletionBlock:nil];
}

+ (PNMessage *)sendMessage:(id)message
                 toChannel:(PNChannel *)channel
       withCompletionBlock:(PNClientMessageProcessingBlock)success {

    // Create object instance
    PNError *error = nil;
    PNMessage *messageObject = [PNMessage messageWithObject:message forChannel:channel error:&error];

    [self performAsyncLockingBlock:^{

        // Check whether client is able to send request or not
        NSInteger statusCode = [[self sharedInstance] requestExecutionPossibilityStatusCode];
        if (statusCode == 0) {

            [[PNObservationCenter defaultCenter] removeClientAsMessageProcessingObserver];
            if (success) {

                [[PNObservationCenter defaultCenter] addClientAsMessageProcessingObserverWithBlock:success];
            }

            [[self sharedInstance].serviceChannel sendMessage:messageObject];
        }
        // Looks like client can't send request because of some reasons
        else {

            PNError *sendingError = [PNError errorWithCode:statusCode];
            sendingError.associatedObject = messageObject;

            [[self sharedInstance] notifyDelegateAboutMessageSendingFailedWithError:sendingError];


            if (success) {

                success(PNMessageSendingError, sendingError);
            }
        }
    }
           postponedExecutionBlock:^{

               [self postponeSendMessage:message toChannel:channel withCompletionBlock:success];
           }];


    return messageObject;
}

+ (PNMessage *)postponeSendMessage:(id)message
                         toChannel:(PNChannel *)channel
               withCompletionBlock:(PNClientMessageProcessingBlock)success {

    //@[PNNillIfNotSet(message), PNNillIfNotSet(channel), PNNillIfNotSet((id)success)]
    NSArray *parameters = @[(message?message:[NSNull null]), (channel?channel:[NSNull null]), (success?(id)success:[NSNull null])];
    NSLog(@"PARAMETERS: %@", parameters);
    [[self sharedInstance] postponeSelector:@selector(sendMessage:toChannel:withCompletionBlock:)
                                  forObject:self
                             withParameters:parameters
                                 outOfOrder:NO];
}

+ (void)sendMessage:(PNMessage *)message {

    [self sendMessage:message withCompletionBlock:nil];
}

+ (void)sendMessage:(PNMessage *)message withCompletionBlock:(PNClientMessageProcessingBlock)success {

    [self sendMessage:message.message toChannel:message.channel withCompletionBlock:success];
}


#pragma mark - History methods

+ (void)requestFullHistoryForChannel:(PNChannel *)channel {

    [self requestFullHistoryForChannel:channel withCompletionBlock:nil];
}

+ (void)requestFullHistoryForChannel:(PNChannel *)channel
                 withCompletionBlock:(PNClientHistoryLoadHandlingBlock)handleBlock {

    [self requestHistoryForChannel:channel from:nil to:nil withCompletionBlock:handleBlock];
}

+ (void)requestHistoryForChannel:(PNChannel *)channel from:(NSDate *)startDate to:(NSDate *)endDate {

    [self requestHistoryForChannel:channel from:startDate to:endDate withCompletionBlock:nil];
}

+ (void)requestHistoryForChannel:(PNChannel *)channel
                            from:(NSDate *)startDate
                              to:(NSDate *)endDate
             withCompletionBlock:(PNClientHistoryLoadHandlingBlock)handleBlock {

    [self requestHistoryForChannel:channel from:startDate to:endDate limit:0 withCompletionBlock:handleBlock];
}

+ (void)requestHistoryForChannel:(PNChannel *)channel
                            from:(NSDate *)startDate
                              to:(NSDate *)endDate
                           limit:(NSUInteger)limit {

    [self requestHistoryForChannel:channel from:startDate to:endDate limit:limit withCompletionBlock:nil];
}

+ (void)requestHistoryForChannel:(PNChannel *)channel
                            from:(NSDate *)startDate
                              to:(NSDate *)endDate
                           limit:(NSUInteger)limit
             withCompletionBlock:(PNClientHistoryLoadHandlingBlock)handleBlock {

    [self requestHistoryForChannel:channel
                              from:startDate
                                to:endDate
                             limit:limit
                    reverseHistory:NO
               withCompletionBlock:handleBlock];
}

+ (void)requestHistoryForChannel:(PNChannel *)channel
                            from:(NSDate *)startDate
                              to:(NSDate *)endDate
                           limit:(NSUInteger)limit
                  reverseHistory:(BOOL)shouldReverseMessageHistory {

    [self requestHistoryForChannel:channel
                              from:startDate
                                to:endDate
                             limit:limit
                    reverseHistory:shouldReverseMessageHistory
               withCompletionBlock:nil];
}

+ (void)requestHistoryForChannel:(PNChannel *)channel
                            from:(NSDate *)startDate
                              to:(NSDate *)endDate
                           limit:(NSUInteger)limit
                  reverseHistory:(BOOL)shouldReverseMessageHistory
             withCompletionBlock:(PNClientHistoryLoadHandlingBlock)handleBlock {

    [self performAsyncLockingBlock:^{

        // Check whether client is able to send request or not
        NSInteger statusCode = [[self sharedInstance] requestExecutionPossibilityStatusCode];
        if (statusCode == 0) {

            [[PNObservationCenter defaultCenter] removeClientAsHistoryDownloadObserver];
            if (handleBlock) {

                [[PNObservationCenter defaultCenter] addClientAsHistoryDownloadObserverWithBlock:handleBlock];
            }

            PNMessageHistoryRequest *request = [PNMessageHistoryRequest messageHistoryRequestForChannel:channel
                                                                                                   from:startDate
                                                                                                     to:endDate
                                                                                                  limit:limit
                                                                                         reverseHistory:shouldReverseMessageHistory];
            [[self sharedInstance] sendRequest:request shouldObserveProcessing:YES];
        }
                // Looks like client can't send request because of some reasons
        else {

            PNError *sendingError = [PNError errorWithCode:statusCode];
            sendingError.associatedObject = channel;

            [[self sharedInstance] notifyDelegateAboutHistoryDownloadFailedWithError:sendingError];
        }
    }
           postponedExecutionBlock:^{

               [self postponeRequestHistoryForChannel:channel
                                                 from:startDate
                                                   to:endDate
                                                limit:limit
                                       reverseHistory:shouldReverseMessageHistory
                                  withCompletionBlock:handleBlock];
           }];
}

+ (void)postponeRequestHistoryForChannel:(PNChannel *)channel
                                    from:(NSDate *)startDate
                                      to:(NSDate *)endDate
                                   limit:(NSUInteger)limit
                          reverseHistory:(BOOL)shouldReverseMessageHistory
                     withCompletionBlock:(PNClientHistoryLoadHandlingBlock)handleBlock {

    [[self sharedInstance] postponeSelector:@selector(requestHistoryForChannel:from:to:limit:reverseHistory:withCompletionBlock:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(channel),
                                              PNNillIfNotSet(startDate),
                                              PNNillIfNotSet(endDate),
                                              [NSNumber numberWithUnsignedInteger:limit],
                                              [NSNumber numberWithBool:shouldReverseMessageHistory],
                                              PNNillIfNotSet(handleBlock)]
                                 outOfOrder:NO];
}


#pragma mark - Participant methods

+ (void)requestParticipantsListForChannel:(PNChannel *)channel {

    [self requestParticipantsListForChannel:channel withCompletionBlock:nil];
}

+ (void)requestParticipantsListForChannel:(PNChannel *)channel
                      withCompletionBlock:(PNClientParticipantsHandlingBlock)handleBlock {

    [self performAsyncLockingBlock:^{

        // Check whether client is able to send request or not
        NSInteger statusCode = [[self sharedInstance] requestExecutionPossibilityStatusCode];
        if (statusCode == 0) {

            [[PNObservationCenter defaultCenter] removeClientAsParticipantsListDownloadObserver];
            if (handleBlock) {

                [[PNObservationCenter defaultCenter] addClientAsParticipantsListDownloadObserverWithBlock:handleBlock];
            }


            PNHereNowRequest *request = [PNHereNowRequest whoNowRequestForChannel:channel];
            [[self sharedInstance] sendRequest:request shouldObserveProcessing:YES];
        }
                // Looks like client can't send request because of some reasons
        else {

            PNError *sendingError = [PNError errorWithCode:statusCode];
            sendingError.associatedObject = channel;

            [[self sharedInstance] notifyDelegateAboutParticipantsListDownloadFailedWithError:sendingError];
        }
    }
           postponedExecutionBlock:^{

               [self postponeRequestParticipantsListForChannel:channel withCompletionBlock:handleBlock];
           }];
}

+ (void)postponeRequestParticipantsListForChannel:(PNChannel *)channel
                              withCompletionBlock:(PNClientParticipantsHandlingBlock)handleBlock {

    [[self sharedInstance] postponeSelector:@selector(requestParticipantsListForChannel:withCompletionBlock:)
                                  forObject:self
                             withParameters:@[PNNillIfNotSet(channel), PNNillIfNotSet(handleBlock)]
                                 outOfOrder:NO];
}


#pragma mark - Misc methods

+ (void)performAsyncLockingBlock:(void(^)(void))codeBlock postponedExecutionBlock:(void(^)(void))postponedCodeBlock {

    // Checking whether code can be executed right now or should be posponed
    if ([[self sharedInstance] shouldPostponeMethodCall]) {

        if (postponedCodeBlock) {

            postponedCodeBlock();
        }
    }
    else {

        if (codeBlock) {

            [self sharedInstance].asyncLockingOperationInProgress = YES;

            codeBlock();
        }
    }
}


#pragma mark - Instance methods

- (id)init {
    
    // Check whether initialization successful or not
    if((self = [super init])) {
        
        self.state = PNPubNubClientStateCreated;
        self.launchSessionIdentifier = PNUniqueIdentifier();
        self.reachability = [PNReachability serviceReachability];
        pendingInvocations = [NSMutableArray array];
        
        // Adding PubNub services availability observer
        __block __pn_desired_weak PubNub *weakSelf = self;
        self.reachability.reachabilityChangeHandleBlock = ^(BOOL connected) {

            PNLog(PNLogGeneralLevel, weakSelf, @"IS CONNECTED? %@ (STATE: %i)", connected?@"YES":@"NO", weakSelf.state);
            
            if (weakSelf.shouldConnectOnServiceReachabilityCheck) {

                if (connected) {

                    weakSelf.asyncLockingOperationInProgress = NO;

                    [[weakSelf class] connect];
                }
            }
            else {
                
                if (connected) {
                    
                    if (weakSelf.state == PNPubNubClientStateDisconnectedOnNetworkError) {
                        
                        // Check whether should restore connection or not
                        if([weakSelf shouldRestoreConnection]) {

                            weakSelf.restoringConnection = YES;
                            
                            [[weakSelf class] connect];
                        }
                    }
                }
                else {
                    
                    // Check whether PubNub client was connected or connecting right now
                    if (weakSelf.state == PNPubNubClientStateConnected || weakSelf.state == PNPubNubClientStateConnecting) {
                        
                        if (weakSelf.state == PNPubNubClientStateConnecting) {
                            
                            [weakSelf handleConnectionErrorOnNetworkFailure];
                        }
                        else {

                            PNError *connectionError = [PNError errorWithCode:kPNClientConnectionClosedOnInternetFailureError];
                            [weakSelf notifyDelegateClientWillDisconnectWithError:connectionError];
                            
                            weakSelf.state = PNPubNubClientStateDisconnectingOnNetworkError;
                            
                            // Disconnect communication channels because of
                            // network issues
                            [weakSelf.messagingChannel disconnectWithReset:NO];
                            [weakSelf.serviceChannel disconnect];
                        }
                    }
                }
            }
        };
    }
    
    
    return self;
}


#pragma mark - Client connection management methods

- (BOOL)isConnected {
    
    return self.state == PNPubNubClientStateConnected;
}

- (void)setClientConnectionObservationWithSuccessBlock:(PNClientConnectionSuccessBlock)success
                                          failureBlock:(PNClientConnectionFailureBlock)failure {
    
    // Check whether at least one of blocks has been provided and whether
    // PubNub client already subscribed on state change event or not
    if(![[PNObservationCenter defaultCenter] isSubscribedOnClientStateChange:self] && (success || failure)) {
    
        // Subscribing PubNub client for connection state observation
        // (as soon as event will occur PubNub client will be removed
        // from observers list)
        [[PNObservationCenter defaultCenter] addClientConnectionStateObserver:self
                                                                 oneTimeEvent:YES
                                                            withCallbackBlock:^(NSString *origin,
                                                                                BOOL connected,
                                                                                PNError *connectionError) {
                                                                
            // Notify subscriber via blocks
            if (connected && success) {
                
                success(origin);
            }
            else if (!connected && failure){
                
                failure(connectionError);
            }
        }];
    }
}

- (void)warmUpConnection {
    
    [self sendRequest:[PNTimeTokenRequest new] onChannel:self.messagingChannel shouldObserveProcessing:NO];
    [self sendRequest:[PNTimeTokenRequest new] onChannel:self.serviceChannel shouldObserveProcessing:NO];
}

- (void)sendRequest:(PNBaseRequest *)request shouldObserveProcessing:(BOOL)shouldObserveProcessing {
    
    BOOL shouldSendOnMessageChannel = YES;
    
    
    // Checking whether request should be sent on service
    // connection channel or not
    if ([request isKindOfClass:[PNLeaveRequest class]] ||
        [request isKindOfClass:[PNTimeTokenRequest class]] ||
        [request isKindOfClass:[PNMessageHistoryRequest class]] ||
        [request isKindOfClass:[PNHereNowRequest class]] ||
        [request isKindOfClass:[PNLatencyMeasureRequest class]]) {
        
        shouldSendOnMessageChannel = NO;
    }


    [self     sendRequest:request
                onChannel:(shouldSendOnMessageChannel ? self.messagingChannel : self.serviceChannel)
  shouldObserveProcessing:shouldObserveProcessing];
}

- (void)      sendRequest:(PNBaseRequest *)request
                onChannel:(PNConnectionChannel *)channel
  shouldObserveProcessing:(BOOL)shouldObserveProcessing {
 
    [channel scheduleRequest:request shouldObserveProcessing:shouldObserveProcessing];
}


#pragma mark - Connection channel delegate methods

- (void)connectionChannel:(PNConnectionChannel *)channel didConnectToHost:(NSString *)host {

    // Check whether all communication channels connected and whether
    // client in corresponding state or not
    if ([self.messagingChannel isConnected] && [self.serviceChannel isConnected] &&
        self.state == PNPubNubClientStateConnecting && [self.configuration.origin isEqualToString:host]) {
        
        // Mark that PubNub client established connection to PubNub
        // services
        self.state = PNPubNubClientStateConnected;


        [self warmUpConnection];

        [self notifyDelegateAboutConnectionToOrigin:host];

        if (self.isRestoringConnection) {

            NSArray *channels = [self.messagingChannel subscribedChannels];

            if ([channels count] > 0) {

                // Notify delegate that client is about to restore subscription
                // on previously subscribed channels
                if ([self.delegate respondsToSelector:@selector(pubnubClient:willRestoreSubscriptionOnChannels:)]) {

                    [self.delegate performSelector:@selector(pubnubClient:willRestoreSubscriptionOnChannels:)
                                        withObject:self
                                        withObject:channels];
                }

                [self sendNotification:kPNClientSubscriptionWillRestoreNotification withObject:channels];
            }


            BOOL shouldResubscribe = self.configuration.shouldResubscribeOnConnectionRestore;
            if ([self.delegate respondsToSelector:@selector(shouldResubscribeOnConnectionRestore)]) {

                shouldResubscribe = [[self.delegate shouldResubscribeOnConnectionRestore] boolValue];
            }

            [self.messagingChannel restoreSubscription:shouldResubscribe];
        }
        else {

            [self handleLockingOperationComplete:YES];
        }

        self.restoringConnection = NO;
    }
}

- (void)  connectionChannel:(PNConnectionChannel *)channel
  connectionDidFailToOrigin:(NSString *)host
                  withError:(PNError *)error {
    
    // Check whether client in corresponding state and all
    // communication channels not connected to the server
    if(self.state == PNPubNubClientStateConnecting && [self.configuration.origin isEqualToString:host] &&
       ![self.messagingChannel isConnected] && ![self.serviceChannel isConnected]) {

        [self.configuration shouldKillDNSCache:YES];
        
        if ([self.delegate respondsToSelector:@selector(pubnubClient:connectionDidFailWithError:)]) {
            
            [self.delegate performSelector:@selector(pubnubClient:connectionDidFailWithError:)
                                withObject:self
                                withObject:error];
        }
        
        
        // Send notification to all who is interested in it
        // (observation center will track it as well)
        [[NSNotificationCenter defaultCenter] postNotificationName:kPNClientConnectionDidFailWithErrorNotification
                                                            object:self
                                                          userInfo:(id)error];

        [self handleLockingOperationComplete:YES];

    }
}

- (void)connectionChannel:(PNConnectionChannel *)channel didDisconnectFromOrigin:(NSString *)host {
    
    // Check whether host name arrived or not
    // (it may not arrive if event sending instance
    // was dismissed/deallocated)
    if (host == nil) {
        
        host = self.configuration.origin;
    }
    
    
    // Check whether received event from same host on which client
    // is configured or not and all communication channels are closed
    if([self.configuration.origin isEqualToString:host] &&
       ![self.messagingChannel isConnected] && ![self.serviceChannel isConnected]) {
        
        // Check whether all communication channels disconnected and whether
        // client in corresponding state or not
        if (self.state == PNPubNubClientStateDisconnecting ||
            self.state == PNPubNubClientStateDisconnectingOnNetworkError) {
            
            PNError *connectionError;
            PNPubNubClientState state = PNPubNubClientStateDisconnected;
            if (self.state == PNPubNubClientStateDisconnectingOnNetworkError) {
                
                state = PNPubNubClientStateDisconnectedOnNetworkError;
            }
            self.state = state;


            if (self.state == PNPubNubClientStateDisconnected) {

                if ([self.delegate respondsToSelector:@selector(pubnubClient:didDisconnectFromOrigin:)]) {

                    [self.delegate pubnubClient:self didDisconnectFromOrigin:host];
                }

                [self sendNotification:kPNClientDidDisconnectFromOriginNotification withObject:host];
            }
            else if (state == PNPubNubClientStateDisconnectedOnNetworkError) {

                connectionError = [PNError errorWithCode:kPNClientConnectionClosedOnInternetFailureError];

                if ([self.delegate respondsToSelector:@selector(pubnubClient:didDisconnectFromOrigin:withError:)]) {

                    [self.delegate pubnubClient:self didDisconnectFromOrigin:host withError:connectionError];
                }

                [self sendNotification:kPNClientConnectionDidFailWithErrorNotification withObject:connectionError];
            }
            
            
            // Check whether error is caused by network error or not
            switch (connectionError.code) {
                case kPNClientConnectionFailedOnInternetFailureError:
                case kPNClientConnectionClosedOnInternetFailureError:
                    
                    // Try to refresh reachability state (there is situation whem reachability state
                    // changed within library to handle sockets timeout/error)
                    [self.reachability refreshReachabilityState];
                    break;
                    
                default:
                    break;
            }
            
            
            if(self.state == PNPubNubClientStateDisconnected) {
                
                // Clean up cached data
                [PNChannel purgeChannelsCache];

                [self handleLockingOperationComplete:YES];
            }
            else {

                // Check whether service is available
                // (this event may arrive after device was unlocked
                // so basically connection is available and only
                // sockets closed by remote server or internal kernel
                // layer)
                if ([self.reachability isServiceReachabilityChecked]) {

                    if ([self.reachability isServiceAvailable]) {

                        // Check whether should restore connection or not
                        if ([self shouldRestoreConnection]) {

                            self.restoringConnection = YES;

                            // Try to restore connection to remote PubNub services
                            [[self class] connect];
                        }
                    }
                    // In case if there is no connection check whether clint
                    // should restore connection or not.
                    else if(![self shouldRestoreConnection]) {

                        self.state = PNPubNubClientStateDisconnected;
                    }
                }
            }
        }
        // Check whether server unexpectedly closed connection
        // while client was active or not
        else if(self.state == PNPubNubClientStateConnected) {
            
            self.state = PNPubNubClientStateDisconnected;
            
            if([self shouldRestoreConnection]) {
                
                // Try to restore connection to remote PubNub services
                [[self class] connect];
            }
        }
        // Check whether connection has been closed because
        // PubNub client updates it's configuration
        else if (self.state == PNPubNubClientStateDisconnectingOnConfigurationChange) {

            // Close connection to PubNub services
            [[self class] disconnect];
            
            
            // Delay connection restore to give some time internal
            // components to complete their tasks
            int64_t delayInSeconds = 1;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                
                self.state = PNPubNubClientStateCreated;
                self.configuration = self.temporaryConfiguration;
                self.temporaryConfiguration = nil;
                
                [self prepareCryptoHelper];
                
                
                // Restore connection which will use new configuration
                [[self class] connect];
            });
        }
    }
}

- (void) connectionChannel:(PNConnectionChannel *)channel
  willDisconnectFromOrigin:(NSString *)host
                 withError:(PNError *)error {
    
    if (self.state == PNPubNubClientStateConnected && [self.configuration.origin isEqualToString:host]) {
        
        self.state = PNPubNubClientStateDisconnecting;
        BOOL disconnectedOnNetworkError = ![self.reachability isServiceAvailable];
        if(!disconnectedOnNetworkError) {

            disconnectedOnNetworkError = error.code == kPNRequestExecutionFailedOnInternetFailureError;
        }
        if (!disconnectedOnNetworkError) {

            disconnectedOnNetworkError = ![self.messagingChannel isConnected] || ![self.serviceChannel isConnected];
        }
        if (disconnectedOnNetworkError) {
            
            self.state = PNPubNubClientStateDisconnectingOnNetworkError;
        }

        [self.reachability updateReachabilityFromError:error];


        [self notifyDelegateClientWillDisconnectWithError:error];
    }
}


#pragma mark - Handler methods

- (void)handleConnectionErrorOnNetworkFailure {

    // Check whether client is connectig currently or not
    if (self.state == PNPubNubClientStateConnecting) {

        PNError *networkError = [PNError errorWithCode:kPNClientConnectionFailedOnInternetFailureError];

        // Notify delegate about connection error if delegate
        // implemented error handling delegate method
        if ([self.delegate respondsToSelector:@selector(pubnubClient:connectionDidFailWithError:)]) {

            [self.delegate performSelector:@selector(pubnubClient:connectionDidFailWithError:)
                                withObject:self
                                withObject:networkError];
        }

        [self sendNotification:kPNClientConnectionDidFailWithErrorNotification withObject:networkError];

        [self handleLockingOperationComplete:YES];
    }
}

- (void)handleLockingOperationComplete:(BOOL)shouldStartNext {

    if (self.isAsyncLockingOperationInProgress) {

        self.asyncLockingOperationInProgress = NO;

        if (shouldStartNext) {

            NSInvocation *methodInvocation = nil;
            if ([pendingInvocations count] > 0) {

                // Retrieve reference on invocation instance at the start of the list
                // (oldest schedculed instance)
                methodInvocation = [pendingInvocations objectAtIndex:0];
                [pendingInvocations removeObjectAtIndex:0];
            }

            [methodInvocation invoke];
        }
    }
}


#pragma mark - Misc methods

- (void)prepareCryptoHelper {
    
    if ([self.configuration.cipherKey length] > 0) {
        
        PNError *helperInitializationError = nil;
        [[PNCryptoHelper sharedInstance] updateWithConfiguration:self.configuration
                                                       withError:&helperInitializationError];
        if (helperInitializationError != nil) {
            
            PNLog(PNLogGeneralLevel, self, @" [INFO] Crypto helper initialization failed because of error: %@",
                  helperInitializationError);
        }
    }
}

- (BOOL)shouldPostponeMethodCall {

    return self.isAsyncLockingOperationInProgress;
}

- (void)postponeSelector:(SEL)calledMethodSelector
               forObject:(id)object
          withParameters:(NSArray *)parameters
              outOfOrder:(BOOL)placeOutOfOrder{

    // Initialze variables required to perform postponed method call
    int signatureParameterOffset = 2;
    NSMethodSignature *methodSignature = [object methodSignatureForSelector:calledMethodSelector];
    NSInvocation *methodInvocation = [NSInvocation invocationWithMethodSignature:methodSignature];

    // Configure invocation instance
    methodInvocation.selector = calledMethodSelector;
    [parameters enumerateObjectsUsingBlock:^(id parameter, NSUInteger parameterIdx, BOOL *parametersEnumeratorStop) {

        NSUInteger parameterIndex = (parameterIdx + signatureParameterOffset);
        parameter = [parameter isKindOfClass:[NSNull class]] ? nil : parameter;
        const char *parameterType = [methodSignature getArgumentTypeAtIndex:parameterIndex];
        if ([parameter isKindOfClass:[NSNumber class]]) {

            if (strcmp(parameterType, @encode(BOOL)) == 0) {

                BOOL flagValue = [(NSNumber *) parameter boolValue];
                [methodInvocation setArgument:&flagValue atIndex:parameterIndex];
            }
            else if (strcmp(parameterType, @encode(NSUInteger)) == 0) {

                NSUInteger unsignedInteger = [(NSNumber *) parameter unsignedIntegerValue];
                [methodInvocation setArgument:&unsignedInteger atIndex:parameterIndex];
            }
        }
        else {

            [methodInvocation setArgument:&parameter atIndex:parameterIndex];
        }
    }];
    methodInvocation.target = object;
    [methodInvocation retainArguments];


    // Place invocation instance into mending invocations set for future usage
    if (placeOutOfOrder) {

        // Placing method invocation at first index, so it will be called as soon
        // as possible
        [pendingInvocations insertObject:methodInvocation atIndex:0];
    }
    else {

        [pendingInvocations addObject:methodInvocation];
    }
}

- (void)notifyDelegateAboutConnectionToOrigin:(NSString *)originHostName {

    // Check whether delegate able to handle connection completion
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didConnectToOrigin:)]) {

        [self.delegate performSelector:@selector(pubnubClient:didConnectToOrigin:)
                            withObject:self
                            withObject:self.configuration.origin];
    }

    [self sendNotification:kPNClientDidConnectToOriginNotification withObject:originHostName];
}

- (void)notifyDelegateAboutSubscriptionFailWithError:(PNError *)error {

    // Check whether delegate is able to handle subscription error
    // or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:subscriptionDidFailWithError:)]) {

        [self.delegate performSelector:@selector(pubnubClient:subscriptionDidFailWithError:)
                            withObject:self
                            withObject:(id)error];
    }

    [self sendNotification:kPNClientSubscriptionDidFailNotification withObject:error];

    [self handleLockingOperationComplete:YES];
}

- (void)notifyDelegateAboutUnsubscriptionFailWithError:(PNError *)error {

    // Check whether delegate is able to handle unsubscription error
    // or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:unsubscriptionDidFailWithError:)]) {

        [self.delegate performSelector:@selector(pubnubClient:unsubscriptionDidFailWithError:)
                            withObject:self
                            withObject:(id)error];
    }

    [self sendNotification:kPNClientUnsubscriptionDidFailNotification withObject:error];

    [self handleLockingOperationComplete:YES];
}

- (void)notifyDelegateAboutTimeTokenRetrievalFailWithError:(PNError *)error {

    // Check whether delegate is able to handle time token retriaval
    // error or not
    if([self.delegate respondsToSelector:@selector(pubnubClient:timeTokenReceiveDidFailWithError:)]) {

        [self.delegate performSelector:@selector(pubnubClient:timeTokenReceiveDidFailWithError:)
                            withObject:self
                            withObject:error];
    }

    [self sendNotification:kPNClientDidFailTimeTokenReceiveNotification withObject:error];

    [self handleLockingOperationComplete:YES];
}

- (void)notifyDelegateAboutMessageSendingFailedWithError:(PNError *)error {

    // Check whether delegate is able to handle message sendinf error
    // or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didFailMessageSend:withError:)]) {

        [self.delegate pubnubClient:self didFailMessageSend:error.associatedObject withError:error];
    }

    [self sendNotification:kPNClientMessageSendingDidFailNotification withObject:error];

    [self handleLockingOperationComplete:YES];
}

- (void)notifyDelegateAboutHistoryDownloadFailedWithError:(PNError *)error {

    // Check whether delegate us able to handle message history download error
    // or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didFailHistoryDownloadForChannel:withError:)]) {

        [self.delegate pubnubClient:self
   didFailHistoryDownloadForChannel:error.associatedObject
                          withError:error];
    }

    [self sendNotification:kPNClientHistoryDownloadFailedWithErrorNotification withObject:error];

    [self handleLockingOperationComplete:YES];
}

- (void)notifyDelegateAboutParticipantsListDownloadFailedWithError:(PNError *)error {

    // Check whether delegate us able to handle participants list
    // download error or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didFailParticipantsListDownloadForChannel:withError:)]) {

        [self.delegate       pubnubClient:self
didFailParticipantsListDownloadForChannel:error.associatedObject
                                withError:error];
    }

    [self sendNotification:kPNClientParticipantsListDownloadFailedWithErrorNotification withObject:error];

    [self handleLockingOperationComplete:YES];
}

- (void)notifyDelegateAboutError:(PNError *)error {
        
    if ([self.delegate respondsToSelector:@selector(pubnubClient:error:)]) {
        
        [self.delegate performSelector:@selector(pubnubClient:error:)
                            withObject:self
                            withObject:error];
    }

    [self sendNotification:kPNClientErrorNotification withObject:error];
}

- (void)notifyDelegateClientWillDisconnectWithError:(PNError *)error {

    if ([self.delegate respondsToSelector:@selector(pubnubClient:willDisconnectWithError:)]) {

        [self.delegate performSelector:@selector(pubnubClient:willDisconnectWithError:)
                            withObject:self
                            withObject:error];
    }

    [self sendNotification:kPNClientConnectionDidFailWithErrorNotification withObject:error];
}

- (void)sendNotification:(NSString *)notificationName withObject:(id)object {

    // Send notification to all who is interested in it
    // (observation center will track it as well)
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:object];
}

- (BOOL)shouldRestoreConnection {

    BOOL shouldRestoreConnection = self.configuration.shouldAutoReconnectClient;
    if ([self.delegate respondsToSelector:@selector(shouldReconnectPubNubClient:)]) {

        shouldRestoreConnection = [[self.delegate performSelector:@selector(shouldReconnectPubNubClient:)
                                                       withObject:self] boolValue];
    }


    return shouldRestoreConnection;
}

- (NSInteger)requestExecutionPossibilityStatusCode {

    NSInteger statusCode = 0;

    // Check whether client can subscribe for channels or not
    if ([self.reachability isServiceReachabilityChecked] && [self.reachability isServiceAvailable]) {

        if (![self isConnected]) {

            statusCode = kPNRequestExecutionFailedClientNotReadyError;
        }
    }
    else {

        statusCode = kPNRequestExecutionFailedOnInternetFailureError;
    }


    return statusCode;
}


#pragma mark - Message channel delegate methods

- (void)messagingChannel:(PNMessagingChannel *)channel didSubscribeOnChannels:(NSArray *)channels {

    // Check whether delegate can handle subscription on channel or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didSubscribeOnChannels:)]) {

        [self.delegate performSelector:@selector(pubnubClient:didSubscribeOnChannels:)
                            withObject:self
                            withObject:channels];
    }


    [self sendNotification:kPNClientSubscriptionDidCompleteNotification withObject:channels];

    [self handleLockingOperationComplete:YES];
}

- (void)messagingChannel:(PNMessagingChannel *)messagingChannel didRestoreSubscriptionOnChannels:(NSArray *)channels {

    // Check whether delegate can handle subscription restore on channels or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didRestoreSubscriptionOnChannels:)]) {

        [self.delegate performSelector:@selector(pubnubClient:didRestoreSubscriptionOnChannels:)
                            withObject:self
                            withObject:channels];
    }

    [self sendNotification:kPNClientSubscriptionDidRestoreNotification withObject:channels];

    [self handleLockingOperationComplete:YES];
}

- (void)    messagingChannel:(PNMessagingChannel *)channel
  didFailSubscribeOnChannels:(NSArray *)channels
                   withError:(PNError *)error {

    error.associatedObject = channels;
    [self notifyDelegateAboutSubscriptionFailWithError:error];
}

- (void)messagingChannel:(PNMessagingChannel *)channel didUnsubscribeFromChannels:(NSArray *)channels {

    // Check whether delegate can handle unsubscription event or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didUnsubscribeOnChannels:)]) {

        [self.delegate performSelector:@selector(pubnubClient:didUnsubscribeOnChannels:)
                            withObject:self
                            withObject:channels];
    }

    [self sendNotification:kPNClientUnsubscriptionDidCompleteNotification withObject:channels];
}

- (void)    messagingChannel:(PNMessagingChannel *)channel
didFailUnsubscribeOnChannels:(NSArray *)channels
                   withError:(PNError *)error {

    error.associatedObject = channels;
    [self notifyDelegateAboutUnsubscriptionFailWithError:error];
}

- (void)messagingChannel:(PNMessagingChannel *)messagingChannel didReceiveMessage:(PNMessage *)message {

    // Check whether delegate can handle new message arrival or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didReceiveMessage:)]) {

        [self.delegate performSelector:@selector(pubnubClient:didReceiveMessage:)
                            withObject:self
                            withObject:message];
    }

    [self sendNotification:kPNClientDidReceiveMessageNotification withObject:message];
}

- (void)messagingChannel:(PNMessagingChannel *)messagingChannel didReceiveEvent:(PNPresenceEvent *)event {

    // Try to update cached channel data
    PNChannel *channel = event.channel;
    if (channel) {

        [channel updateWithEvent:event];
    }

    // Check whether delegate can handle presence event arrival or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didReceivePresenceEvent:)]) {

        [self.delegate performSelector:@selector(pubnubClient:didReceivePresenceEvent:)
                            withObject:self
                            withObject:event];
    }

    [self sendNotification:kPNClientDidReceivePresenceEventNotification withObject:event];
}


#pragma mark - Service channel delegate methods

- (void)serviceChannel:(PNServiceChannel *)channel didReceiveTimeToken:(NSNumber *)timeToken {

    // Check whether delegate can handle time token retrieval or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didReceiveTimeToken:)]) {

        [self.delegate performSelector:@selector(pubnubClient:didReceiveTimeToken:)
                            withObject:self
                            withObject:timeToken];
    }

    [self sendNotification:kPNClientDidReceiveTimeTokenNotification withObject:timeToken];

    [self handleLockingOperationComplete:YES];
}

- (void)serviceChannel:(PNServiceChannel *)channel receiveTimeTokenDidFailWithError:(PNError *)error {

    [self notifyDelegateAboutTimeTokenRetrievalFailWithError:error];

    [self handleLockingOperationComplete:YES];
}

- (void)    serviceChannel:(PNServiceChannel *)channel
  didReceiveNetworkLatency:(double)latency
       andNetworkBandwidth:(double)bandwidth {

    // TODO: NOTIFY NETWORK METER INSTANCE ABOUT ARRIVED DATA
}

- (void)serviceChannel:(PNServiceChannel *)channel willSendMessage:(PNMessage *)message {

    // Check whether delegate can handle message sending event or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:willSendMessage:)]) {

        [self.delegate performSelector:@selector(pubnubClient:willSendMessage:)
                            withObject:self
                            withObject:message];
    }

    [self sendNotification:kPNClientWillSendMessageNotification withObject:message];
}

- (void)serviceChannel:(PNServiceChannel *)channel didSendMessage:(PNMessage *)message {

    // Check whether delegate can handle message sent event or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didSendMessage:)]) {

        [self.delegate performSelector:@selector(pubnubClient:didSendMessage:)
                            withObject:self
                            withObject:message];
    }

    [self sendNotification:kPNClientDidSendMessageNotification withObject:message];

    [self handleLockingOperationComplete:YES];
}

- (void)serviceChannel:(PNServiceChannel *)channel
    didFailMessageSend:(PNMessage *)message
             withError:(PNError *)error {

    error.associatedObject = message;
    [self notifyDelegateAboutMessageSendingFailedWithError:error];
}

- (void)serviceChannel:(PNServiceChannel *)serviceChannel didReceiveMessagesHistory:(PNMessagesHistory *)history {

    // Check whether delegate can response on history download event or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didReceiveMessageHistory:forChannel:startingFrom:to:)]) {

        [self.delegate pubnubClient:self
           didReceiveMessageHistory:history.messages
                         forChannel:history.channel
                       startingFrom:history.startDate
                                 to:history.endDate];
    }

    [self sendNotification:kPNClientDidReceiveMessagesHistoryNotification withObject:history];

    [self handleLockingOperationComplete:YES];
}

- (void)           serviceChannel:(PNServiceChannel *)serviceChannel
  didFailHisoryDownloadForChannel:(PNChannel *)channel
                        withError:(PNError *)error {

    error.associatedObject = channel;
    [self notifyDelegateAboutHistoryDownloadFailedWithError:error];
}

- (void)serviceChannel:(PNServiceChannel *)serviceChannel didReceiveParticipantsList:(PNHereNow *)participants {

    // Check whether delegate can response on participants list download event or not
    if ([self.delegate respondsToSelector:@selector(pubnubClient:didReceiveParticipantsLits:forChannel:)]) {

        [self.delegate pubnubClient:self
         didReceiveParticipantsLits:participants.participants
                         forChannel:participants.channel];
    }

    [self sendNotification:kPNClientDidReceiveParticipantsListNotification withObject:participants];

    [self handleLockingOperationComplete:YES];
}

- (void)                 serviceChannel:(PNServiceChannel *)serviceChannel
  didFailParticipantsListLoadForChannel:(PNChannel *)channel
                              withError:(PNError *)error {

    error.associatedObject = channel;
    [self notifyDelegateAboutParticipantsListDownloadFailedWithError:error];

}

#pragma mark -


@end
