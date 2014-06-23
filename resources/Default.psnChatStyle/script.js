window._actually_create_context = function(classes) {
    var c = document.createElement("div");
    c.className = "context";
    var i;
    for (i = 0; i < classes.length; i++) {
        c.classList.add(classes[i]);
    }
    document.body.appendChild(c);
    window.last_context = c;
    return true;
}

window.create_context_if_needed = function() {
    var cc = window.last_context;
    if (cc === null) {
        return window._actually_create_context(arguments);
    }
    var i;
    for (i = 0; i < arguments.length; ++i) {
        if (cc.classList.contains(arguments[i])) {
            continue;
        } else {
            return window._actually_create_context(arguments);
        }
    }
    return false;
}

window.prepare_message_context = function(suid, name) {
    var c = window.last_context;
    
    var dummy_div = document.createElement("div");
    dummy_div.style.position = "relative";
    
    var avatar = new Image(32, 32);
    avatar.className = "avatar"
    avatar.src = window.Conversation.avatarImageFor_(suid);
    
    dummy_div.appendChild(avatar);
    
    var units = document.createElement("div");
    units.className = "units-bogus";
    dummy_div.appendChild(units);
    c.appendChild(dummy_div);
    
    var sendername = document.createElement("div");
    sendername.className = "sender_name";
    sendername.textContent = name;
    c.appendChild(sendername);
}

window.appendInformational = function(text) {
    window.last_context = null;
    var div = document.createElement("div");
    div.className = "information";
    div.textContent = text;
    document.body.appendChild(div);
}

window.appendMessage = function(m, ded) {
    if (window.create_context_if_needed(m.isSelf()? "self" : "other", "message",
                                        m.senderUID()))
        window.prepare_message_context(m.senderUID(), m.senderName());
    
    var ulist = window.last_context.children[0].children[1];
    var unit = document.createElement("div");
    unit.className = "unit";
    if (ded)
        unit.classList.add("failed");
    
    var text = document.createElement("div");
    text.className = "message_text";
    text.textContent = m.stringValue();
    
    var ts = document.createElement("div");
    ts.className = "timestamp";
    ts.textContent = m.localizedTimestamp();
    
    if (m.isSelf()) {
        unit.appendChild(ts);
        unit.appendChild(text);
    } else {
        unit.appendChild(text);
        unit.appendChild(ts);
    }
    ulist.appendChild(unit);
    
    if (m.messageID() !== 0)
        window.tracking_messages[m.messageID()] = unit;
}

window.appendAction = function(m, ded) {
    window._actually_create_context([m.isSelf()? "self" : "other", "action", m.senderUID()]);
    var c = window.last_context;
    
    var flex_c = document.createElement("div");
    flex_c.className = "flex_centered";
    if (ded)
        unit.classList.add("failed");
    
    var ts = document.createElement("div");
    ts.className = "timestamp";
    ts.textContent = m.localizedTimestamp();
    
    var avatar = new Image(32, 32);
    avatar.className = "avatar"
    avatar.src = window.Conversation.avatarImageFor_(m.senderUID());
    
    var msg = document.createElement("div");
    msg.className = "message_action";

    var b = document.createElement("b");
    b.textContent = "\u2022 " + m.senderName();
    msg.appendChild(b);
    msg.appendChild(document.createTextNode(" " + m.stringValue()));
    
    if (m.isSelf()) {
        flex_c.appendChild(ts);
        flex_c.appendChild(msg);
        flex_c.appendChild(avatar);
    } else {
        flex_c.appendChild(avatar);
        flex_c.appendChild(msg);
        flex_c.appendChild(ts);
    }
    
    c.appendChild(flex_c);
    
    if (m.messageID() !== 0)
        window.tracking_messages[m.messageID()] = flex_c;
}

window.deliverMessage = function(event) {
    var cevent = event.detail[0];
    for (var i = 0; i < event.detail.length; cevent = event.detail[++i]) {
        console.log(cevent.unixTimestamp())
        if (window.last_timestamp === null
            || Math.abs(cevent.unixTimestamp() - window.last_timestamp) > 600) {
            window.appendInformational(cevent.localizedTimestamp());
            window.last_timestamp = cevent.unixTimestamp();
        }
        switch (cevent.type()) {
            case window.SCChatMessageType: {
                if (cevent.chatMessageType() === window.DESMessageTypeAction) {
                    window.appendAction(cevent, 0);
                } else {
                    window.appendMessage(cevent, 0);
                }
                break;
            }
            case window.SCInformationalMessageType: {
                window.postInformational(cevent);
                break;
            }
        }
    }
}

window.appendDeadMessage = function(event) {
    var cevent = event.detail[0];
    for (var i = 0; i < event.detail.length; cevent = event.detail[++i]) {
        console.log(cevent.unixTimestamp())
        if (window.last_timestamp === null
            || Math.abs(cevent.unixTimestamp() - window.last_timestamp) > 600) {
            window.appendInformational(cevent.localizedTimestamp());
            window.last_timestamp = cevent.unixTimestamp();
        }
        switch (cevent.type()) {
            case window.SCChatMessageType: {
                if (cevent.chatMessageType() === window.DESMessageTypeAction) {
                    window.appendAction(cevent, 1);
                } else {
                    window.appendMessage(cevent, 1);
                }
                break;
            }
            case window.SCInformationalMessageType: {
                window.postInformational(cevent);
                break;
            }
        }
    }
}

window.flairDeliveredMessage = function(event) {
    console.log("lel")
    console.log(event)
    var cevent = event.detail;
    if (window.tracking_messages[cevent] !== undefined) {
        window.tracking_messages[cevent].classList.add("delivered");
        window.tracking_messages[cevent] = undefined;
    }
}

window.bindEventHandlers = function() {
    window.last_context = null;
    window.last_timestamp = null;
    window.tracking_messages = {};
    document.addEventListener("SCMessagePostedEvent", window.deliverMessage, true);
    document.addEventListener("SCMessageDeliveredEvent", window.flairDeliveredMessage, true);
    document.addEventListener("SCFailedMessagePostedEvent", window.appendDeadMessage, true);
    console.log("initialized.");
}

window.onload = function() {
    window.bindEventHandlers();
}