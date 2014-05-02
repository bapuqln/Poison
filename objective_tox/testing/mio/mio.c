/**********************************************
 * mio is a tool for working with TXD2 files,
 * like the kudryavka utility did in Poison 1.x
 * it also keeps the tradition of being named
 * after a Little Buster.
 *
 * Note: requires a TXD-augmented core to com-
 * pile standalone, and the txdplus files,
 * which depend on scrypt. It *should* work
 * on non-Mac boxes.
 *
 * Copyright (c) 2014 Zodiac Labs.
 * You are free to do whatever you want with
 * this file -- provided this notice is
 * retained.
 **********************************************/

#include "data.h"
#include "txdplus.h"
#include "txdplus_private.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <fcntl.h>

void usage(const char *name) {
    printf("%s: quick txd file tool, iteration 2\n", name);
    printf("usage: %s convert [-nico / -maki / -cherry / -toxcore] "
           "<input file> <output file>\n", name);
    printf("usage: %s survey <input file>\n", name);
    printf("usage: %s passwd <input file>\n\n", name);
      puts("note: The switches provided to convert determine the type "
           "of the output file.\n"
           "-nico: Padded maki-file. Leaks the least amount of information.\n"
           "-maki: Plain maki-file.\n"
           "-cherry: Unencrypted TXD binary. Absolutely no protection at all.\n"
           "-toxcore: Unencrypted vanilla file. Works with most other clients, "
                      "but not encrypted.");
}

int passwd(const char *file) {
    FILE *f = fopen(file, "r");
    if (!f) {
        perror("mio/passwd");
        return -1;
    }
    char magic[5] = { 0 };
    fread(&magic, 4, 1, f);
    //printf("%s\n", magic);
    uint32_t magic_const = ntohl(*magic);

    fseek(f, 0, SEEK_END);
    long plc = ftell(f);
    rewind(f);

    uint8_t *bytes = malloc(plc);
    fread(bytes, plc, 1, f);
    fclose(f);

    txd_intermediate_t loaded;
    if (magic_const == 0xE6A19C00) {
        printf("mio/passwd: note: You're adding a password to the cherry-file "
               "%s.\n", file);
        int err = txd_intermediate_from_buf(bytes, plc, &loaded);
        if (err != TXD_ERR_SUCCESS) {
            free(bytes);
            printf("mio/passwd: error: txd_intermediate_from_buf failed with "
                   "code %d\n", err);
            return -1;
        }
    } else {
        char *passwd = getpass("Password: ");
        uint8_t *dec = NULL;
        uint64_t sze = 0;
        printf("%s", bytes);
        int derr = txd_decrypt_buf((uint8_t *)passwd, strlen(passwd), bytes,
                                   plc, &dec, &sze);
        if (derr != TXD_ERR_SUCCESS) {
            free(bytes);
            printf("mio/passwd: error: txd_decrypt_buf failed with "
                   "code %d, did you type the correct password?\n", derr);
            return -1;
        }
        free(bytes);
        int err = txd_intermediate_from_buf(dec, sze, &loaded);
        if (err != TXD_ERR_SUCCESS) {
            printf("mio/passwd: error: txd_intermediate_from_buf failed with "
                   "code %d\n", err);
            return -1;
        }
        free(dec);
    }

    uint8_t *clear;
    uint64_t clearlen;
    int eerr = txd_export_to_buf(loaded, &clear, &clearlen);
    if (eerr != TXD_ERR_SUCCESS) {
        printf("mio/passwd: error: txd_export_to_buf failed with code %d\n",
               eerr);
        return -1;
    }

    uint8_t *e;
    uint64_t elen;
    char *npasswd = getpass("New password: ");
    if (magic_const == 'MAKi') {
        txd_encrypt_buf((uint8_t *)npasswd, strlen(npasswd), clear, clearlen,
                        &e, &elen, "mio 1.0", 0);
    } else {
        txd_encrypt_buf((uint8_t *)npasswd, strlen(npasswd), clear, clearlen,
                        &e, &elen, "mio 1.0", TXD_BIT_PADDED_FILE);
    }

    char *template = strdup(".si-XXXXXXXX");
    char *temp = mktemp(template);
    int fd = open(temp, O_CREAT | O_EXCL | O_WRONLY, 0600);
    if (fd == -1) {
        perror("mio/passwd/write");
        free(e);
        return -1;
    }
    write(fd, e, elen);
    close(fd);
    remove(file);
    rename(temp, file);
    free(template);
    free(e);
    txd_intermediate_free(loaded);
    return 0;
}

