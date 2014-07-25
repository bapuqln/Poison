#ifndef arisa_tools_libarisa_h
#define arisa_tools_libarisa_h

#include <stdint.h>
#include <sodium.h>

#define ARISA_MAGIC ((uint32_t)'RISb')
#define ARISA_SIGN_KEYSIZE (crypto_sign_ed25519_SECRETKEYBYTES)
#define ARISA_OPEN_KEYSIZE (crypto_sign_ed25519_PUBLICKEYBYTES)
#define ARISA_SIGSTRUCTLEN (4 + crypto_hash_sha512_BYTES + \
                            crypto_sign_ed25519_BYTES)

#define ARISA_SIGNATURE_INVALID (-3001)
#define ARISA_SIGNATURE_TAMPERED (-3002)

uint8_t *arisa_get_signature(uint8_t *buf, uint64_t len);
int arisa_copy_hash(uint8_t *sig, uint8_t *public_key, uint8_t **out);
int arisa_onestep_verify(uint8_t *buf, uint64_t len, uint8_t *pubkey);

#endif
