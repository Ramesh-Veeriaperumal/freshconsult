/*
*   For collaboration feature.
*   To be included in _head.html.erb
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
        JUST_NOW_TEXT: "Now",
        LONG_AGO_TEXT: "Long ago",
        MAX_ONLINE_SEC: 60,
        MONTHS: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
        TIME_CHUNKS: [[60 * 60 * 24, "d"], [60 * 60, "h"], [60, "m"]],
        NOTIFICATION_POPUP_CARD_TEMPLATE: "collaboration/templates/notification_popup_card",
        DUMMY_USER: {name: "New user"}
    };

    var _COLLAB_PVT = {
        ChatApi: {},
        connectionInited : function() {
            Collab.MEMBER_PRESENCE_POLL_TIME = _COLLAB_PVT.ChatApi.memberPresencePollTime;
            // TODO(mayank): mergo updates DB with nil data
            // This is supposed to update latest self_info; Avoiding this temporarily; 
            // _COLLAB_PVT.UpdateUser(Collab.currentUser.uid, Collab.currentUser.name, Collab.currentUser.email)
            

            _COLLAB_PVT.ChatApi.getAllUsers(function(response) {
                var users = response.users;
                // TODO (ankit): manage response.start and futher fetching if(start != "")
                users.forEach(function(user) {
                    Collab.usersMap[user.uid] = jQuery.extend({"uid": user.uid}, user.info);
                });

                if(Collab.usersMap && !!Object.keys(Collab.usersMap).length) {
                    Collab.getNotifications();
                }
            });

            function uiIniter() {
                Collab.initedWithData = true;
                // call initUI if pending config found
                if(typeof App.CollaborationUi !== "undefined" && !!App.CollaborationUi.pendingConfig) {
                    App.CollaborationUi.initUi(App.CollaborationUi.pendingConfig);
                    delete App.CollaborationUi.pendingConfig;
                }
            }

            // HK module
            if(typeof ProfileImage !== "undefined") {
                ProfileImage.fetch(uiIniter);
            } else {
                uiIniter();
            }
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
            var is_open_collab_view = !!$("#collab-sidebar.expand").length;
            var sent_by_me = (msg.s_id === Collab.currentUser.uid);
            var msg_for_opend_collab = (!!Collab.currentConversation && msg.co_id === Collab.currentConversation.co_id);

            if(is_open_collab_view && msg_for_opend_collab && !sent_by_me) {
                msg.incremental = true;
                App.CollaborationUi.addMessageHtml(msg, CONST.TYPE_RECEIVED);
            }
            if(sent_by_me) {
                _COLLAB_PVT.updateConvoMeta(msg); /* stores metadata per convo */
            }
        },
        onErrorHandler: function(response) {
            App.CollaborationUi.hideDiscussBtn(response);
            console.warn("Could not start collaboration. Unknown Error.");
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
                _COLLAB_PVT.ChatApi.updateConvoMeta(metadata);
            }
        }
    };

    var Collab = {
        conversationsMap: {},
        usersMap: {},
        notificationsMap: {},
        unreadNotiCount: 0,
        invalidAnnotationMessages: [],

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
            _COLLAB_PVT.ChatApi.refreshAttachmentUri(convoObj, cb);
        },
        sendMessage: function(m, co_id, cb) {
            var msg = {
                "mid": m.mid,
                "metadata": m.metadata,
                "body": m.body,
                "m_type": m.m_type,
                "attachment_link": m.attachment_link
            };
            var convo = {
                "co_id": co_id,
                "token": Collab.currentConversation.token
            };
            _COLLAB_PVT.ChatApi.sendMessage(msg, convo, cb);
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
            _COLLAB_PVT.ChatApi.notifyUser(userId, notifyBody, ticketId)
        },
        addMember: function(convoName, uid, cb) {
            var convo = {
                "co_id": convoName,
                "token": Collab.currentConversation.token
            }
            _COLLAB_PVT.ChatApi.addMember(convo, uid, function(response) {
                Collab.conversationsMap[response.co_id].members = response.members;
                Collab.collaboratorsGetPresence();
                if(typeof cb === "function") cb(response);
            });
        },
        updateTicketCloseStatus: function(is_closed) {
            var convo = {
                "co_id": Collab.currentConversation.co_id,
                "token": Collab.currentConversation.token
            };
            if(is_closed) {
                _COLLAB_PVT.ChatApi.closeConversation(convo);
            } else {
                _COLLAB_PVT.ChatApi.openConversation(convo);
            }
        },
        createConversation: function(c, cb) {
            var convo = {
                "members": c.members,
                "co_id": c.co_id,
                "owned_by": c.owned_by,
                "token": Collab.currentConversation.token
            };
            _COLLAB_PVT.ChatApi.createConversation(convo, cb);
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
                cb);
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

        getSelectionInfo: function() {
            var annotatorId = Collab.currentUser.uid;
            return _COLLAB_PVT.Annotations.getSelectionInfo(annotatorId);
        },

        fetchMoreMessages: function(p, cb){
            var param = {
                "co_id": p.co_id,
                "start": p.start,
                "limit": p.limit,
                "token": Collab.currentConversation.token
            };
            _COLLAB_PVT.ChatApi.getMessages(param, cb);
        },
        
        uploadAttachment: function(fd, cb){
            var convo = {
                "formData": fd,
                "token": Collab.currentConversation.token
            };
            _COLLAB_PVT.ChatApi.uploadAttachment(convo, cb);
        },

        setConvoOwner: function(co_id, uid, cb) {
            var convo = {
                "co_id": co_id,
                "token": Collab.currentConversation.token
            }
            _COLLAB_PVT.ChatApi.setConvoOwner(convo, uid, cb);
        },

        getUserInfo: function(uid, cb) {
            _COLLAB_PVT.ChatApi.getUserInfo(uid, cb);
        },

        activateBellListeners: function() {
            // Bell-click listener
            jQuery(document).on("click.collab_head", "#bell-icon-link", function() {
                if(jQuery("#collab-notification-dd").hasClass("hide")) {
                    if(Collab.usersMap && !!Object.keys(Collab.usersMap).length) {
                        Collab.getNotifications();
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

        init: function() {
            var config = App.CollaborationUi.parseJson($("#collab-model-data").attr("data-model-payload"));
            // TODO(aravind): Add all fields.
            Collab.currentUser = {
                "name": config.userName,
                "uid": config.userId,
                "email": config.userEmail
            };
            
            _COLLAB_PVT.ChatApi = new ChatApi({
                "clientId": config.clientId,
                "clientAccountId": config.clientAccountId,
                "userId": config.userId,
                "initAuthToken": config.initAuthToken,
                "onconnect": _COLLAB_PVT.connectionInited,
                "ondisconnect": _COLLAB_PVT.disconnected,
                "onreconnect": _COLLAB_PVT.reconnected,
                "onmessage": _COLLAB_PVT.onMessageHandler,
                "onnotify": _COLLAB_PVT.onNotifyHandler,
                "onheartbeat": _COLLAB_PVT.onHeartBeat,
                "onmemberadd": _COLLAB_PVT.onMemberAdd,
                "onmemberremove": _COLLAB_PVT.onMemberRemove,
                "chatApiServer": config.collab_url,
                "rtsServer": config.rts_url,
                "onerror": _COLLAB_PVT.onErrorHandler
            });

            if(typeof Annotation !== "undefined") {
                _COLLAB_PVT.Annotations = new Annotation({
                    "annotationevents": _COLLAB_PVT.getAnnotationEvents(),
                    "wrapper_elem_style": "background-color: #fee4c8; line-height: 18px; box-shadow: 1px 1px 0 lightgrey; border-radius: 1px; border: 1px solid #ebc397; color:#333333; padding: 0 2px;"
                });
            }
            window.$kapi = _COLLAB_PVT.ChatApi;
        }
    };
    return Collab;
})(window.jQuery);
