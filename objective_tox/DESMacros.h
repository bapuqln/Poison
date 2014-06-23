#ifndef DESMacros
#define DESMacros

#define _DESInfo(fmt, ...)  NSLog(@"%s (%s:%i): [i] " fmt, __func__, __FILE__, __LINE__, ##__VA_ARGS__)
#define _DESWarn(fmt, ...)  NSLog(@"%s (%s:%i): [w] " fmt, __func__, __FILE__, __LINE__, ##__VA_ARGS__)
#define _DESError(fmt, ...) NSLog(@"%s (%s:%i): [e] " fmt, __func__, __FILE__, __LINE__, ##__VA_ARGS__)

#ifndef DES_NO_LOGGING

#define DESInfo _DESInfo
#define DESWarn _DESWarn
#define DESError _DESError

#else

#define DESInfo(fmt, ...)
#define DESWarn(fmt, ...)
#define DESError(fmt, ...)

#endif

#define DESAbstractWarning (_DESWarn(@"Calling methods on an abstract class is not allowed!" \
                            "I'll let you off this once, but fix your code, please."))

#endif
