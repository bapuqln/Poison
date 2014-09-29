(function() {
    window.__SCPostEvent = function(name, ob) {
        var evt = document.createEvent("CustomEvent");
        evt.initCustomEvent(name, true, true, ob);
        document.dispatchEvent(evt);
    }

    window.DESMessageTypeText = 1;
    window.DESMessageTypeAction = 2;

    window.SCChatMessageType = 1;
    window.SCInformationalMessageType = 2;
    window.SCAttributeMessageType = 3;

    window.SCAttributeName = 1;
    window.SCAttributeStatusMessage = 2;

    window.__SCPreHeight = 0;
    window.willChangePageHeight = function() {
        var body = document.body;
        var html = document.documentElement;
        var h = Math.max(body.scrollHeight, body.offsetHeight,
                         html.clientHeight, html.scrollHeight, html.offsetHeight);
        window.__SCPreHeight = h;
    }
    window.notePageHeightChanged = function() {
        if (window.pageYOffset + window.innerHeight == window.__SCPreHeight
            || window.preHeight < window.innerHeight)
            window.__SCScrollViewToBottom();
    };

    window.__SCScrollByPointNumber = function(p) {
        window.scrollTo(0, window.pageYOffset + p);
    };
    window.__SCScrollViewToBottom = function() {
        var body = document.body;
        var html = document.documentElement;
        var h = Math.max(body.scrollHeight, body.offsetHeight,
                         html.clientHeight, html.scrollHeight, html.offsetHeight);
        window.scrollTo(0, Math.max(0, h - window.innerHeight));
        window.__SCPreHeight = h;
    };
})();
