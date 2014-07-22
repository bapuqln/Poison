#import "ObjectiveTox-Private.h"
#import "toxav.h"

void DESOrangeDidRequestCall(void *av, int32_t cid, void *arg) {
    DESInfo(@"callback: %d, %p", cid, arg);
}