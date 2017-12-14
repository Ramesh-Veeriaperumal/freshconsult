/*
*   For collaboration feature.
*   To be included in cdn/collaboration.js
*
*/

window.App = window.App || {};
App.CollaborationModel = (function ($) {
    var CONST = {
        TYPE_SENT: "sent",
        TYPE_RECEIVED: "received",
        MSG_TYPE_CLIENT: "1", // Msg from Client
        MSG_TYPE_SERVER_MADD: "2", // Msg from Server, denotes addition of member
        MSG_TYPE_SERVER_MREMOVE: "3", // Msg from Server, denotes removal of member
        MSG_TYPE_CLIENT_ATTACHMENT: '4', // Attachment Msg from Client
        MSG_TYPE_TYPING: 'typing', // not known to server
        MSG_TYPE_READ_RECEIPT: 'read_receipt', // not known to server
        JUST_NOW_TEXT: "Now",
        LONG_AGO_TEXT: "Long ago",
        MAX_ONLINE_SEC: 60,
        MONTHS: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
        TIME_CHUNKS: [[60 * 60 * 24, "d"], [60 * 60, "h"], [60, "m"]],
        NOTIFICATION_POPUP_CARD_TEMPLATE: "collaboration/templates/notification_popup_card",
        DUMMY_USER: {name: "New user"},
        ANNOTATION: {bg_color: "#b4ebdf", shadow_color: "#7ec7b7", border_color: "#96dbcc"},
        NOTI_KEYS: ["hk_notify", "hk_group_notify", "reply"],
        RESPONSE_ERROR_ACTION_NOT_AUTHORIZED: "Action not authorized" // Response Error String
   };

    var _COLLAB_PVT = {
        ChatApi: {},
        apiInited: function(response) {
            if(typeof response.features !== "undefined") {
                Collab.features.groupMentionsEnabled = response.features.enable_group_mentions;
                Collab.features.replyToEnabled = response.features.enable_reply_to;
                Collab.features.collabTourEnabled = response.features.show_collab_tour;
                Collab.features.markReadEnabled = response.features.enable_mark_read;
                Collab.features.followerEnabled = response.features.enable_follower;
                Collab.features.readReceiptEnabled = response.features.enable_read_receipt;
            }
        },
        connectionInited : function() {
            Collab.MEMBER_PRESENCE_POLL_TIME = _COLLAB_PVT.ChatApi.memberPresencePollTime;
            // TODO(mayank): mergo updates DB with nil data
            // This is supposed to update latest self_info; Avoiding this temporarily;
            // _COLLAB_PVT.updateUser(Collab.currentUser.uid, Collab.currentUser.name, Collab.currentUser.email)

            function uiIniter() {
                Collab.initedWithData = true;
                // call initUI if pending config found
                if(typeof App.CollaborationUi !== "undefined" && !!App.CollaborationUi.pendingConfig) {
                    App.CollaborationUi.initUi(App.CollaborationUi.pendingConfig);
                    delete App.CollaborationUi.pendingConfig;
                }
            }

            _COLLAB_PVT.ChatApi.getAllUsers(function(response) {
                var users = response.users;
                Collab.usersTagMap = {};
                // TODO (ankit): manage response.start and futher fetching if(start != "")
                users.forEach(function(user) {
                    var handle = user.info.email.split("@")[0];
                    while(Collab.usersTagMap.hasOwnProperty(handle) && Collab.usersTagMap[handle].deleted !== "1") {
                        handle += "+";
                    }
                    Collab.usersMap[user.uid] = jQuery.extend({"uid": user.uid}, {"tag": handle}, user.info);
                    Collab.usersTagMap[handle] = jQuery.extend({"uid": user.uid, "tag": handle}, user.info);
                });
                if(!!window.raw_store_data && !!window.raw_store_data.group) {
                    var grp_info = window.raw_store_data.group;
                    Collab.groupsTagMap = {};
                    grp_info.forEach( function (grp) {
                        var grp_name = grp.name.trim().toLowerCase().replace(/\s+/g, "-");
                        if(Collab.usersTagMap.hasOwnProperty(grp_name) && Collab.usersTagMap[grp_name].deleted !== "1") {
                            grp_name += "*";
                        }
                        while(Collab.groupsTagMap.hasOwnProperty(grp_name)) {
                            grp_name += "*";
                        }
                        Collab.groupsMap[grp.id] = jQuery.extend({"tag": grp_name}, grp);
                        Collab.groupsTagMap[grp_name] = grp.id;
                    });
                }
                uiIniter();
                _COLLAB_PVT.ChatApi.markOnline(_COLLAB_PVT.onHeartBeat);
            });

        },
        disconnected: function(response) {
            App.CollaborationUi.onDisconnectHandler(response);
        },
        reconnected: function(response) {
            App.CollaborationUi.onReconnecthandler(response);
        },
        // TODO (mayank): This Call will be moved to Rails Backend
        updateUser: function(id, name, mail, cb) {
            var userData = {
              "uid": String(id),
              "info": {
                  "name": name,
                  "email": mail || name + "@freshdesk.com",
              }
            };
            _COLLAB_PVT.ChatApi.updateUser(userData, function(response) {
                _COLLAB_PVT.updateLocalUserModel(response);
                if(typeof cb === "function") {cb(response);}
            });
        },
        updateLocalUserModel: function(response) {
            Collab.usersMap[response.uid] = jQuery.extend(Collab.usersMap[response.uid] || {}, {
                "uid": response.uid,
                "name": response.info.name,
                "lastActive": response.last_online_at ? Collab.parseUTCDateToLocal(response.last_online_at).getTime() : 0
            }, response.info || {});
        },
        onMessageHandler: function(msg) {
            // Rendering will be handled by addMessageHtml based on message Type
            var sent_by_me = (msg.s_id === Collab.currentUser.uid);
            var msg_for_current_convo = (!!Collab.currentConversation && msg.co_id === Collab.currentConversation.co_id);

            if(msg_for_current_convo && !sent_by_me) {
                if(msg.m_type === CONST.MSG_TYPE_TYPING) {
                    App.CollaborationUi.addTypingHtml(msg);
                } else if(msg.m_type === CONST.MSG_TYPE_READ_RECEIPT) {
                    App.CollaborationUi.updateReadReceipt(msg);
                } else {
                    msg.incremental = true;
                    App.CollaborationUi.addMessageHtml(msg, CONST.TYPE_RECEIVED);
                }
            }
            if (msg_for_current_convo && sent_by_me && msg.m_type !== CONST.MSG_TYPE_TYPING && msg.m_type !== CONST.MSG_TYPE_READ_RECEIPT) {
                App.CollaborationUi.updateSentMessage(msg);
                _COLLAB_PVT.updateConvoMeta(msg); /* stores metadata per convo */
            }
        },
        onErrorHandler: function(response) {
            App.CollaborationUi.hideDiscussBtn(response);
            console.warn("Could not start collaboration api. Unknown Error.");
        },
        onMemberAdd: function(response){
                var body = App.CollaborationUi.parseJson(response.body);
                if(!!body.last_online_at) {
                    Collab.usersMap[body.user_id].lastActive = Collab.parseUTCDateToLocal(body.last_online_at).getTime();
                }

                if(!Collab.conversationsMap[response.co_id].members[body.user_id]){
                    var param = {};
                    if(Collab.usersMap[body.user_id]) {
                        param[body.user_id] = Collab.usersMap[body.user_id];
                        param[body.user_id]["added_at"] = response.created_at;
                        App.CollaborationUi.updateCollaboratorsList(param);
                    } else {
                        Collab.getUserInfo(body.user_id, function(user_info) {
                            _COLLAB_PVT.updateLocalUserModel(user_info);
                            var user_info_map = {};
                            user_info_map[body.user_id] = {"added_at": user_info.created_at};
                            App.CollaborationUi.updateCollaboratorsList(user_info_map);
                        });
                    }
                }
        },
        onMemberRemove: function(response){
            var userIdToRemove = App.CollaborationUi.parseJson(response.body).user_id;
            var members = Collab.conversationsMap[response.co_id].members;
            if(!!members[userIdToRemove]){
                App.CollaborationUi.removeCollaboratorsFromList(userIdToRemove);
            }
        },
        onFollowerAdd: function(response) {
            var currentConvo = Collab.conversationsMap[response.co_id];
            var respBody = App.CollaborationUi.parseJson(response.body);
            var followers = currentConvo.followers || {};
            var followerToAdd = {
                added_at: respBody.added_at
            };
            if (!followers[respBody.user_id]) {
                followers[respBody.user_id] = followerToAdd;
                currentConvo.followers = followers;
            }
            if(respBody.user_id === Collab.currentUser.uid) {
              App.CollaborationUi.updateFollowConvoUi(true);
            }
        },
        onFollowerRemove: function(response) {
            var currentConvo = Collab.conversationsMap[response.co_id];
            var userIdToRemove = App.CollaborationUi.parseJson(response.body).user_id;
            var followers = currentConvo.followers;
            if (followers && followers[userIdToRemove]) {
                delete currentConvo.followers[userIdToRemove];
            }
            if(userIdToRemove === Collab.currentUser.uid) {
              App.CollaborationUi.updateFollowConvoUi(false);
            }
        },
        onNotifyHandler: function(response) {
            Collab.notificationsMap[response.nid] = Collab.notificationsMap[response.nid] || [];
            Collab.notificationsMap[response.nid].push(response);
            /*
                This is yet to be decided in the UX:
                commenting for now
                _COLLAB_PVT.showNotification(response);
            */
            Collab.unreadNotiCount++;

            response.body = App.CollaborationUi.parseJson(response.body);

            var notificationIsForOpenedCollab = (!!Collab.currentConversation && Collab.currentConversation.co_id === response.body.co_id);
            if(App.CollaborationUi.isCollabOpen() && notificationIsForOpenedCollab) {
                Collab.markNotification([response.nid]);
                response.is_read = true;
                // Collab.unreadNotiCount will reduce to once from markRead call
            }

            App.CollaborationUi.addNotificationHtml(response);
        },
        onHeartBeat: function(user) {
            Collab.usersMap[user.uid].lastActive = Collab.parseUTCDateToLocal(user.last_online_at).getTime();
        },
        getAnnotationEvents: function() {
            return App.CollaborationUi.annotationEvents;
        },
        emptyNotificationList: function() {
            $("#collab-notification-list").find("li:not(.info)").remove();
        },
        showNotification: function(response) {
            var notifyBox = $(JST[CONST.NOTIFICATION_POPUP_CARD_TEMPLATE]({notification: App.CollaborationUi.parseJson(response.body)}));
            $("body").append(notifyBox);
            setTimeout(function(){notifyBox.fadeOut()}, 2000);
            setTimeout(function(){notifyBox.remove()}, 5000);
        },
        updateConvoMeta: function(msg) {
            var annotationData;
            if(!!msg.metadata) {
                annotationData = App.CollaborationUi.parseJson(msg.metadata).annotations;
            }

            if(!!annotationData) {
                annotationData.messageId = msg.mid;
                var meta_operations = [ {
                        "operator": "add",
                        "property": "annotations",
                        "type": "string_set",
                        "value": [JSON.stringify(annotationData)]}
                    ];
                var metadata = {
                    "co_id": msg.co_id,
                    "operations": meta_operations,
                    "token": Collab.currentConversation.token
                };

                _COLLAB_PVT.ChatApi.updateConvoMeta(metadata, function(response, isErr) {
                    if(isErr) {
                        _COLLAB_PVT.refreshConvoToken(function() {
                            metadata.token = Collab.currentConversation.token;
                            _COLLAB_PVT.ChatApi.updateConvoMeta(metadata);
                        });
                    }
                });
            }
        },

        refreshConvoToken: function(cb) {
            var ticket_id = Collab.currentConversation.co_id;
            if(typeof ticket_id !== "undefined" && ticket_id !== null) {
                var collab_access_token = App.CollaborationUi.getUrlParameter("token");
                var refreshUrl = '/helpdesk/tickets/collab/'+ ticket_id + '/convo_token'
                if(collab_access_token) {
                    refreshUrl +=  "?token=" + collab_access_token;
                }
                jQuery.ajax({
                    url: refreshUrl,
                    type: 'GET',
                    contentType: 'application/json; charset=utf-8',
                    success: function(response){
                        if(typeof response !== "undefined") {
                            _COLLAB_PVT.updateConvoToken(response);
                            if(typeof cb === "function") {cb()}
                        }
                    },
                    error: function() {
                        console.log("refresh Convo Token failed!! New token could not be retrieved");
                    }
                });
            } else {
                console.log("refresh Convo Token failed!! Ticket ID not found!");
            }
        },

        updateConvoToken: function(data) {
            if(typeof data !== "undefined" && typeof Collab.currentConversation !== "undefined") {
                //update currentconversation token
                Collab.currentConversation.token = data.convo_token;
                if(typeof Collab.conversationsMap[Collab.currentConversation.co_id] !== "undefined")
                {
                    //update conversion map
                    Collab.conversationsMap[Collab.currentConversation.co_id].token = data.convo_token;
                }

                //update dom value
                var ticket_payload = App.CollaborationUi.parseJson($("#collab-ticket-payload").data("ticketPayload"));
                ticket_payload.convo_token = data.convo_token;
                $("#collab-ticket-payload").attr("data-ticket-payload", JSON.stringify(ticket_payload));
            }
        },
  
        sendReadReceipt: function(msgId) {
            var currentConvo = Collab.currentConversation;
            if (!Collab.conversationsMap[currentConvo.co_id]) {
                // Conversation doesn't exists or there is no message in msgBody
                return;
            }

            var msg = {
                "body": JSON.stringify({
                    "mid": msgId
                }),
                "m_type": CONST.MSG_TYPE_READ_RECEIPT,
                "ts": Date.now().toString(),
                "persist": false
            }
            Collab.sendMessage(msg, currentConvo.co_id);
        }
    };

    var Collab = {
        conversationsMap: {},
        usersMap: {},
        usersTagMap: {},
        groupsMap: {},
        groupsTagMap: {},
        notificationsMap: {},
        unreadNotiCount: 0,
        invalidAnnotationMessages: [],
        profileImages: {},
        selectionInfo: {},
        features: {
            groupMentionsEnabled: false,
            replyToEnabled: false,
            collabTourEnabled: false,
            markReadEnabled: false,
            followerEnabled: false,
            readReceiptEnabled: false
        },

        isOnline: function(userId) {
            var is_online = false;
            if(Collab.usersMap[userId]) {
                if(!Collab.usersMap[userId].lastActive){
                    Collab.usersMap[userId].lastActive = 0;
                }
                is_online = Math.floor((new Date().getTime() - Collab.usersMap[userId].lastActive) / 1000) < CONST.MAX_ONLINE_SEC;
            }
            return is_online;
        },
        parseUTCDateToLocal: function(standardUTCDateString) {
            var a = standardUTCDateString.split(/[^0-9]/);
            var localDateObj = new Date(Date.UTC(a[0],a[1]-1,a[2],a[3],a[4],a[5]));
            return localDateObj;
        },
        getCurrentUTCTimeStamp: function() {
            var d = new Date();
            var nano_precision = (window.performance && window.performance.now) ? Math.ceil((performance.now() * 1000000000)).toString().slice(0,9) : (("000"+d.getUTCMilliseconds()).slice(-3) + "000000");
            return d.getUTCFullYear() + "-" + ("0"+(d.getUTCMonth()+1)).slice(-2) + "-" + ("0"+(d.getDate())).slice(-2) + " " + ("0"+(d.getUTCHours())).slice(-2) + ":" + ("0"+(d.getUTCMinutes())).slice(-2) + ":" + ("0"+(d.getUTCSeconds())).slice(-2) + "." + nano_precision + " +0000 UTC";
        },
        refreshAttachmentUri: function(fid, cb) {
            var convoObj = {
                "token": Collab.currentConversation.token,
                "fid": fid,
                "co_id": Collab.currentConversation.co_id
            }
            _COLLAB_PVT.ChatApi.refreshAttachmentUri(convoObj, function(response, isErr) {
                if(isErr) {
                    _COLLAB_PVT.refreshConvoToken(function() {
                        convoObj.token = Collab.currentConversation.token;
                        _COLLAB_PVT.ChatApi.refreshAttachmentUri(convoObj, cb);
                    });
                } else {
                    if(typeof cb === "function") {cb(response);}
                }
            });
        },
        sendMessage: function(m, co_id, cb) {
            var msg = {
                "mid": m.mid,
                "metadata": m.metadata,
                "body": m.body,
                "m_type": m.m_type,
                "attachment_link": m.attachment_link,
                "ts": m.ts,
                "persist": m.persist
            };

            var convo = {
                "co_id": co_id,
                "token": Collab.currentConversation.token
            };

            _COLLAB_PVT.ChatApi.sendMessage(msg, convo, function(response, isErr) {
                    if(isErr) {
                        // Refresh Convo Token
                        _COLLAB_PVT.refreshConvoToken(function() {
                            convo.token = Collab.currentConversation.token;
                            if (typeof response === 'string' && response === CONST.RESPONSE_ERROR_ACTION_NOT_AUTHORIZED) {
                                // This situation will arise only for created conversations after 24 hrs of inactivity and we have to refresh rtstoken
                                var convoRTSTokenRefresh = {
                                  'co_id': convo.co_id,
                                  'token': convo.token
                                };
                                var myId = Collab.currentUser.uid;
                                _COLLAB_PVT.ChatApi.getRtsAuthToken(convoRTSTokenRefresh, myId, function(response, isErr) {
                                    // convo token is already refreshed so no need to refresh here again
                                    _COLLAB_PVT.ChatApi.sendMessage(msg, convo, cb);
                                })
                            } else {
                                _COLLAB_PVT.ChatApi.sendMessage(msg, convo, cb);
                            }
                        });
                    } else {
                        if(typeof cb === "function") {cb(response);}
                    }
            });
        },
        updateReadMarker: function(msgId, cb) {
            var convo_id = Collab.currentConversation.co_id;
            var current_user_id = Collab.currentUser.uid;

           _COLLAB_PVT.ChatApi.updateReadMarker(convo_id, current_user_id, msgId, cb);
           if(Collab.features.readReceiptEnabled) {
             _COLLAB_PVT.sendReadReceipt(msgId);
           }
        },
        checkNotiKeys: function(msg) {
            meta = JSON.parse(msg.metadata)
            for(var i in CONST.NOTI_KEYS) {
                if(meta.hasOwnProperty(CONST.NOTI_KEYS[i])){
                    return true;
                }
            }
            return false;
        },
        sendNotification: function(msg) {
            var ticket_id = Collab.currentConversation.co_id;
            if(!!ticket_id) {
                var collab_access_token = App.CollaborationUi.getUrlParameter("token");
                var currentConvo = Collab.conversationsMap[ticket_id];
                var message_data = {
                    mid: msg.mid
                };
                if(collab_access_token) {
                    message_data.token = collab_access_token;
                }
                if (Collab.features.followerEnabled && Object.keys(currentConvo.followers).length !== 0) {
                    var followers = currentConvo.followers;
                    var followersInfo = [];
                    for (var userId in followers) {
                        if (followers.hasOwnProperty(userId)) {
                            followersInfo.push({
                                follower_id: userId
                            });
                        }
                    }
                    var members = currentConvo.members;
                    var topMembersInfo = [];
                    var topCount = 3;
                    for (var memberId in members) {
                        if (topCount === 0) {
                            break;
                        }
                        if (members.hasOwnProperty(memberId)) {
                            topMembersInfo.push({
                                member_id: memberId
                            });
                            topCount--;
                        }
                    }
                    if (msg.metadata) {
                        message_data.metadata = App.CollaborationUi.parseJson(msg.metadata);
                    }
                    message_data.metadata = message_data.metadata || {};
                    message_data.metadata.follower_notify = followersInfo;
                    message_data.top_members = App.CollaborationUi.stringify(topMembersInfo);
                    message_data.m_ts = Date.now().toString();
                    message_data.m_type = msg.m_type;
                    message_data.body = msg.m_type === CONST.MSG_TYPE_CLIENT_ATTACHMENT ? JSON.parse(msg.body).fn : msg.body;
                } else if (msg.metadata && Collab.checkNotiKeys(msg)) {
                    message_data.metadata = App.CollaborationUi.parseJson(msg.metadata);
                    message_data.body = msg.body;
                }

                if (message_data.metadata) {
                    message_data.metadata = App.CollaborationUi.stringify(message_data.metadata);
                    var jsonData = App.CollaborationUi.stringify(message_data);
                    jQuery.ajax({
                        url: '/helpdesk/tickets/collab/' + ticket_id + '/notify',
                        type: 'POST',
                        dataType: 'json',
                        data: jsonData,
                        contentType: 'application/json; charset=utf-8'
                    });
                }
            } else {
                console.log("Sending notification failed!! Ticket ID not found!");
            }
        },
        formatTimestamp: function(age) {  // in seconds
            if (age > 60 * 86400) {
                return CONST.LONG_AGO_TEXT;
            }
            for (var i = 0; i < CONST.TIME_CHUNKS.length; ++i) {
                var n = Math.floor(age / CONST.TIME_CHUNKS[i][0]);
                if (n > 0) { return n + CONST.TIME_CHUNKS[i][1]; }
            }
            // Keeping exact seconds requires refreshing it dynamically.
            return CONST.JUST_NOW_TEXT;
        },
        collaboratorsGetPresence: function() {
            var collaborators = [];
            var collaboratorsMap = {};
            var convo = Collab.conversationsMap[Collab.currentConversation.co_id];
            if(!!convo) {
                var convoMembers = convo.members;
                for(var id in convoMembers) {
                    if(convoMembers.hasOwnProperty(id)) {
                        collaborators.push(id);
                    }
                }

                _COLLAB_PVT.ChatApi.getPresence(collaborators, function(response) {
                    if(typeof response === "string") { response = App.CollaborationUi.parseJson(response); }
                    for (var i = response.length - 1; i >= 0 && !!response[i].uid && Collab.usersMap[response[i].uid]; i--) {
                        Collab.usersMap[response[i].uid].lastActive = response[i].last_online_at ?
                            Collab.parseUTCDateToLocal(response[i].last_online_at).getTime() : 0 ;
                        collaboratorsMap[response[i].uid] = response[i];
                    }
                    App.CollaborationUi.updateCollaboratorsList(collaboratorsMap);
                });
            } else {
                window.clearInterval(window.getPresenceIval);
            }
        },
        getNotifications: function() {
            _COLLAB_PVT.emptyNotificationList();
            _COLLAB_PVT.ChatApi.getNotifications(Collab.currentUser.uid, function(response) {
                var notifications = response.noti;
                // TODO (ankit): manager respone.start and further fetching if (start != "")
                Collab.unreadNotiCount = 0;
                for (var i = notifications.length - 1; i >= 0; i--) {
                    notifications[i].body = App.CollaborationUi.parseJson(notifications[i].body);

                    if(!notifications[i].is_read) {
                        Collab.unreadNotiCount++;
                    }
                    Collab.notificationsMap[notifications[i].nid] = notifications[i];
                    App.CollaborationUi.addNotificationHtml(notifications[i]);
                }

                if(!notifications.length) {
                    $("#collab-notification-dd").find("li.info").show();
                }
                if(!!response.collab_count) {
                    $("#notifiaction-total-collab").text("("+response.collab_count+")");
                }
            });
        },
        notify: function(userId, notifyBody, ticketId) {
            _COLLAB_PVT.ChatApi.notifyUser(userId, notifyBody, ticketId);
        },

        followConvo: function(follow) {
            var convo = {
                "co_id": Collab.currentConversation.co_id,
                "token": Collab.currentConversation.token
            }
            var followCb = function(resp) {
              _COLLAB_PVT.onFollowerAdd({co_id: convo.co_id, body: {user_id: Collab.currentUser.uid, added_at: new Date()}});
            }
            var unfollowCb =  function(resp) {
              _COLLAB_PVT.onFollowerRemove({co_id: convo.co_id, body: {user_id: Collab.currentUser.uid}});
            }
            if(follow) {
              _COLLAB_PVT.ChatApi.addFollower(convo, Collab.currentUser.uid, function(response, isErr) {

                if(isErr) {
                    _COLLAB_PVT.refreshConvoToken(function() {
                        convo.token = Collab.currentConversation.token;
                        _COLLAB_PVT.ChatApi.addFollower(convo, Collab.currentUser.uid, followCb)
                    })
                } else {
                    followCb(response);
                }
              });
            } else {
              _COLLAB_PVT.ChatApi.removeFollower(convo, Collab.currentUser.uid, function(response, isErr) {
                if(isErr) {
                    _COLLAB_PVT.refreshConvoToken(function() {
                        convo.token = Collab.currentConversation.token;
                        _COLLAB_PVT.ChatApi.removeFollower(convo, Collab.currentUser.uid, unfollowCb)
                    })
                } else {
                    unfollowCb(response);
                }

              });
            }
        },

        addMember: function(convoName, uid, cb) {
            var convo = {
                "co_id": convoName,
                "token": Collab.currentConversation.token
            }
            _COLLAB_PVT.ChatApi.addMember(convo, uid, function(response, isErr) {
                if(isErr) {
                    _COLLAB_PVT.refreshConvoToken(function() {
                        convo.token = Collab.currentConversation.token;
                        _COLLAB_PVT.ChatApi.addMember(convo, uid, function(response) {
                            Collab.conversationsMap[response.co_id].members = response.members;
                            Collab.collaboratorsGetPresence();
                            if(typeof cb === "function") cb(response);
                        });
                    });

                } else {
                    Collab.conversationsMap[response.co_id].members = response.members;
                    Collab.collaboratorsGetPresence();
                    if(typeof cb === "function") cb(response);
                }

            });
        },
        updateTicketCloseStatus: function(is_closed) {
            var convo = {
                "co_id": Collab.currentConversation.co_id,
                "token": Collab.currentConversation.token
            };
            if(is_closed) {
                _COLLAB_PVT.ChatApi.closeConversation(convo, function (response, isErr) {
                    if(isErr) {
                        _COLLAB_PVT.refreshConvoToken(function() {
                            convo.token = Collab.currentConversation.token;
                            _COLLAB_PVT.ChatApi.closeConversation(convo);
                        });
                    }
                });
            } else {
                _COLLAB_PVT.ChatApi.openConversation(convo, function (response, isErr) {
                    if(isErr) {
                        _COLLAB_PVT.refreshConvoToken(function() {
                            convo.token = Collab.currentConversation.token;
                            _COLLAB_PVT.ChatApi.openConversation(convo);
                        });
                    }
                });
            }
        },
        createConversation: function(c, cb) {
            var convo = {
                "members": c.members,
                "co_id": c.co_id,
                "owned_by": c.owned_by,
                "token": Collab.currentConversation.token,
                "name": Collab.currentConversation.name,
                "notify_version": App.CollaborationUi.notifyVersion
            };
            _COLLAB_PVT.ChatApi.createConversation(convo, function(response, isErr) {
                    if(isErr) {
                        _COLLAB_PVT.refreshConvoToken(function() {
                            convo.token = Collab.currentConversation.token;
                            _COLLAB_PVT.ChatApi.createConversation(convo, cb);
                        });
                    } else {
                        if(typeof cb === "function") {cb(response);}
                    }
            });
        },
        loadConversation: function(cb) {
            var self = this;
            var convo = {
                "co_id": Collab.currentConversation.co_id,
                "token": Collab.currentConversation.token
            };
            Collab.invalidAnnotationMessages=[];
            _COLLAB_PVT.ChatApi.loadConversation(convo,
                Collab.currentUser.uid,
                function(response, isErr) {
                    if(isErr) {
                        _COLLAB_PVT.refreshConvoToken(function() {
                            convo.token = Collab.currentConversation.token;
                            _COLLAB_PVT.ChatApi.loadConversation(convo, Collab.currentUser.uid, cb);
                        });
                    } else {
                        if(typeof cb === "function") {cb(response);}
                    }
                }
            );
        },

        markNotification: function(notifiactionIds, cb) {
            // check for any; since group is based on is_read status
            if(!Collab.notificationsMap[notifiactionIds[0]].is_read) {
                _COLLAB_PVT.ChatApi.markNotification({
                    uid: Collab.currentUser.uid,
                    nids: notifiactionIds
                }, cb);
                notifiactionIds.forEach(function(nid) {
                    Collab.notificationsMap[nid].is_read = true;
                    Collab.unreadNotiCount--;
                });
            } else {
                console.log("Notification is read; redirecting.", notifiactionIds);
                cb();
            }
        },

        markAnnotation: function() {
            return _COLLAB_PVT.Annotations.markAnnotation();
        },

        restoreAnnotations: function(ann_meta) {
            var status;
            if(ann_meta) {
                if(!ann_meta.highlighted) {
                    ann_meta.highlighted  = _COLLAB_PVT.Annotations.restoreAnnotation(ann_meta);
                }
            } else {
                for(var k in Collab.annotationsMap) {
                    if(Collab.annotationsMap.hasOwnProperty(k)) {
                        Collab.annotationsMap[k].forEach(function(ann) {
                            if(!ann.highlighted) {
                                status = _COLLAB_PVT.Annotations.restoreAnnotation(ann.annotation);
                                ann.highlighted = status.success;
                                ann.note_hidden = status.note_hidden;

                                if(!ann.highlighted && !ann.note_hidden) {
                                    ann.invalid = true;
                                    Collab.invalidAnnotationMessages = Collab.invalidAnnotationMessages || [];

                                    if(Collab.invalidAnnotationMessages.indexOf(ann.annotation.messageId) === -1) {
                                        Collab.invalidAnnotationMessages.push(ann.annotation.messageId);
                                        App.CollaborationUi.invalidateAnnotationMessage(ann.annotation.messageId);
                                    }
                                }
                            }
                        });
                    }
                }
            }
        },

        getSelectionInfo: function () {
            return Collab.selectionInfo;
        },

        setSelectionInfo: function() {
            var annotatorId = Collab.currentUser.uid;
            Collab.selectionInfo = _COLLAB_PVT.Annotations.getSelectionInfo(annotatorId);
            return Collab.selectionInfo;
        },

        resetSelectionInfo: function () {
            Collab.selectionInfo = {};
        },

        fetchMoreMessages: function(p, cb){
            var param = {
                "co_id": p.co_id,
                "start": p.start,
                "limit": p.limit,
                "token": Collab.currentConversation.token
            };
            _COLLAB_PVT.ChatApi.getMessages(param, function(response, isErr) {
                if(isErr) {
                    _COLLAB_PVT.refreshConvoToken(function() {
                        param.token = Collab.currentConversation.token;
                        _COLLAB_PVT.ChatApi.getMessages(param, cb);
                    });
                } else {
                    if(typeof cb === "function") {cb(response);}
                }
            });
        },

        uploadAttachment: function(fd, cb){
            var convo = {
                "formData": fd,
                "token": Collab.currentConversation.token
            };
            _COLLAB_PVT.ChatApi.uploadAttachment(convo, function(response, isErr) {
                if(isErr) {
                    _COLLAB_PVT.refreshConvoToken(function() {
                        convo.token = Collab.currentConversation.token;
                        _COLLAB_PVT.ChatApi.uploadAttachment(convo, cb);
                    });
                } else {
                    if(typeof cb === "function") {cb(response);}
                }
            });
        },

        setConvoOwner: function(co_id, uid, cb) {
            var convo = {
                "co_id": co_id,
                "token": Collab.currentConversation.token,
                "name": Collab.currentConversation.name
            }
            _COLLAB_PVT.ChatApi.setConvoOwner(convo, uid, function(response, isErr) {
                if(isErr) {
                    _COLLAB_PVT.refreshConvoToken(function() {
                        convo.token = Collab.currentConversation.token;
                        _COLLAB_PVT.ChatApi.setConvoOwner(convo, uid, cb);
                    });
                } else {
                    if(typeof cb === "function") {cb(response);}
                }
            });
        },

        getUserInfo: function(uid, cb) {
            _COLLAB_PVT.ChatApi.getUserInfo(uid, cb);
        },

        activateBellListeners: function() {
            // Bell-click listener
            jQuery(document).on("click.collab_head", "#bell-icon-link", function() {
                if(jQuery("#collab-notification-dd").hasClass("hide")) {
                    if(Collab.usersMap && !!Object.keys(Collab.usersMap).length) {
                        // Collab.getNotifications();
                    }
                }
                jQuery("#collab-notification-dd").toggleClass("hide");
            });
            jQuery(document).on("click.collab_head", function(e) {
                if(!jQuery(e.target).parents("#bell-icon-link").length) {
                    jQuery("#collab-notification-dd").addClass("hide");
                }
            });
            App.CollaborationUi.activateBellListeners();
        },
        markNotiReadForCollabOpen: function(noti) {
            var notiForCurrentCollab = (!!Collab.currentConversation && Collab.currentConversation.co_id === noti.ticket_id);
            if(notiForCurrentCollab && App.CollaborationUi.isCollabOpen()) {
                var noti_elem = jQuery('.notifications-list a[data-unread-ids="'+noti.noti_id+'"]');
                App.UserNotification.markNotificationRead(noti_elem, function(){
                    console.log("READ: ", arguments);
                });
            }
        },

        init: function() {
            var config = App.CollaborationUi.parseJson($("#collab-account-payload").data("accountPayload"));
            // TODO(aravind): Add all fields.
            Collab.currentUser = config.user;

            _COLLAB_PVT.ChatApi = new ChatApi({
                "clientId": config.client_id,
                "clientAccountId": config.client_account_id,
                "userId": config.user.uid,
                "initAuthToken": config.init_auth_token,
                "chatApiServer": config.collab_url,
                "rtsServer": config.rts_url,

                "onconnect": _COLLAB_PVT.connectionInited,
                "ondisconnect": _COLLAB_PVT.disconnected,
                "onreconnect": _COLLAB_PVT.reconnected,
                "onmessage": _COLLAB_PVT.onMessageHandler,
                "onnotify": _COLLAB_PVT.onNotifyHandler,
                "onheartbeat": _COLLAB_PVT.onHeartBeat,
                "onmemberadd": _COLLAB_PVT.onMemberAdd,
                "onmemberremove": _COLLAB_PVT.onMemberRemove,
                "onfolloweradd": _COLLAB_PVT.onFollowerAdd,
                "onfollowerremove": _COLLAB_PVT.onFollowerRemove,
                "onerror": _COLLAB_PVT.onErrorHandler,
                "apiinited": _COLLAB_PVT.apiInited
            });

            if(typeof Annotation !== "undefined") {
                _COLLAB_PVT.Annotations = new Annotation({
                    "annotationevents": _COLLAB_PVT.getAnnotationEvents(),
                    "wrapper_elem_style": "background-color: "+ CONST.ANNOTATION.bg_color +"; line-height: 18px; box-shadow: 1px 1px 0 "+ CONST.ANNOTATION.shadow_color +"; border-radius: 1px; border: 1px solid "+ CONST.ANNOTATION.border_color +"; color:#333333; padding: 0 2px;"
                });
            } else {
                console.warn("Annotations sdk not present. couldn't start annotations.");
            }
            window.$kapi = _COLLAB_PVT.ChatApi;

            if(typeof App.CollaborationEmoji !== "undefined") {
                App.CollaborationEmoji.init();
            }
        }
    };
    return Collab;
})(window.jQuery);