int survey(char *file) {
    FILE *f = fopen(file, "r");
    if (!f) {
        perror("mio/survey");
        return -1;
    }
    uint8_t buf[5] = { 0 };
    fread(&buf, 4, 1, f);
    uint32_t magic_const = ntohl(*(uint32_t *)buf);

    fread(&buf, 4, 1, f);
    uint32_t clen = _txd_read_int_32(buf);
    char *comment = calloc(clen + 1, 1);
    fread(comment, clen, 1, f);

    if (magic_const == 'MAKi') {
        puts(" Format: encrypted maki-file (no padding)");
    } else if (magic_const == 'NICo') {
        puts(" Format: encrypted nico-file (padded)");
    } else if (magic_const == 0xE6A19C00) {
        puts(" Format: unencrypted cherry-file");
    } else {
        free(comment);
        puts("unknown format");
        return -1;
    }

    printf("Comment: -----\n%s\n--------------\n", comment);
    free(comment);

    fseek(f, 0, SEEK_END);
    long plc = ftell(f);
    rewind(f);

    uint8_t *bytes = malloc(plc);
    fread(bytes, plc, 1, f);
    fclose(f);

    txd_intermediate_t loaded;
    //__builtin_trap();
    if (magic_const == 0xE6A19C00) {
        int err = txd_intermediate_from_buf(bytes, plc, &loaded);
        if (err != TXD_ERR_SUCCESS) {
            free(bytes);
            printf("mio/survey: error: txd_intermediate_from_buf failed with "
                   "code %d\n", err);
            return -1;
        }
    } else {
        char *passwd = getpass("Password: ");
        uint8_t *dec = NULL;
        uint64_t sze = 0;
        int derr = txd_decrypt_buf((uint8_t *)passwd, strlen(passwd), bytes,
                                   plc, &dec, &sze);
        if (derr != TXD_ERR_SUCCESS) {
            free(bytes);
            printf("mio/survey: error: txd_decrypt_buf failed with "
                   "code %d, did you type the correct password?\n", derr);
            return -1;
        }
        free(bytes);
        int err = txd_intermediate_from_buf(dec, sze, &loaded);
        if (err != TXD_ERR_SUCCESS) {
            printf("mio/survey: error: txd_intermediate_from_buf failed with "
                   "code %d\n", err);
            return -1;
        }
        free(dec);
    }

    puts("****** CONTENTS OF FILE");

    return 0;
}


