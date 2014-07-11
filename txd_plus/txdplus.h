#ifndef TXDPLUS_H
#define TXDPLUS_H
#import <sodium.h>

/* Outer envelope functions. cc txd_crypto.c */

extern const int32_t TXD_ERR_BAD_KEY;
extern const int32_t TXD_ERR_DECRYPT_FAILED;
extern const uint32_t TXD_BIT_PADDED_FILE;

typedef struct __txd_fast {
    uint64_t N;
    uint32_t r;
    uint32_t p;
    uint8_t salt[24];
    uint8_t key[crypto_secretbox_KEYBYTES];
} *txd_fast_t;

/**
 * Run scrypt on the password password of passlen.
 * @return A pointer to the precomputed results (or NULL). Use it with
 *         txd_encrypt_buf_fast, then free it with txd_fast_release.
 */
txd_fast_t txd_fast_alloc(const uint8_t *password, uint64_t passlen);

/**
 * Securely erases the precomputed key in obj.
 * This function will not fail.
 */
void txd_fast_release(const txd_fast_t obj);

/**
 * Encrypt clear_in of clear_len with the password password of passlen.
 * If this function returns TXD_ERR_SUCCESS, out will point to the encrypted
 * data, which can be written to disk or sent over the wire.
 * comment will be saved in clear to the file.
 *
 * This is a convenience function that calls txd_encrypt_buf_fast.
 */
int txd_encrypt_buf(const uint8_t *password, uint64_t passlen,
                    const uint8_t *clear_in, uint64_t clear_len,
                    uint8_t **out, uint64_t *out_size,
                    const char *comment, uint32_t flags);

/**
 * Decrypt encr_in of encr_len with the password password of passlen.
 * If this function returns TXD_ERR_SUCCESS, out will point to the decrypted
 * data, which can be further processed (into txd_intermediate_t, for example).
 */
int txd_decrypt_buf(const uint8_t *password, uint64_t passlen,
                    const uint8_t *encr_in, uint64_t encr_len,
                    uint8_t **out, uint64_t *out_size);

/**
 * Do the same thing as txd_encrypt_buf, but with a precomputed scrypt key.
 */
int txd_encrypt_buf_fast(const txd_fast_t precomputed,
                         const uint8_t *clear_in, uint64_t clear_len,
                         uint8_t **out, uint64_t *out_size,
                         const char *comment, uint32_t flags);

#endif
