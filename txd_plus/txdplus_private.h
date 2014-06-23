#ifndef TXD_PRIVATE_H
#define TXD_PRIVATE_H
#include <sys/types.h>
#include <sys/param.h>

/**
 * Endian-ness and stuff
 * probably only works on linux and BSD-like
 */

static inline void _txd_write_int_32_le(uint32_t the_int, uint8_t *buf) {
    buf[0] = the_int >> 24;
    buf[1] = the_int >> 16;
    buf[2] = the_int >> 8;
    buf[3] = the_int;
}

static inline void _txd_write_int_64_le(uint64_t the_int, uint8_t *buf) {
    buf[0] = the_int >> 56;
    buf[1] = the_int >> 48;
    buf[2] = the_int >> 40;
    buf[3] = the_int >> 32;
    buf[4] = the_int >> 24;
    buf[5] = the_int >> 16;
    buf[6] = the_int >> 8;
    buf[7] = the_int;
}

static inline uint32_t _txd_read_int_32_le(const uint8_t *buf) {
    return (((uint32_t)buf[0] << 24) + ((uint32_t)buf[1] << 16) +
            ((uint32_t)buf[2] << 8) + (uint32_t)buf[3]);
}

static inline uint64_t _txd_read_int_64_le(const uint8_t *buf) {
    return (((uint64_t)buf[0] << 56) + ((uint64_t)buf[1] << 48) +
            ((uint64_t)buf[2] << 40) + ((uint64_t)buf[3] << 32) +
            ((uint64_t)buf[4] << 24) + ((uint64_t)buf[5] << 16) +
            ((uint64_t)buf[6] << 8) + (uint64_t)buf[7]);
}
/* otherwise, we write them backwards.
 * It's like how the British drive on the wrong side of the road.
 */
static inline void _txd_write_int_32_be(uint32_t the_int, uint8_t *buf) {
    buf[3] = the_int >> 24;
    buf[2] = the_int >> 16;
    buf[1] = the_int >> 8;
    buf[0] = the_int;
}

static inline void _txd_write_int_64_be(uint64_t the_int, uint8_t *buf) {
    buf[7] = the_int >> 56;
    buf[6] = the_int >> 48;
    buf[5] = the_int >> 40;
    buf[4] = the_int >> 32;
    buf[3] = the_int >> 24;
    buf[2] = the_int >> 16;
    buf[1] = the_int >> 8;
    buf[0] = the_int;
}

static inline uint32_t _txd_read_int_32_be(const void *buf) {
    return *((uint32_t*)buf);
}

static inline uint64_t _txd_read_int_64_be(const void *buf) {
    return *((uint64_t*)buf);
}

static inline void _txd_write_int_64(uint64_t the_int, uint8_t *buf) {
    #if BYTE_ORDER == LITTLE_ENDIAN
    _txd_write_int_64_le(the_int, buf);
    #elif BYTE_ORDER == BIG_ENDIAN
    _txd_write_int_64_be(the_int, buf);
    #else
    #error u w0t m8
    #endif
}

static inline void _txd_write_int_32(uint32_t the_int, uint8_t *buf) {
    #if BYTE_ORDER == LITTLE_ENDIAN
    _txd_write_int_32_le(the_int, buf);;
    #elif BYTE_ORDER == BIG_ENDIAN
    _txd_write_int_32_be(the_int, buf);;
    #else
    #error u w0t m8
    #endif
}

static inline uint64_t _txd_read_int_64(const uint8_t *buf) {
    #if BYTE_ORDER == LITTLE_ENDIAN
    return _txd_read_int_64_le(buf);
    #elif BYTE_ORDER == BIG_ENDIAN
    return _txd_read_int_64_be(buf);
    #else
    #error u w0t m8
    #endif
}

static inline uint32_t _txd_read_int_32(const uint8_t *buf) {
    #if BYTE_ORDER == LITTLE_ENDIAN
    return _txd_read_int_32_le(buf);
    #elif BYTE_ORDER == BIG_ENDIAN
    return _txd_read_int_32_be(buf);
    #else
    #error u w0t m8
    #endif
}

static inline void _txd_kill_memory(void *buf, size_t size) {
    volatile char *p = buf;
    while (size--) {
        *p++ = 0;
    }
}

#endif