int convert(int format, char *file, char *fileout) {
    FILE *f = fopen(file, "r");
    if (!f) {
        perror("mio/convert");
        return -1;
    }
    char magic[5] = { 0 };
    fread(&magic, 4, 1, f);
    uint32_t magic_const = ntohl(*(uint32_t *)magic);
    if ((magic_const == 'MAKi' || magic_const == 'NICo')
        && (format == 0 || format == 3))
        puts("mio/convert: warning: you are converting from an encrypted "
             "format to a non-encrypted format.");

    fseek(f, 0, SEEK_END);
    long plc = ftell(f);
    rewind(f);

    uint8_t *bytes = malloc(plc);
    fread(bytes, plc, 1, f);
    fclose(f);

    txd_intermediate_t loaded;
    //__builtin_trap();
    if (magic_const == 0xE6A19C00) {
        int err = txd_intermediate_from_buf(bytes, plc, &loaded);
        if (err != TXD_ERR_SUCCESS) {
            free(bytes);
            printf("mio/convert: error: txd_intermediate_from_buf failed with "
                   "code %d\n", err);
            return -1;
        }
    } else {
        char *passwd = getpass("Password: ");
        uint8_t *dec = NULL;
        uint64_t sze = 0;
        int derr = txd_decrypt_buf((uint8_t *)passwd, strlen(passwd), bytes,
                                   plc, &dec, &sze);
        if (derr != TXD_ERR_SUCCESS) {
            free(bytes);
            printf("mio/convert: error: txd_decrypt_buf failed with "
                   "code %d, did you type the correct password?\n", derr);
            return -1;
        }
        free(bytes);
        int err = txd_intermediate_from_buf(dec, sze, &loaded);
        if (err != TXD_ERR_SUCCESS) {
            printf("mio/convert: error: txd_intermediate_from_buf failed with "
                   "code %d\n", err);
            return -1;
        }
        free(dec);
    }

    uint8_t *finished_output = NULL;
    uint64_t size;

    char *template = strdup(".si-XXXXXXXX");
    char *temp = mktemp(template);
    int fd = open(temp, O_CREAT | O_EXCL | O_WRONLY, 0600);
    if (fd == -1) {
        perror("mio/convert");
        return -1;
    }

    if (format == 3) {
        Tox *t = tox_new(1);
        txd_restore_intermediate(loaded, t);
        puts("mio/convert: writing Core file, so letting Tox run for a bit");
        for (int n = 0; n < 20; ++n) {
            tox_do(t);
            printf(".");
            fflush(stdout);
            usleep(50000);
        }
        puts(" done");
        size = tox_size(t);
        finished_output = malloc(size);
        tox_save(t, finished_output);
        goto writeout;
    }

    uint8_t *clear;
    uint64_t clearlen;
    int eerr = txd_export_to_buf(loaded, &clear, &clearlen);
    if (eerr != TXD_ERR_SUCCESS) {
        printf("mio/passwd: error: txd_export_to_buf failed with code %d\n",
               eerr);
        return -1;
    }
    if (format == 0) {
        finished_output = clear;
        size = clearlen;
        goto writeout;
    }

    char *npasswd = getpass("New password: ");
    if (format == 1) {
        txd_encrypt_buf((uint8_t *)npasswd, strlen(npasswd), clear, clearlen,
                        &finished_output, &size, "mio 1.0", 0);
    } else {
        txd_encrypt_buf((uint8_t *)npasswd, strlen(npasswd), clear, clearlen,
                        &finished_output, &size, "mio 1.0", TXD_BIT_PADDED_FILE);
    }
    free(clear);

  writeout:
    write(fd, finished_output, size);
    close(fd);
    rename(temp, fileout);
    free(template);
    free(finished_output);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        usage(argv[0]);
        return 0;
    }
    const char *cmd = argv[1];
    if (!strcmp(cmd, "passwd") && argc == 3) {
        return passwd(argv[2]);
    } else if (!strcmp(cmd, "convert") && argc == 5) {
        int fmt;
        if (!strcmp(argv[2], "-cherry"))
            fmt = 0;
        else if (!strcmp(argv[2], "-maki"))
            fmt = 1;
        else if (!strcmp(argv[2], "-nico"))
            fmt = 2;
        else if (!strcmp(argv[2], "-toxcore"))
            fmt = 3;
        else {
            printf("mio/convert: error: format must be one of -cherry, -maki, "
                   "-nico, -toxcore");
            return -1;
        }
        return convert(fmt, argv[3], argv[4]);
    } else if (!strcmp(cmd, "survey") && argc == 3) {
        return survey(argv[2]);
    }
    return 0;
}

