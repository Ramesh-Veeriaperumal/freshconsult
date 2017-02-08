/*
*   chatapi.js
*
*/
(function(global, ChatApi) {
    global.ChatApi = ChatApi();
})(this, function() {
    var config = {};
    var rts;
    var DEFAULT_HEARTBEAT_IVAL = 30 * 1000; // 30s.
    var DEFAULT_MEMBER_PRESENCE_POLL_TIME = 60 * 1000; // 1m.
    var CONVO_ACCESS_SCOPE = "client";


    var LOG_COLOR = "color: green; font-weight: 700;";
    var ERROR_LOG_COLOR = "color: red; font-weight: 700;";
    var WARNING_LOG_COLOR = "color: orange; font-weight: 700;";
    var MSG_TYPE_SERVER_MADD = "2"; // Msg from Server, denotes addition of member
    var MSG_TYPE_SERVER_MREMOVE= "3"; // Msg from Server, denotes removal of member

    var CHAT_API_SERVER, RTS_SERVER, MESSAGE_PUBLISH_ROUTE, USER_MARK_ONLINE_ROUTE,
        USER_UPDATE_ROUTE, CONVERSATION_GET_ROUTE, ADD_MEMBER_ROUTE, REMOVE_MEMBER_ROUTE,
        GET_PRESENCE_ROUTE, GET_NOTIFICATION_ROUTE, MARK_NOTIFICATION_ROUTE,
        CONVERSATION_UPDATE_METADATA_ROUTE, USERS_GET_PAYLOAD_ROUTE, USERS_GET_ALL_ROUTE, CONVERSATION_MESSAGES_HISTORY_ROUTE, ATTACHMENTS_UPLOAD_ROUTE;
    /*
    *   Will be changing these to match this.
    *   https://docs.google.com/document/d/10tJTABwH-z8TbcsxbypDZJ4aaNr63BVue3kEUFLKfAw/edit#heading=h.t46w8c4hnhnh
    */
    function setPaths() {        
        USER_MARK_ONLINE_ROUTE = CHAT_API_SERVER + "/users.markOnline";
        USER_UPDATE_ROUTE = CHAT_API_SERVER + "/users.createOrUpdate";
        GET_PRESENCE_ROUTE = CHAT_API_SERVER + "/users.getOnline";
        USERS_GET_PAYLOAD_ROUTE = CHAT_API_SERVER + "/users.getInitPayload";
        GET_NOTIFICATION_ROUTE = CHAT_API_SERVER + "/users.notifications.get";
        USERS_GET_ALL_ROUTE = CHAT_API_SERVER + "/users.getAll";
        USERS_GET = CHAT_API_SERVER + "/users.get";
        MARK_NOTIFICATION_ROUTE = CHAT_API_SERVER + "/users.notifications.markRead";
        
        ATTACHMENTS_UPLOAD_ROUTE = CHAT_API_SERVER + "/conversations.attachments.upload";
        MESSAGE_PUBLISH_ROUTE = CHAT_API_SERVER + "/conversations.messages.publish";
        CONVERSATION_CREATE_ROUTE = CHAT_API_SERVER + "/conversations.create";
        CONVERSATION_GET_ROUTE = CHAT_API_SERVER + "/conversations.get";
        ADD_MEMBER_ROUTE = CHAT_API_SERVER + "/conversations.members.add";
        CONVERSATION_UPDATE_METADATA_ROUTE = CHAT_API_SERVER + "/conversations.updateMetadata";
        REMOVE_MEMBER_ROUTE = CHAT_API_SERVER + "/conversations.members.remove";
        CONVERSATION_CLOSE_ROUTE = CHAT_API_SERVER + "/conversations.close";
        CONVERSATION_OPEN_ROUTE = CHAT_API_SERVER + "/conversations.open";
        CONVERSATION_MESSAGES_HISTORY_ROUTE = CHAT_API_SERVER + "/conversations.messages.history";
        CONVERSATION_OWNER_SET_ROUTE = CHAT_API_SERVER + "/conversations.owner.set";
        CONVERSATION_GET_ATTACHMENT_URL = CHAT_API_SERVER + "/conversations.attachments.geturl";
    }

    /*
    *   Init
    *   ----
    *
    *   1. Get Initial Payload from ChatAPI
    *   2. Register account to RTS (init socket)
    *   3. Activate listeners on the socket for client
    *       3.1 onconnect
    *       3.2 onmessage
    *   4. Load User on client from ChatAPI
    *   5. Subscribe to Notification conversation on RTS
    *   6. Heartbeat to ChatAPI
    */


    /*
    *   Constructor
    */
    function ChatApi (c) {
        var self = this;
        if(!c){
          throw new Error("No options provided");
          return;
        }

        config = c;

        // Initialize constants.
        CHAT_API_SERVER = config.chatApiServer;
        RTS_SERVER = config.rtsServer;
        setPaths();

        log("%c- Getting initial payload from ChatAPI.", LOG_COLOR)
        collabHttpAjax({
            method: "GET",
            url: USERS_GET_PAYLOAD_ROUTE,
            success: function(response) {
                if(typeof response === "string") {response = JSON.parse(response);}
                if(!!response) {
                    config.rtsAccountId = response.rts_acc_id
                    // TODO(aravindm): Move tokens to cookies.
                    config.authToken = response.collab_token;
                    config.rtsAuthToken = response.rts_token;
                    config.useRtsPub = response.use_rts_pub;
                    config.memberPresencePollTime = response.MemberPresencePollTime;
                    // TODO(aravindm): Use the full user and optional convo object that is returned.
                    NOTIFICATION_CONVO_ID = response.user.info.nch;
                    setModelData.call(self, config);

                    rts = new RTS({
                        "accId" : self.rtsAccountId,
                        "userId" : self.userId,
                        "origin" : RTS_SERVER,
                        "onConnect" : function() {onconnect.call(self);},
                        "onReconnect" : function() {onreconnect.call(self);},
                        "onDisconnect" :  function() {ondisconnect.call(self);},
                        "debug" : !!localStorage.debugCollab
                    });
                    $rts = rts;

                    log("%c- Heartbeats set to send every "+ (response.UserHeartbeatPollTime || DEFAULT_HEARTBEAT_IVAL) + " mili-sec.", LOG_COLOR)
                    var heartbeat = setInterval(function() {
                        // log(">> client: heartbeat sent to ChatAPI")
                        collabHttpAjax({
                            method: "POST",
                            url: USER_MARK_ONLINE_ROUTE,
                            data: {"uid": config.userId},
                            success: function(response) {
                                if(typeof response === "string") {response = JSON.parse(response);};
                                self.onheartbeat(response);
                                log("%c - User online updated.", LOG_COLOR, response);
                            },
                        }, config.clientId, config.authToken);
                    }, response.UserHeartbeatPollTime || DEFAULT_HEARTBEAT_IVAL);
                }
            },
            onerror: function(err) {
                console.log(err);
                log("%c- Could not get payload. ChatAPI is down!!!", ERROR_LOG_COLOR);
            }
        }, config.clientId, config.initAuthToken);
    };

    /*
    *   Sets state variable.
    *   those can later be referred by "ChatApiObject.varName";
    *   Helps maintaining data in state.
    */
    function setModelData() {
        var self = this;
        if(!config){
          throw new Error("No options provided");
        }

        if(config.clientId) {
          self.clientId = String(config.clientId);
        } else {
          throw new Error("ChatApi: clientId not provided");
        }

        if(config.userId) {
          self.userId = String(config.userId);
        } else {
          throw new Error("ChatApi: userId not provided");
        }

        if(config.clientAccountId) {
          self.clientAccountId = config.clientAccountId;
        } else {
          throw new Error("ChatApi: clientAccountId not provided");
        }

        if(config.rtsAccountId) {
          self.rtsAccountId = config.rtsAccountId;
        } else {
          throw new Error("ChatApi: rtsAccountId not provided");
        }

        if(config.authToken) {
          self.authToken = config.authToken;
        } else {
          throw new Error("ChatApi: authToken not provided");
        }

        if(config.rtsAuthToken) {
          self.rtsAuthToken = config.rtsAuthToken;
        } else {
          throw new Error("ChatApi: rtsAuthToken not provided");
        }

        if(config.useRtsPub){
            self.useRtsPub = config.useRtsPub;
        }

        self.memberPresencePollTime = config.memberPresencePollTime || DEFAULT_MEMBER_PRESENCE_POLL_IVAL;

        self.onconnect = config.onconnect || function (){log(">> client: onconnect called.");};
        self.ondisconnect = config.ondisconnect || function (){log(">> client: ondisconnect called.");};
        self.onreconnect = config.onreconnect || function (){log(">> client: onreconnect called.");};
        self.onmessage = config.onmessage || function (){log(">> client: onmessage called.");};
        self.onnotify = config.onnotify || function (){log(">> client: onnotify called.");};
        self.onheartbeat = config.onheartbeat || function (){log(">> client: onheartbeat called.");};
        self.onmemberadd = config.onmemberadd || function(){log(">> client: onmemberadd called.");};
        self.onmemberremove = config.onmemberremove || function(){log(">> client: onmemberremove called.");};
        self.onerror = config.onerror || function(){log(">> client: on error called.");};
    };

    /*
    *   onConnect, onMessage, onNotification
    */
    function onconnect(){
        var self = this;
        log(">> ChatApi: Socket Connected");
        if(NOTIFICATION_CONVO_ID){
            subscribe.call(self, NOTIFICATION_CONVO_ID);
        }
        self.onconnect();
    }

    function onreconnect(){
        var self = this;
        self.onreconnect();
    }

    function ondisconnect(){
        var self = this;
        self.ondisconnect();
    }

    function onmessagehandler(data){
        var self = this;
        log(">> ChatApi: Received Data: ", data);

        if (data.accId === self.rtsAccountId) {
            var eventType = data.event || data.query || "";
            var msg;
            switch (eventType.toLowerCase()) {
                case "subscribe":
                    log(">> client: subscription response: ", data);
                    if(data.status === 1) {
                        if(config.subscriptionCallback) {
                            config.subscriptionCallback();
                        } else {
                            log("%c >> client: WARNING!! subscription callback not set.", WARNING_LOG_COLOR, data);
                        }
                    } else {
                        log("%c >> client: ERROR!! while subscribing to channel from RTS.", ERROR_LOG_COLOR, data);
                    }
                    break;
                case "send":
                    log(">> client: send_message response: ", data);
                    // TODO (mayank): make your own unique_id and use them instead of id
                    msg = JSON.parse(data.msg);
                    msg.mid = String(data.id); /* quick fix */
                    if(msg.u_nch === NOTIFICATION_CONVO_ID) {
                        msg.nid = String(data.id); /* quick fix for notification use case */
                        self.onnotify(msg);
                    }
                    else if (msg.m_type === MSG_TYPE_SERVER_MADD){
                        self.onmemberadd(msg);
                    }
                    else if (msg.m_type === MSG_TYPE_SERVER_MREMOVE){
                        self.onmemberremove(msg);
                    }
                    else {
                        self.onmessage(msg);
                    }
                    break;
                default:
                  log("Nothing done for: ", data);
            }
        } else {
            log(">> ChatApi: AccId not valid / not provided", data);
        }
    }

    /*
    *  Subscribing to RTS
    */
    function subscribe(conversation, callback) {
        var self = this;
        rts.subscribe(conversation, function(data){onmessagehandler.call(self, data);}, function(err, data){
            if (typeof callback === "function"){callback(data);}
        });
    };

    /*
    *   Utility functions
    *   -----------------
    *
    *   Handle error cases while calling these functions
    */
    function collabHttpAjax(params, clientId, token, multipart) {
        params.beforeSend = function(xhr) {
            if(!multipart){
                xhr.setRequestHeader("Content-Type", "application/json;charset=UTF-8");    
            }            
            xhr.setRequestHeader("Authorization", token);
            xhr.setRequestHeader("ClientId", clientId);
        };

        // jQuery call isn't working; using raw JS object instead
        // TODO: (mayank): Need to revisit this case.
        if(false && !!window.jQuery) {
            window.jQuery.ajax(params);
        } else {
            var xhr = new(window.XMLHttpRequest || ActiveXObject)('MSXML2.XMLHTTP.3.0');
            xhr.open(params.method, params.url);
            params.beforeSend(xhr);
            xhr.onerror = function (e) {
                params.onerror ? params.onerror(e, xhr) : console.error(e, xhr);
            };
            xhr.onreadystatechange = function (e) {
                if (xhr.readyState === 4) {
                    var okComplete = (xhr.status === 200 || xhr.status === 201);
                    if(okComplete && typeof (params.success || params.statusCode[xhr.status]) === "function") {
                        (params.success || params.statusCode[xhr.status])(xhr.responseText);
                    } else {
                        xhr.onerror.call();
                    }
                }
            };
            if(!!multipart) {
                xhr.send(params.data);    
            } else {
                xhr.send(!!params.data ? stringify(params.data) : null);
            }
        }
    }

    function stringify(data) {
        if(typeof data === "string") {
            return data;
        }
        return window.Prototype ? Object.toJSON(data) : JSON.stringify(data);
    }

    function log(){
        if(console && !!localStorage.debugCollab){
          var args = Array.prototype.slice.call(arguments);
          console.log.apply(console, args);
        }
    };

    function conversationLoadCb(response, cb){
        var self = this;
        if(!response) {
            cb();
            return;
        }
        if(typeof response === "string") {response = JSON.parse(response);};
        log(">> conversation retrieved from ChatAPI: ", response);

        self.conversationsMap = self.conversationsMap || {};
        if(!!response.conversation.co_id && !!response.conversation.co_ch) {
            var conversation = response.conversation;
            self.conversationsMap[conversation.co_id] = conversation;
            subscribe.call(self, response.conversation.co_ch, function() {
                log(">> client: conversation subscribed in RTS.");
                if(typeof cb === "function") {cb(response);}
            });
        }
    }

    function getAuthToken(authToken, convoToken) {
        return !!convoToken ? (authToken+";"+convoToken) : authToken;
    }

    /*
    *   API endpoints
    *   -------------
    *
    *   1. Create Conversation
    *       1.1 Create in ChatAPI
    *       1.2 subscribe in RTS
    *   2. Send Message to ChatAPI
    *   3. load conversation
    *       3.1 Get conversation details from ChatAPI
    *       3.2 Subscribe to conversation on RTS
    *
    */

    /*
    *   Will create in ChatAPI and subscribe in RTS
    */
    ChatApi.prototype.createConversation = function(convo, cb){
        var self = this;

        var conversationObj = {
            "members": convo.members,
            "co_name": convo.name,
            "co_id": convo.co_id,
            "owned_by": convo.owned_by
        };
        conversationObj.members = !!conversationObj.members.length ? conversationObj.members : [self.userId]
        conversationObj.read_access = CONVO_ACCESS_SCOPE;
        conversationObj.write_access = CONVO_ACCESS_SCOPE;
        log("%c- Creating conversation in ChatAPI with name: ", LOG_COLOR, conversationObj.co_id);

        cbStatusOk = function(response) {
            conversationLoadCb.call(self, response, cb);
        }

        function cbStatusCreated(response){
            if(typeof response === "string") {response = JSON.parse(response);};
            log(">> conversation created in ChatAPI: ", response);

            self.conversationsMap = self.conversationsMap || {};
            if(!!response.conversation.co_id && !!response.conversation.co_ch) {
                var conversation = response.conversation;
                self.conversationsMap[conversation.co_id] = conversation;
                // If created subscribe
                subscribe.call(self, response.conversation.co_ch, function() {
                    log(">> client: conversation subscribed in RTS.");
                    if(typeof cb === "function") {cb(response);}
                });
            }
        }

        collabHttpAjax({
            method: "POST",
            url: CONVERSATION_CREATE_ROUTE,
            data: conversationObj,
            statusCode: {
                "200": cbStatusOk,
                "201": cbStatusCreated
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    }

    ChatApi.prototype.sendMessage = function(msg, convo, cb) {
        var self = this;

        var conversationName = convo.co_id;
        var conversation = self.conversationsMap[conversationName];

        var msgObj = {
            "body": msg.body,
            "co_id" : conversationName,
            "co_ch" : conversation.co_ch,
            "rts_aid" : self.rtsAccountId,
            "c_aid" : self.clientId, 
            "s_id": self.userId,
            "cid": self.clientAccountId,
            "metadata": stringify(msg.metadata),
            "m_type": msg.m_type,
            "al": msg.attachment_link
        };

        var logMessage = "Conversation: " + conversationName + " Message: " + msg.body;

        if(self.useRtsPub) {
            log("%c- Sending message to RTSSocket: ", LOG_COLOR, logMessage);
            var params = {
                "message" : msgObj,
                "channelName" : conversation.co_ch,
                "persist": true
            };
            rts.publish(params, cb);
        } else {
            
            log("%c- Sending message to ChatAPI: ", LOG_COLOR, logMessage);
            collabHttpAjax({
                method: "POST",
                url: MESSAGE_PUBLISH_ROUTE,
                data: msgObj,
                success: function(response) {
                    if(typeof response === "string") {response = JSON.parse(response);};
                    log(">> client: message published: ", response);
                    if(typeof cb === "function") {cb(response);}
                }
            }, self.clientId, getAuthToken(self.authToken, convo.token));
        }
    }

    ChatApi.prototype.loadConversation = function(convo, uid, cb) {
        var self = this;

        var conversationName = convo.co_id;
        
        collabHttpAjax({
            method: "GET",
            url: CONVERSATION_GET_ROUTE + "?co_id=" + conversationName + "&uid=" + uid,
            success: function(response){
                conversationLoadCb.call(self, response, cb);
            },
            onerror: function(){
                // expecting 204
                var response = "";
                conversationLoadCb.call(self, response, cb);
            },
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    }

    ChatApi.prototype.addMember = function(convo, memberId, cb) {
        var self = this;

        var conversation = self.conversationsMap[convo.co_id];
        var data = {
            "co_id": convo.co_id,
            "uid": String(memberId),
            "s_id": self.userId
        }

        log(">> Trying to add members in conversation. ", data);

        collabHttpAjax({
            method: "POST",
            url: ADD_MEMBER_ROUTE,
            data: data,
            success: function(response){
                if(typeof response === "string") {response = JSON.parse(response);};
                log(">> members added in conversation.: ", response);
                if(typeof cb === "function") {cb(response);}
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    }

    ChatApi.prototype.removeMember = function(convo, memberId, cb) {
        var self = this;

        var data = {
            "co_id": convo.co_id,
            "uid": String(memberId)
        }

        log(">> Trying to remove members in conversation. ", data);

        collabHttpAjax({
            method: "POST",
            url: REMOVE_MEMBER_ROUTE,
            data: data,
            success: function(response){
                if(typeof response === "string") {response = JSON.parse(response);};
                log(">> member removed from conversation.: ", response);
                if(typeof cb === "function") {cb(response);}
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    }

    ChatApi.prototype.getPresence = function(users, cb) {
        var self = this;
        collabHttpAjax({
            method: "POST",
            url: GET_PRESENCE_ROUTE,
            data: {
                "uid": self.userId,
                "users": users
            },
            success: function(response){
                if(typeof response === "string") {response = JSON.parse(response);};
                log(">> client: online statuses: ", response);
                if(typeof cb === "function") {cb(response);}
            }
        }, self.clientId, self.authToken);
    }

    ChatApi.prototype.getNotifications = function(userId, cb) {
        var self = this;
        collabHttpAjax({
            method: "GET",
            url: GET_NOTIFICATION_ROUTE + "?uid=" + userId,
            success: function(response) {
                if(typeof response === "string") {response = JSON.parse(response);};
                log(">> client: notifications: ", response);
                if(typeof cb === "function") {cb(response);}
            }
        }, self.clientId, self.authToken);
    }

    ChatApi.prototype.updateUser = function(userObj, cb) {
        var self = this;
        var userData = {
            "uid": userObj.uid,
            "info": {
                "name": userObj.info.name,
                "email": userObj.info.email
            }
        };
        collabHttpAjax({
            method: "POST",
            url: USER_UPDATE_ROUTE,
            data: userData,
            success: function(response) {
                if(typeof response === "string") {response = JSON.parse(response);};
                log(">> client: created user: ", response);
                if(typeof cb === "function") {cb(response);}
            }
        }, self.clientId, self.authToken);
    }

    ChatApi.prototype.markNotification = function(notiObj, cb) {
        var self = this;
        var notificationData = {
            "uid": notiObj.uid, 
            "nids": notiObj.nids
        };
        collabHttpAjax({
            method: "POST",
            url: MARK_NOTIFICATION_ROUTE,
            data:  notificationData,
            success:  function(response) {
                if(typeof response === "string") {response = JSON.parse(response);};
                log(">> client: marked notification: ", response);
                if(typeof cb === "function") {cb(response);}
            }
        }, self.clientId, self.authToken);
    }

    ChatApi.prototype.getAllUsers = function(cb) {
        var self = this;
        collabHttpAjax({
            method: "GET",
            url: USERS_GET_ALL_ROUTE,
            success: function(response) {
                if(typeof response === "string") {response = JSON.parse(response);};
                if(typeof cb === "function") {cb(response);}
            }
        }, self.clientId, self.authToken);
    }

    ChatApi.prototype.updateConvoMeta = function(convo, cb) {
        var self = this;

        var convoMeta = {
            "co_id": convo.co_id,
            "operations": convo.operations
        };
        collabHttpAjax({
            method: "POST",
            url: CONVERSATION_UPDATE_METADATA_ROUTE,
            data:  convoMeta,
            success:  function(response) {
                if(typeof response === "string") {response = JSON.parse(response);};
                log(">> client: updated conversation metadata: ", response);
                if(typeof cb === "function") {cb(response);}
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    }

    ChatApi.prototype.getMessages = function(fetchMeta, cb){
        var self = this;

        var param = {
            "co_id": fetchMeta.co_id,
            "start": fetchMeta.start,
            "limit": fetchMeta.limit
        };
        
        var co_id = "?co_id="+param.co_id; // required
        var start = "&start="+param.start; // required
        var limit = (!!param.limit)?("&limit="+param.limit):""; // optional
        collabHttpAjax({
            method: "GET",
            url: CONVERSATION_MESSAGES_HISTORY_ROUTE + co_id + start + limit,
            success: function(response){
                if(typeof response === "string"){response = JSON.parse(response);};
                if(typeof cb === "function"){cb(response);}
            }
        }, self.clientId, getAuthToken(self.authToken, fetchMeta.token));
    },

    ChatApi.prototype.closeConversation = function(convo, cb) {
        var self = this;

        collabHttpAjax({
            method: "POST",
            url: CONVERSATION_CLOSE_ROUTE,
            data: {"co_id": convo.co_id},
            success: function(response){
                if(typeof response === "string"){response = JSON.parse(response);};
                if(typeof cb === "function"){cb(response);}
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    },

    ChatApi.prototype.openConversation = function(convo, cb) {
        var self = this;

        collabHttpAjax({
            method: "POST",
            url: CONVERSATION_OPEN_ROUTE,
            data: {"co_id": convo.co_id},
            success: function(response){
                if(typeof response === "string"){response = JSON.parse(response);};
                if(typeof cb === "function"){cb(response);}
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    },

    ChatApi.prototype.setConvoOwner = function(convo, uid, cb) {
        var self = this;

        collabHttpAjax({
            method: "POST",
            url: CONVERSATION_OWNER_SET_ROUTE,
            data: {"co_id": convo.co_id, "uid": uid, "co_name": convo.name},
            success: function(response){
                if(typeof response === "string"){response = JSON.parse(response);};
                if(typeof cb === "function"){cb(response);}
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    }

    ChatApi.prototype.uploadAttachment = function(convo, cb){
        var self = this;

        var multipartTrue = true;
        var data = convo.formData;
        collabHttpAjax({
            method: "POST",
            url: ATTACHMENTS_UPLOAD_ROUTE,
            data: data,
            success: function(response){
                if(typeof response === "string"){response = JSON.parse(response);};
                if (typeof cb === "function"){cb({code: 200, body: response});}
            },
            onerror: function(e, xhr) {
                // expcting 413 / 415
                cb({code: xhr.status});
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token), multipartTrue);
    },

    ChatApi.prototype.refreshAttachmentUri = function(convo, cb){
        var self = this;
        
        var fid = convo.fid;
        var co_id = convo.co_id;
        
        collabHttpAjax({
            method: "GET",
            url: CONVERSATION_GET_ATTACHMENT_URL + "?fid=" + fid + "&co_id=" + co_id,
            success: function(response){
                if(typeof response === "string"){response = JSON.parse(response);};
                if(typeof cb === "function"){cb(response);}
            }
        }, self.clientId, getAuthToken(self.authToken, convo.token));
    },

    ChatApi.prototype.getUserInfo = function(uid, cb){
        var self = this;
        
        collabHttpAjax({
            method: "GET",
            url: USERS_GET + "?uid=" + uid,
            success: function(response){
                if(typeof response === "string"){response = JSON.parse(response);};
                if(typeof cb === "function"){cb(response);}
            }
        }, self.clientId, self.authToken);
    }    

    return ChatApi;
});
