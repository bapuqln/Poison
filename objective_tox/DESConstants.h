#ifndef DESConstants_h
#define DESConstants_h

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

FOUNDATION_EXPORT NSString *const DESDefaultNickname; /* Toxicle */
FOUNDATION_EXPORT NSString *const DESDefaultStatusMessage; /* Toxing on Tox */

extern const uint32_t DESPublicKeySize;
extern const uint32_t DESPrivateKeySize;
extern const uint32_t DESFriendAddressSize;

extern const uint32_t DESMaximumMessageLength;
extern const uint32_t DESMaximumNameLength;
extern const uint32_t DESMaximumStatusMessageLength;

extern NSString *const DESFriendAddingErrorDomain;

typedef NS_ENUM(uint8_t, DESFriendStatus) {
    DESFriendStatusAvailable,
    DESFriendStatusAway,
    DESFriendStatusBusy,
    DESFriendStatusOffline,
};

typedef NS_ENUM(uint8_t, DESConversationType) {
    DESConversationTypeFriend,
    DESConversationTypeGroup,
};

typedef NS_ENUM(uint8_t, DESMessageType) {
    DESMessageTypeText = 1,
    DESMessageTypeAction = 2,
};

typedef NS_ENUM(uint8_t, DESEventType) {
    DESEventTypeGroupUserNameChanged,
    DESEventTypeGroupUserJoined,
    DESEventTypeGroupUserLeft,
    DESEventTypeFriendNameChanged,
    DESEventTypeFriendStatusMessageChanged,
    DESEventTypeFriendUserStatusChanged,
    DESEventTypeFriendConnectionStatusChanged,
    DESEventTypeFriendControlMessage
};

typedef NS_ENUM(NSInteger, DESFriendAddErrorCode) {
    DESFriendAddMessageTooLong = -1,
    DESFriendAddNoMessage = -2,
    DESFriendAddOwnKey = -3,
    DESFriendAddAlreadySent = -4,
    DESFriendAddUnknownError = -5,
    DESFriendAddInvalidID = -6,
    DESFriendAddNospamChanged = -7,
    DESFriendAddMemoryFailure = -8
};

#endif
