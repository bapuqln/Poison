#include "libarisa.h"
#include "txdplus_private.h"

#define LIBARISA_DEBUG (1)

uint8_t *arisa_get_signature(uint8_t *buf, uint64_t len) {
    /* address where RISa + flen is */
    uint8_t *header = buf + (len - ARISA_SIGSTRUCTLEN);

    uint32_t magic = _txd_read_int_32(header);
    if (magic != ARISA_MAGIC) {
#if LIBARISA_DEBUG
        puts("wasn't able to read RISb");
#endif
        return NULL;
    }
    return header;
}

int arisa_copy_hash(uint8_t *sig, uint8_t *public_key, uint8_t **out) {
    uint8_t *nacl_sig = sig + 4;
    uint8_t *hash = malloc(crypto_hash_sha512_BYTES + crypto_sign_ed25519_BYTES);
    unsigned long long hash_length;

    int ver = crypto_sign_ed25519_open(hash, &hash_length, nacl_sig,
                                       ARISA_SIGSTRUCTLEN - 4, public_key);

    if (ver == -1) {
#if LIBARISA_DEBUG
        puts("file is tampered with");
#endif
        free(hash);
        return ARISA_SIGNATURE_TAMPERED;
    }

    if (hash_length != crypto_hash_sha512_BYTES) {
#if LIBARISA_DEBUG
        puts("weird hash length");
#endif
        free(hash);
        return ARISA_SIGNATURE_INVALID;
    }

    if (out)
        *out = hash;
    return 0;
}

int arisa_onestep_verify(uint8_t *buf, uint64_t len, uint8_t *pubkey) {
    uint8_t *sig = arisa_get_signature(buf, len);
    if (!sig)
        return ARISA_SIGNATURE_INVALID;

    uint8_t *hash;
    int status = arisa_copy_hash(sig, pubkey, &hash);

    if (status == 0) {
        uint8_t *calculated_hash = malloc(crypto_hash_sha512_BYTES);
        crypto_hash_sha512(calculated_hash, buf, len - ARISA_SIGSTRUCTLEN);

        int match = 0;
        match |= crypto_verify_32(calculated_hash, hash);
        match |= crypto_verify_32(calculated_hash + 32, hash + 32);
        free(calculated_hash);

        if (match != 0)
            status = ARISA_SIGNATURE_TAMPERED;
        free(hash);
    }

    return status;
}


