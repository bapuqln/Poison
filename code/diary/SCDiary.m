#import "SCDiary.h"
#import "scrypt-jane/scrypt-jane.h"
#import "txdplus_private.h"
#include <sqlite3.h>
#include <sodium.h>

/* same as for datafile encryption */
static uint64_t     SCRYPT_N = 13;
static uint32_t     SCRYPT_r = 3;
static uint32_t     SCRYPT_p = 0;

@interface SCDiaryAuthorization : NSObject

- (instancetype)initWithPassword:(NSString *)password
                               N:(uint64_t)n r:(uint32_t)r p:(uint32_t)p
                            salt:(uint8_t *)salt;

@end

@implementation SCDiaryAuthorization {
    uint8_t *_encryptionKey;

    NSString *_password;
    uint8_t *_salt;
    uint64_t _N;
    uint64_t _r;
    uint64_t _p;

    BOOL _hasLazyInitialized;
    dispatch_once_t _instanceOnceToken;
}

- (instancetype)initWithPassword:(NSString *)password
                               N:(uint64_t)n r:(uint32_t)r p:(uint32_t)p
                            salt:(uint8_t *)salt {
    self = [super init];
    if (self) {
        _salt = malloc(24);
        if (!salt) {
            randombytes_buf(_salt, 24);
        } else {
            memcpy(_salt, salt, 24);
        }
        _N = n;
        _r = r;
        _p = p;
    }
    return self;
}

- (const uint8_t *)encryptionKey {
    dispatch_once(&_instanceOnceToken, ^{
        uint8_t *pwBytes = (uint8_t *)_password.UTF8String;
        size_t pwBytesLen = [_password lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

        _encryptionKey = malloc(crypto_secretbox_KEYBYTES);
        scrypt(pwBytes, pwBytesLen, _salt, 24, _N, _r, _p, _encryptionKey, crypto_secretbox_KEYBYTES);
        _hasLazyInitialized = 1;
    });
    return _encryptionKey;
}

- (void)dealloc {
    if (_salt) {
        _txd_kill_memory(_salt, 24);
        free(_salt);
    }
    if (_encryptionKey) {
        _txd_kill_memory(_encryptionKey, crypto_secretbox_KEYBYTES);
        free(_encryptionKey);
    }
}

@end



@interface SCDiary ()

@property sqlite3 *backingStore;
@property (strong) NSCache *pageCache;
@property (strong) SCDiaryAuthorization *auth;

@end

@implementation SCDiary

- (instancetype)initWithURL:(NSURL *)url password:(NSString *)password {
    self = [super init];
    if (self) {
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:url.path];
        sqlite3_initialize();
        int ok = sqlite3_open(url.path.UTF8String, &_backingStore);
        if (ok == SQLITE_OK) {
            [self preload];
            if (!exists) {
                [self createTables];
            }
            self.auth = [self loadAuthorization:password];

            if (!self.auth)
                return nil;
        } else {
            NSLog(@"error opening diary: %@ (%d)", url, ok);
            sqlite3_close(self.backingStore);
            return nil;
        }
    }
    return self;
}

- (void)preload {
    sqlite3_exec(self.backingStore, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
}

/* Based on conversationIdentifier of Poison's DESConversation category.
 * They are hashed one-way to avoid leaking friends on disk. The only data
 * visible in the unencrypted diary container should be book-keeping only. */

#define SCHEMA ("CREATE TABLE auth (salt BLOB, n INT, r INT, p INT);"\
                "CREATE TABLE conversations (conv_num INT PRIMARY KEY, uid BLOB);"\
                "CREATE TABLE page (page_num INT PRIMARY KEY, conversation INT,"\
                                   "nonce BLOB, page BLOB, next INT, prev INT)")

- (void)createTables {
    char *err;
    sqlite3_exec(self.backingStore, SCHEMA, NULL, NULL, &err);
    if (err) {
        NSLog(@"%s", err);
        sqlite3_free(err);
    }
}

#define GET_AUTH ("SELECT * FROM auth LIMIT 1")
#define SET_AUTH ("INSERT INTO auth VALUES (?, ?, ?, ?)")

- (SCDiaryAuthorization *)loadAuthorization:(NSString *)password {
    sqlite3_stmt *stmt = NULL;

    uint8_t *salt = malloc(24);
    uint64_t n;
    uint32_t r, p;

    sqlite3_prepare_v2(self.backingStore, GET_AUTH, -1, &stmt, NULL);
    int ret = sqlite3_step(stmt);

    if (ret == SQLITE_ROW) {
        if (sqlite3_column_bytes(stmt, 1) != 24) {
            free(salt);
            return nil;
        }
        const void *s = sqlite3_column_blob(stmt, 1);
        memcpy(salt, s, 24);

        n = sqlite3_column_int64(stmt, 2);
        r = sqlite3_column_int(stmt, 3);
        p = sqlite3_column_int(stmt, 4);
        sqlite3_finalize(stmt);
        NSLog(@"SCDiary: authorization loaded.");
    } else {
        sqlite3_finalize(stmt);
        n = SCRYPT_N;
        r = SCRYPT_r;
        p = SCRYPT_p;
        randombytes_buf(salt, 24);

        sqlite3_prepare_v2(self.backingStore, SET_AUTH, -1, &stmt, NULL);
        sqlite3_bind_blob(stmt, 1, salt, 24, NULL);
        sqlite3_bind_int64(stmt, 2, n);
        sqlite3_bind_int(stmt, 3, r);
        sqlite3_bind_int(stmt, 4, p);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);

        sqlite3_exec(self.backingStore, "COMMIT", NULL, NULL, NULL);
        NSLog(@"SCDiary: authorization saved.");
    }

    SCDiaryAuthorization *obj = [[SCDiaryAuthorization alloc] initWithPassword:password N:n r:r p:p salt:salt];
    free(salt);
    return obj;
}

- (void)dealloc {
    NSLog(@"Diary closed.");
    sqlite3_close(self.backingStore);
}

@end
