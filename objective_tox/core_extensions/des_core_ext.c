#include "tox.h"
#include "Messenger.h"
#include "util.h"
#include "friend_connection.h"

void DESSetKeys(Tox *tox, uint8_t *pk, uint8_t *sk) {
    Messenger *m = (Messenger *)tox;
    memcpy(m -> net_crypto -> self_public_key, pk, crypto_box_PUBLICKEYBYTES);
    memcpy(m -> net_crypto -> self_secret_key, sk, crypto_box_SECRETKEYBYTES);
}

int DESCountCloseNodes(Tox *tox) {
    Messenger *m = (Messenger *)tox;
    uint32_t i, ret = 0;
    unix_time_update();

    for (i = 0; i < LCLIENT_LIST; ++i) {
        Client_data *client = &m->dht->close_clientlist[i];

        if (!is_timeout(client->assoc4.timestamp, BAD_NODE_TIMEOUT) ||
            !is_timeout(client->assoc6.timestamp, BAD_NODE_TIMEOUT))
            ++ret;
    }

    return ret;
}

int DESCopyNetAddress(Tox *tox, int32_t peernum, char **ip_out, uint16_t *port_out) {
    //if (!tox_get_friend_connection_status(tox, peernum))
    //    return 0;
    Messenger *priv = (Messenger *)tox;
    /* CCID for net_crypto. */
    int ccid = friend_connection_crypt_connection_id(priv->fr_c, priv -> friendlist[peernum].friendcon_id);
    if (ccid == -1) {
        return 0;
    }

    //int ccid = priv -> friendlist[peernum].crypt_connection_id;
    uint8_t is_direct = 0;
    uint32_t status = crypto_connection_status(priv -> net_crypto, ccid, &is_direct);
    if (status != CRYPTO_CONN_ESTABLISHED) {
        if (ip_out)
            *ip_out = "tcprelay";
        if (port_out)
            *port_out = 0;
        return 1;
    }
    IP_Port identity = priv -> net_crypto -> crypto_connections[ccid].ip_port;
    if (identity.ip.family == AF_INET) {
        char *s = malloc(INET_ADDRSTRLEN);
        inet_ntop(AF_INET, identity.ip.ip4.uint8, s, INET_ADDRSTRLEN);
        if (ip_out)
            *ip_out = s;
        else
            free(s);
    } else {
        char *s = malloc(INET6_ADDRSTRLEN);
        inet_ntop(AF_INET6, identity.ip.ip6.uint8, s, INET6_ADDRSTRLEN);
        if (ip_out)
            *ip_out = s;
        else
            free(s);
    }
    if (port_out)
        *port_out = ntohs(identity.port);
    return 1;
}
