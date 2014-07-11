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
})();
