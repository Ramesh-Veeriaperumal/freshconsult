/*
*	For collaboration feature.
*	DOM related functions fall here.
*	Expects $ to be loaded before it.
*	To be included in _collaboration partial
*
*/ 

App.CollaborationUi = (function ($) {
	
    var CONST = {
        MENTION_RE: /\B@([\S]+)\b/igm,
        IMAGE_TAG_RE: /<img/igm,
        MENTION_EVERYONE_TAG: "@everyone",
        TYPE_SENT: 'sent',
		TYPE_RECEIVED: 'received',
        MSG_TYPE_CLIENT: "1", // Msg from Client
        MSG_TYPE_SERVER_MADD: "2", // Msg from Server, denotes addition of member
        MSG_TYPE_SERVER_MREMOVE: "3", // Msg from Server, denotes removal of member
        MSG_TYPE_CLIENT_ATTACHMENT: "4",
        DEFAULT_PRESENCE_IVAL: 60 * 1000 * 1, // 1 minute
        RETRY_DELAY_FOR_PENDING_DP_REQ: 1000 * 5, // 5sec
        AVATAR_TEMPLATE: "collaboration/templates/avatar",
        COLLABORATORS_LIST_ITEM_TEMPLATE: "collaboration/templates/collaborators_list_item",
        COLLABORATION_MESSAGE_TEMPLATE: "collaboration/templates/collaboration_message",
        NOTIFICATION_LIST_ITEM_TEMPLATE: "collaboration/templates/notification_list_item",
        FETCH_MESSAGE_LIMIT: 50,
        DEFAULT_FETCH_RETRY: 5,
        MAX_JUMBOMOJI_COUNT: 3,
        DEF_PIC_URL: "/assets/misc/profile_blank_thumb.jpg",
        EMOJIS_URL: "/images/emojis/",
        HELPKIT_MAX_COLLABORATORS: 20,
        HIDE_ANIMATION_DURATION: 1000, //ms
        DUMMY_USER: {name: "---"},
        DEFAULT_ERR: "unexpected",
        HIDE_ERROR_DURATION: 3000, //ms
        MAX_UPLOAD_SIZE: "15MB"
    };

    var _COLLAB_PVT = {
        savedScrollHeight:0,
        bellEvents: function() {
            var $collabBell = $("#collab-bell");
            $collabBell.on("mouseenter.collab", ".collab-notification-list", function(event) {
               var el = event.currentTarget;
                _COLLAB_PVT.showScrollBar(el); 
            });
            $collabBell.on("click.collab", ".collab-notification-list .collab-notification-link", function(event) {
                event.preventDefault();
                var noti_ids = $(event.currentTarget).attr("data-noti-ids").split(",");
                
                App.CollaborationModel.markNotification(noti_ids, function() {
                    _COLLAB_PVT.updateNotiCount();
                    window.open(event.currentTarget.getAttribute("data-href"), "_self");
                });
            });            
        },
        events: function(){
            var $collabBtn = $("#sticky_header");
            var $collabSidebar = $("#collab-sidebar");
            var $pagearea = $("#Pagearea");
            var $scrollBox = $("#collab-sidebar #scroll-box");
            
            $collabBtn.on("click.collab", "#collab-btn", _COLLAB_PVT.fetchAndToggleCollab);
            $collabSidebar.on("click.collab", "#collab-close-icon", _COLLAB_PVT.toggleCollabExpand);
            $collabSidebar.on("click.collab", "#collaborators-tab-btn", _COLLAB_PVT.showCollaboratorsListView);
            $collabSidebar.on("click.collab", "#discussion-tab-btn", _COLLAB_PVT.showDiscussionView);
            $collabSidebar.on("mouseover.collab", ".avatar-cover", _COLLAB_PVT.showHoverCard);
            $collabSidebar.on("mouseleave.collab", ".avatar-cover", _COLLAB_PVT.hideHoverCard);
            $collabSidebar.on("mouseleave.collab", "#collab-hovercard-cover", _COLLAB_PVT.hideHoverCard);
            $collabSidebar.on("collabAttachmentImageError.collab", ".collab-attachment-msg .image", function(event) {
                var fid = event.target.getAttribute("data-fid");
                var retry_count = event.target.getAttribute("data-fetch-retry-count");
                if(retry_count === "") {
                    retry_count = 0;
                }
                _COLLAB_PVT.refreshAttachmentUri(event.target, fid, retry_count);
            })
            $pagearea.on("mouseup.collab", ".leftcontent .conversation:not(.activity)", function(event) {
                var containerEl = event.currentTarget;
                _COLLAB_PVT.showAnnotationOption(containerEl);
            });
            $pagearea.on("mouseleave.collab", "#show-discussion-dd", _COLLAB_PVT.hideDiscussionDD);
            $pagearea.on("click.collab", "#collab-option-dd", _COLLAB_PVT.markAnnotation);
            $scrollBox.on("scroll.collab", _COLLAB_PVT.hasChatReachedTop); // scroll doesn't bubble

            $collabSidebar.on("click.enabledCollab", "#collab-send-attachment-button", function(event){
                _COLLAB_PVT.sendAttachmentMessage(event.currentTarget.getAttribute("data-file"));
            });
            $collabSidebar.on("change.enabledCollab", "#collab-attachment-input", function(event) {
                _COLLAB_PVT.uploadFile(event.target.files);
            });
            $scrollBox.on("mouseenter.collab", function(event) {
                var el = event.currentTarget;
                _COLLAB_PVT.showScrollBar(el);
            });
            $collabSidebar.on("click.enabledCollab", "#cancel-annotation", function(event) {
                var msgId = Collab.parseJson($(event.currentTarget).parent(".annotation").attr("data-annotation")).messageId;
                _COLLAB_PVT.cancelAnnotation(msgId);
            });
            $collabSidebar.on("click.enabledCollab", "#collab-attachment-cancel-icon", function(event) {
                _COLLAB_PVT.resetAttachmentFormView();
            });
            $collabSidebar.on("click.collab", "#collaborators-list-items .tag-handle", function(event) {
                _COLLAB_PVT.mentionUser(event.currentTarget.getAttribute("data-mention-text"));
            });
            $collabSidebar.on("mouseenter.collab", "#collaborators-list", function(event) {
               var el = event.currentTarget;
                _COLLAB_PVT.showScrollBar(el); 
            });
            $collabSidebar.on("click.collab", ".annotation-text", function(event) {
                var ann_text = event.currentTarget;
                if(!$(ann_text).hasClass("invalid-annotation")) {
                    if(!!event.target) {
                        var msg_id = $(event.target).parents(".collab-message-box")[0].getAttribute("id").replace("collab-", "");
                        var annotation_e = $("#annotation-" + msg_id);
                        _COLLAB_PVT.scrollToAnnotationHighlight(annotation_e.length ? annotation_e : msg_id, event);
                    }
                } else {
                    console.log("invalid annotation");
                }
            });
            $collabSidebar.on("keydown.enabledCollab", "#send-message-box", function(event) {
                if(event.which === 13 && !event.shiftKey) {
                    event.preventDefault();
                    _COLLAB_PVT.sendMessageSubmit();
                } else if(event.which === 27 && !event.shiftKey) {
                    event.preventDefault();
                    _COLLAB_PVT.fetchAndToggleCollab();
                }
            })
            $pagearea.on("click.collab", "#show-discussion-dd", function(event) {
                var data_msg_id = event.currentTarget.getAttribute('data-message-id');
                _COLLAB_PVT.scrollToMessage(data_msg_id);
            });
            
            $collabSidebar.on('click.collab', "#collab-hovercard-cover", function(event){
                _COLLAB_PVT.mentionUser(event.currentTarget.getAttribute("data-mention-text"));
                _COLLAB_PVT.hideHoverCard(null, true); // forceHide=true
            });

            $(document).on('click.collab', function(event) {
                // Hide annotation option when click is outside the annotation-allowed area; 
                // for inside, there is a different handler working.
                if(!$(event.target).parents(".leftcontent .conversation:not(.activity)").length) {
                    _COLLAB_PVT.hideAnnotationOption();
                }
            })
        },

        showCollaboratorsListView: function() {
            $("#collab-chat-section").removeClass("active");
            $("#collaborators-list").addClass("active");
            $("#discussion-tab-btn").removeClass("active");
            $("#collaborators-tab-btn").addClass("active");
        },

        showDiscussionView: function() {
            $("#collab-chat-section").addClass("active");
            $("#collaborators-list").removeClass("active");
            $("#discussion-tab-btn").addClass("active");
            $("#collaborators-tab-btn").removeClass("active");
        },

        markAnnotation: function() {
            _COLLAB_PVT.hideAnnotationOption();
            _COLLAB_PVT.cancelTempAnnotationIfAny();
            _COLLAB_PVT.showDiscussionView();

            var response = App.CollaborationModel.markAnnotation();

            if(!Collab.isCollabOpen()) {
                Collab.loadConversation(function() {
                    _COLLAB_PVT.cancelTempAnnotationIfAny();
                    App.CollaborationModel.restoreAnnotations(response.annotation.selectionMeta);
                    prepareDataMarkAnnotation();
                    _COLLAB_PVT.toggleCollabExpand(true);
                });
            } else {
                prepareDataMarkAnnotation();
                _COLLAB_PVT.toggleCollabExpand(true);
            }

            function prepareDataMarkAnnotation() {
                if(!!response.status) {
                    var $annotationHolder = $("#annotation");
                    var $chatSection = $("#collab-chat-section");
                    $chatSection.addClass("annotated");
                    $annotationHolder.find(".text").text('\"' + response.annotation.selectionMeta.textContent + '\"');
                    $annotationHolder.attr("title", response.annotation.selectionMeta.textContent);
                    response.annotation.selectionMeta.s_id = App.CollaborationModel.currentUser.uid;
                    delete response.annotation.selectionMeta.highlighted;
                    $annotationHolder.attr('data-annotation', JSON.stringify(response.annotation.selectionMeta));
                }
            }
        },

        cancelTempAnnotationIfAny: function() {
            var temp_ann_e = $(".collab-temp-annotation.annotation");
            var msg_id;
            if(temp_ann_e.length) {
                msg_id = temp_ann_e.attr("data-message-id");
                _COLLAB_PVT.cancelAnnotation(msg_id);
            }
        },

        cancelAnnotation: function(msg_id) {
            // reset annotation
            if(msg_id) {
                $("[data-message-id='"+ msg_id +"']").toArray().forEach(function(elem) {
                    $(elem).replaceWith($(elem).html());
                });
            }

            // reset message-box
            var $annotationHolder = $("#annotation");
            $annotationHolder.attr("data-annotation", "");
            $annotationHolder.find(".text").empty();

            var $chatSection = $("#collab-chat-section");
            $chatSection.removeClass("annotated");

            if(msg_id) {
                $("#send-message-box").focus();
            }
        },

        resetAttachmentFormView: function() {
            $("#collab-chat-section").removeClass("collab-file-attached");
            _COLLAB_PVT.scrollToBottom();
            $("#collab-attachment-name").text("");
            $("#collab-attachment-image .image").remove();
            $("#collab-attachment-size").text("");
            $("#collab-send-attachment-button").attr("data-file", "");
            $("#collab-attachment-section").removeClass("sent");

            var text_msg_val = $("#send-message-box").val();
            $("form#send-collab-message-form")[0].reset();
            $("#send-message-box").val(text_msg_val);

            $("#send-message-box").focus();
        },

        hideAnnotationOption: function() {
            var $collabOptionsDD = $("#collab-option-dd");
            $collabOptionsDD.css({
                left: 0,
                top: 0,
                display: "none"
            });
        },

        unbindEvents: function(){
            window.clearInterval(window.getPresenceIval);
            $("input[type='file'][name='file']").off("change.collab");
            $("#collab-sidebar").off(".collab");
            $("#collab-sidebar").off(".enabledCollab");
            $("#collab-sidebar #scroll-box").off();
            $("#Pagearea").off(".collab");
            $("#collaborators-list-items").off(".collab");
            $("#sticky_header").off(".collab");
            $(document).off(".collab");
        },
        scrollToBottom: function() {
            var $scrollBox = $("#collab-sidebar #scroll-box");
            if($scrollBox) {
        	   $scrollBox[0].scrollTop = $scrollBox[0].scrollHeight;
            } else {
                console.log("Could not find the scrollbox; scrollToBottom called anyway.")
            }
        },
        fetchAndToggleCollab: function() {
            if(!Collab.isCollabOpen()) {
                Collab.loadConversation(_COLLAB_PVT.toggleCollabExpand);
            } else {
                _COLLAB_PVT.toggleCollabExpand();
            }
        },
        toggleCollabExpand: function(forceOpen) {
            var $collabSidebar = $("#collab-sidebar");
            var $msgBox = $("#collab-sidebar #send-message-box");

            if(forceOpen === true) {
                $collabSidebar.removeClass("expand");
            }

	        if($collabSidebar.hasClass("expand")) {
                $collabSidebar.removeClass("expand");
                $msgBox.blur();
	        } else {
                $collabSidebar.addClass("expand");

                setTimeout(function() {
                    _COLLAB_PVT.scrollToBottom();
                    if(!_COLLAB_PVT.collabDisabled()) {
    	                $msgBox.focus();
                    }
	            });
	        }
	    },

        uploadFile: function(files) {
            var collabModel = App.CollaborationModel;
            var currentConversation = collabModel.currentConversation;
            // get the selected file
            var formData = new FormData();
            $.each(files, function(key, value) {
                //var size = value.size/1024/1024 // Convert to MB, check for file size limit
                formData.append("file", value);
            });
            
            formData.append("co_id", currentConversation.co_id);
            if(!collabModel.conversationsMap[currentConversation.co_id]) {
                Collab.createConversation(currentConversation.co_id, [], proceedUpload);
            } else {
                proceedUpload();
            }

            function proceedUpload() {
                collabModel.uploadAttachment(formData, function(response){
                    switch(response.code) {
                        case 200: {
                            response = response.body;
                            $("#collab-chat-section").addClass("collab-file-attached");
                            _COLLAB_PVT.scrollToBottom();
                            $("#collab-attachment-input").replaceWith($("#collab-attachment-input").clone());
                            $("#collab-attachment-name").text(response.fn.substr(0, 12) + ".." + response.fn.substr(response.fn.lastIndexOf(".")));
                            $("#collab-attachment-name").attr("title", response.fn);
                            $("#collab-attachment-image").prepend("<img class='image' src='"+ response.pl +"'><span class='valign-helper'></span>");
                            $("#collab-attachment-size").text(response.fs);
                            $("#collab-send-attachment-button").attr("data-file", JSON.stringify(response));
                            break;
                        }
                        case 413: {
                            Collab.showError("size_exceeded", {max_size: CONST.MAX_UPLOAD_SIZE});
                            _COLLAB_PVT.resetAttachmentFormView();
                            break;
                        }
                        case 415: {
                            Collab.showError("wrong_file_format");
                            _COLLAB_PVT.resetAttachmentFormView();
                            break;
                        }
                    }
                });
            }
        },

        sendAttachmentMessage : function(msgBody) {
            if(!msgBody){
                return;
            }
            $("#collab-attachment-section").addClass("sent");
            var collabModel = App.CollaborationModel;
            var currentConvo = collabModel.currentConversation;

            msgBodyJSON = Collab.parseJson(msgBody);

            var attachment_link = {
                "dl" : msgBodyJSON.dl,
                "pl": msgBodyJSON.pl
            }

            var msg = {
                "m_type": CONST.MSG_TYPE_CLIENT_ATTACHMENT,
                "s_id": collabModel.currentUser.uid,
                "attachment_link": JSON.stringify(attachment_link)
            };
            
            function sendAndRender() {
                var $chatSection = $("#collab-chat-section");
                $chatSection.removeClass("empty-chat-view");
                Collab.addMessageHtml({
                    "body": msgBodyJSON,
                    "s_id": collabModel.currentUser.uid,
                    "metadata": msg.metadata,
                    "mid": msg.mid,
                    "m_type": CONST.MSG_TYPE_CLIENT_ATTACHMENT
                }, CONST.TYPE_SENT);

                delete msgBodyJSON.dl;
                delete msgBodyJSON.pl;
                msg.body = JSON.stringify(msgBodyJSON);

                collabModel.sendMessage(msg, currentConvo.co_id, function(){
                    _COLLAB_PVT.sendMessageSubmit();
                    _COLLAB_PVT.resetAttachmentFormView();
                });
                
                _COLLAB_PVT.scrollToBottom();
            }
            var convoObject = collabModel.conversationsMap[currentConvo.co_id];
            if(!convoObject) {
                Collab.createConversation(currentConvo.co_id, [collabModel.currentUser.uid], sendAndRender);
            } else {
                if(!!convoObject){
                    if(!convoObject.members[collabModel.currentUser.uid]){
                        collabModel.addMember(currentConvo.co_id, collabModel.currentUser.uid, sendAndRender);
                    }else{
                        sendAndRender();    
                    }
                }
            }
        },

	    sendMessageSubmit: function() {
            var $chatSection = $("#collab-sidebar #collab-chat-section");

            var $msgBox = $("#collab-sidebar #send-message-box");
            var collabModel = App.CollaborationModel;
            var currentConvo = collabModel.currentConversation;
            var currentConvoMembers = (!!collabModel.conversationsMap[currentConvo.co_id] ? collabModel.conversationsMap[currentConvo.co_id].members : {});
            var totalMembersInCurrentConvo = Object.keys(currentConvoMembers).length;
            var usersMap = collabModel.usersMap;
            var msgBody = $msgBox.val().trim();
            if(!msgBody) {
                return;
            }

            var msg = {
                "body": msgBody,
                "m_type": CONST.MSG_TYPE_CLIENT
            }
                
            var userMentionName;
            var usersToNotify = [];
            var usersMapToAdd = {};
            var userMentions = msgBody.match(CONST.MENTION_RE) || [];

            // Set metadata for @everyone
            if(userMentions.length === 1 && userMentions[0].trim() === CONST.MENTION_EVERYONE_TAG) {
                msg.metadata = msg.metadata || {};
                msg.metadata.notify_all = "1";
            } else {
            // Set metadata for tagged users
                if(!!userMentions && userMentions.length) {
                    for (var i = 0; i < userMentions.length && totalMembersInCurrentConvo < CONST.HELPKIT_MAX_COLLABORATORS; i++) {
                        for(var id in usersMap) {
                            userMentionName = (usersMap[id] && usersMap[id].email) ? 
                                usersMap[id].email.substring(0, usersMap[id].email.indexOf("@")).toLowerCase() :
                                "" ;
                            if(usersMap.hasOwnProperty(id) 
                                && id !== collabModel.currentUser.uid // not self
                                && usersMap[id].deleted !== "1" // not deleted agent
                                && userMentionName === userMentions[i].trim().substr(1).toLowerCase() // valid
                                && (!!currentConvoMembers[id] || totalMembersInCurrentConvo < CONST.HELPKIT_MAX_COLLABORATORS) // already a member || can be added as member
                                && usersToNotify.indexOf(id) === -1) { // not already in the list
                                    usersToNotify.push(id);

                                    if(!currentConvoMembers[id] && totalMembersInCurrentConvo < CONST.HELPKIT_MAX_COLLABORATORS) {
                                        usersMapToAdd[id] = {"id": id, "added_at": App.CollaborationModel.getCurrentUTCTimeStamp()};
                                        totalMembersInCurrentConvo++;
                                    }
                                    break;
                                }
                        }
                    }

                    if(usersToNotify.length) {
                        msg.metadata = msg.metadata || {};
                        msg.metadata.notify = usersToNotify;
                        // not updating instantly; update the list from type 2 messages
                        // Collab.updateCollaboratorsList(usersMapToAdd);
                    }
                }
            }

            $("form#send-collab-message-form")[0].reset();
            
            var $annotationHolder = $("#annotation");
            var annotationData = $annotationHolder.attr("data-annotation");
            // Set annotations metadata
            if(annotationData) {
                msg.metadata = msg.metadata || {};
                msg.metadata.annotations = Collab.parseJson(annotationData);
                msg.mid = Collab.parseJson(annotationData).messageId;
            }

            $annotationHolder.attr("data-annotation", "");
            $annotationHolder.find(".text").empty();
            
            var $chatSection = $("#collab-chat-section");
            $chatSection.removeClass("annotated");

            function sendAndRender() {
                $chatSection.removeClass("empty-chat-view");
                Collab.addMessageHtml({
                    "body": msg.body,
                    "s_id": collabModel.currentUser.uid,
                    "metadata": msg.metadata,
                    "mid": msg.mid,
                    "m_type": CONST.MSG_TYPE_CLIENT
                }, CONST.TYPE_SENT);
                // TODO (mayank): expect a response with notify | send_message | add_member data
                collabModel.sendMessage(msg, currentConvo.co_id);
                _COLLAB_PVT.scrollToBottom();
                $msgBox.focus();
                if(!!msg.metadata && !!msg.metadata.annotations) {
                    $("[data-message-id='"+ msg.metadata.annotations.messageId +"']").toArray().forEach(function(elem) {
                        $(elem).removeClass("collab-temp-annotation");
                    });
                }
            }
            var convoObject = collabModel.conversationsMap[currentConvo.co_id];
            
            if(!convoObject) {
                Collab.createConversation(currentConvo.co_id, [collabModel.currentUser.uid], function(response) {
                    if(!!response.conversation && !!response.conversation.members[collabModel.currentUser.uid]) {
                        sendAndRender();
                    } else {
                        collabModel.addMember(currentConvo.co_id, collabModel.currentUser.uid, sendAndRender);
                    }
                });
            } else {
                if(!!convoObject){
                    if(!convoObject.members[collabModel.currentUser.uid]){
                        collabModel.addMember(currentConvo.co_id, collabModel.currentUser.uid, sendAndRender);
                    }else{
                        sendAndRender();    
                    }
                }
            }
        },

	    getAvatarHtml: function(userId, class_list) {
	    	var usersMap = App.CollaborationModel.usersMap;
            var avatarHtml = JST[CONST.AVATAR_TEMPLATE]({data: {
                    name: usersMap[userId] ? usersMap[userId].name : CONST.DUMMY_USER.name,
                    id: userId,
                    class_list: class_list
                }});
	        return avatarHtml;
	    },

        getSelectionEndLoc: function(containerEl) {
            var range = window.getSelection().getRangeAt(0);
            var preSelectionRange = range.cloneRange();
            preSelectionRange.selectNodeContents(containerEl);
            preSelectionRange.setEnd(range.startContainer, range.startOffset);
            var start = preSelectionRange.toString().length
            var savedSel = {
                start: preSelectionRange.toString().length,
                end: start + range.toString().length
            }


            var charIndex = 0, range = document.createRange();
            range.setStart(containerEl, 0);
            range.collapse(true);
            var nodeStack = [containerEl], node, foundStart = false, stop = false;
            
            while (!stop && (node = nodeStack.pop())) {
                if (node.nodeType == 3) {
                    var nextCharIndex = charIndex + node.length;
                    if (!foundStart && savedSel.start >= charIndex && savedSel.start <= nextCharIndex) {
                        range.setStart(node, savedSel.start - charIndex);
                        foundStart = true;
                    }
                    if (foundStart && savedSel.end >= charIndex && savedSel.end <= nextCharIndex) {
                        range.setEnd(node, savedSel.end - charIndex);
                        stop = true;
                    }
                    charIndex = nextCharIndex;
                } else {
                    var i = node.childNodes.length;
                    while (i--) {
                        nodeStack.push(node.childNodes[i]);
                    }
                }
            }
            var rects=range.getClientRects();
            return rects[rects.length-1];
        },

        showAnnotationOption: function(containerEl) {
            _COLLAB_PVT.hideAnnotationOption();

            var annotatorId = App.CollaborationModel.currentUser.uid;
            var selectionInfo = App.CollaborationModel.getSelectionInfo(annotatorId);
            if(!selectionInfo.isAnnotableSelection) {
                return;
            }
            var selectionRectsForVp = _COLLAB_PVT.getSelectionEndLoc(containerEl);
            var $collabOptionsDD = $("#collab-option-dd");
            var dropDownWidth = $collabOptionsDD.width();
            if(!!selectionRectsForVp) {
                var leftcontentRects = $("#Pagearea .leftcontent")[0].getBoundingClientRect();
                var dropDownPos = {
                    left: selectionRectsForVp.right - leftcontentRects.left - (dropDownWidth/2),
                    top: selectionRectsForVp.top - leftcontentRects.top + selectionRectsForVp.height
                };
                $collabOptionsDD.css({
                    left: dropDownPos.left,
                    top: dropDownPos.top,
                    display: "block"
                });
            }
        },

        scrollToMessage: function(data_msg_id, retryCounter) {
            _COLLAB_PVT.hideDiscussionDD();
            _COLLAB_PVT.toggleCollabExpand(true);
            _COLLAB_PVT.showDiscussionView();
            var msg_e = $("#collab-" + data_msg_id);
            retryCounter = (retryCounter >= 0) ? retryCounter : CONST.DEFAULT_FETCH_RETRY;
            if(!!msg_e.length) {
                $("#scroll-box").animate({
                    scrollTop: msg_e[0].offsetTop - 30
                }, 500, function() {
                    msg_e.addClass("collab-ann-blink");
                    setTimeout(function(){msg_e.removeClass("collab-ann-blink");}, 5000); /* this time has to be in sync with animation timing; */
                });
                
            } else if(retryCounter > 0) {
                _COLLAB_PVT.fetchMoreMessages(function () {
                    _COLLAB_PVT.scrollToMessage(data_msg_id, --retryCounter);
                })
            }
        },
        scrollToAnnotationHighlight: function(annotation_e, event) {
            var self = this;
            var scrollHt, msg_id;
            if(typeof annotation_e === "string") {
                msg_id = annotation_e;
                annotation_e = $("#annotation-" + msg_id);
            }

            if(!!annotation_e.length) {
                msg_id = annotation_e.attr("id").replace("annotation-", "");
                scrollHt = annotation_e.offset().top - 200;
                $("html, body").animate({ scrollTop: scrollHt }, "slow", function() {
                    $("[data-message-id='"+ msg_id +"']").addClass("collab-highlight-blink");
                    setTimeout(function(){$("[data-message-id='"+ msg_id +"']").removeClass("collab-highlight-blink");}, 1000);
                });
            } else if(!self.hasExapndedTicket) {
                // annotation_e is not present and ticket expand has not been called
                // expand and scroll
                App.fetchMoreAndRender(event, function() {
                    self.hasExapndedTicket = true;
                    _COLLAB_PVT.scrollToAnnotationHighlight(msg_id || annotation_e);
                })
            } else {
                // annotation_e is not present but ticket has already expanded
                // notify user about failure
                Collab.invalidateAnnotationMessage(msg_id);
                console.log("could not find the highlighted section.");
            }
        },
        hasChatReachedTop : function(){
            var $chatBox = $("#collab-sidebar #scroll-box");
            if($chatBox) {
                var scrollTop = $chatBox.scrollTop();
                if (scrollTop < 150){
                    _COLLAB_PVT.savedScrollHeight = $chatBox[0].scrollHeight - $chatBox[0].scrollTop - $chatBox[0].clientHeight;
                    _COLLAB_PVT.fetchMoreMessages()
                }
            } else {
                console.log("Could not find the scrollbox; hasChatReachedTop called anyway.")
            }
        },
        fetchMoreMessages : function(cb){
            var collabModel = App.CollaborationModel;
            var currentConvo = collabModel.currentConversation;
            var cursor = currentConvo.messageStartCursor;
            if(!!cursor){
                var param = {
                    co_id:currentConvo.co_id,
                    start: cursor,
                    limit: CONST.FETCH_MESSAGE_LIMIT,
                };
                if(!_COLLAB_PVT.fetchingMessageBatch) {
                    _COLLAB_PVT.fetchingMessageBatch = true;
                    collabModel.fetchMoreMessages(param, function(response) {
                        _COLLAB_PVT.prependMessages(response);
                        if(typeof cb === "function") cb(response);
                    });
                }
            }
        },
        prependMessages : function(response){
            var $chatBox = $("#collab-sidebar #scroll-box");
            var collabModel = App.CollaborationModel;
            var currentConvo = collabModel.currentConversation;
            var messages = response.messages;
            for(var i = 0 ; i < messages.length ; i++){
                var receiptType = messages[i].s_id == collabModel.currentUser.uid ? CONST.TYPE_SENT : CONST.TYPE_RECEIVED;
                messages[i].forcePrepend = true;
                Collab.addMessageHtml(messages[i], receiptType);
            }
            currentConvo.messageStartCursor = response.start;
            $chatBox[0].scrollTop = $chatBox[0].scrollHeight - $chatBox[0].clientHeight - _COLLAB_PVT.savedScrollHeight;
            _COLLAB_PVT.savedScrollHeight = 0;
            _COLLAB_PVT.fetchingMessageBatch = false;
        },
        mentionUser: function(mentionText) {
            if(!_COLLAB_PVT.collabDisabled()) {
                if(!!mentionText) {
                    _COLLAB_PVT.showDiscussionView();
                    var $msgBox = $("#collab-sidebar #send-message-box");
                    $msgBox.focus();
                    $msgBox.val($msgBox.val() + mentionText + " ");
                }
            }
        },
        showHoverCard: function(event) {
            setTimeout(function() {
                var elementMouseIsOver = document.elementFromPoint(event.clientX, event.clientY);
                if($(elementMouseIsOver).hasClass("avatar-cover") || $(elementMouseIsOver).parents(".avatar-cover").length) {
                    var avatarPos = event.currentTarget.getBoundingClientRect();
                    var avatarHeightBuffer = 18;
                    var topPos = avatarPos.top - avatarHeightBuffer;

                    var hovercardUserId = $(event.currentTarget).attr("data-sender-id");
                    var collabModel = App.CollaborationModel;

                    if(collabModel.usersMap[hovercardUserId]) {
                        $("#hovercard").empty();
                        $("#collab-hovercard-cover").attr("style", "");
                        $("#collab-hovercard-cover").attr("data-mention-text", "@" + App.CollaborationModel.usersMap[hovercardUserId].email.split("@")[0]);
                        $("#hovercard").append($(JST[CONST.COLLABORATORS_LIST_ITEM_TEMPLATE]({data: _COLLAB_PVT.generateCollaboratorListData(hovercardUserId, "hovercard")})));
                        $("#collab-hovercard-cover").attr("style", "display:block;top:"+ topPos +"px;");
                    } else {
                        console.log("User data not available. id:", hovercardUserId);
                    }
                }
            }, 0);
        },
        hideHoverCard: function (event, forceHide) {
            setTimeout(function() {
                var elementMouseIsOver = !!event ? document.elementFromPoint(event.clientX, event.clientY) : "";
                if(!(!forceHide && ($(elementMouseIsOver).hasClass("collab-hovercard-cover") || $(elementMouseIsOver).parents(".collab-hovercard-cover").length))) {
                    $("#hovercard").empty();
                    $("#collab-hovercard-cover").attr("style", "");
                    $("#collab-hovercard-cover").attr("data-mention-text", "");
                }
            }, 0);
        },
        conversationCreateOrLoadCb: function(response) {
            Collab.fetchCount++;
            var collabModel = App.CollaborationModel;
            var curConvo = collabModel.currentConversation;
            var firstLoad = (Collab.fetchCount === 1);

            if(!!response.start){
                collabModel.currentConversation.messageStartCursor = response.start;
            }
            var conversationData = response.conversation;

            /*
            *   Annotation
            */
            if(!!conversationData.metadata) {
                _COLLAB_PVT.resetAnnotationsForTicket();
                _COLLAB_PVT.cancelAnnotation();
                collabModel.annotationsMap = {};
                conversationData.metadata.annotations.forEach(function(annotation) {
                    annotation = (typeof annotation === "string") ? Collab.parseJson(annotation) : annotation;
                    var k = annotation["type"] + annotation["id"];
                    collabModel.annotationsMap[k] = collabModel.annotationsMap[k] || [];
                    collabModel.annotationsMap[k].push({
                        "annotation": annotation,
                        "highlighted": false
                    });
                });

                var ann_map=App.CollaborationModel.annotationsMap;
                for(var key in ann_map) {
                    ann_map[key].sort(function(ann1, ann2) {
                        return ann1.annotation.messageId - ann2.annotation.messageId;
                    });
                }
                collabModel.restoreAnnotations();
            }

            /*
            *   Collab message view and collaborator list view
            */ 
            if(!!conversationData) {
                collabModel.conversationsMap[conversationData.co_id] = conversationData;
                messageList = conversationData.msgs || [];
                var receiptType;
                $('#scroll-box').empty();
                for(var i= 0; i < messageList.length ; i++) {
                    var msg = messageList[i];
                    receiptType = msg.s_id == collabModel.currentUser.uid ? CONST.TYPE_SENT : CONST.TYPE_RECEIVED;
                    msg.forcePrepend = true
                    Collab.addMessageHtml(msg, receiptType);
                }

                membersMap = conversationData.members || {};

                Collab.updateCollaboratorsList(membersMap);

                // change it from winow object to something else
                collabModel.collaboratorsGetPresence();
                window.getPresenceIval = setInterval(function() {
                    collabModel.collaboratorsGetPresence();
                }, collabModel.MEMBER_PRESENCE_POLL_TIME);
                
                // mismatch owner
                if(firstLoad && curConvo.owned_by !== conversationData.owned_by) {
                    App.CollaborationModel.setConvoOwner(curConvo.co_id, curConvo.owned_by);
                }
            }

            /*
            *   Collab expand or not
            */ 
            if(!!Collab.expandCollabOnLoad) {
                _COLLAB_PVT.toggleCollabExpand(true);
                Collab.expandCollabOnLoad = false;
                _COLLAB_PVT.scrollToMessage(Collab.scrollToMsgId);
            }
            
            _COLLAB_PVT.disableCollabUiIfNeeded();

            if(firstLoad) {
                _COLLAB_PVT.checkAndUpdateCoversationStatus(conversationData);
            }
        },

        isTicketClosedOnFirstLoad: function() {
            return App.CollaborationModel.currentConversation.is_closed;
        },

        checkAndUpdateCoversationStatus: function(conversationData) {
            var collabModel = App.CollaborationModel;
            var hk_ticket_close_status = _COLLAB_PVT.isTicketClosedOnFirstLoad();
            var iAmCollaborator = _COLLAB_PVT.isCollaborator(collabModel.currentUser.uid);
            if(iAmCollaborator && (hk_ticket_close_status !== !!conversationData.is_closed)) {
                collabModel.updateTicketCloseStatus(hk_ticket_close_status);
            }
        },

        isCollaborator: function(uid) {
            var convoObj = App.CollaborationModel.conversationsMap[App.CollaborationModel.currentConversation.co_id];
            return !!convoObj ? !!convoObj.members[uid] : false;
        },

        isTicketClosed: function(tid) {
            var is_closed;
            var convoObj = App.CollaborationModel.conversationsMap[tid];
            var convo_closed_in_collab = !!convoObj ? convoObj.is_closed : false;

            is_closed = (Collab.fetchCount === 1) ? _COLLAB_PVT.isTicketClosedOnFirstLoad() : convo_closed_in_collab;
            return is_closed;
        },

        isCollaboratorMaxOut: function(co_id) {
            var convoObj = App.CollaborationModel.conversationsMap[co_id];
            return !!convoObj ? (Object.keys(convoObj.members).length >= CONST.HELPKIT_MAX_COLLABORATORS) : false;
        },

        collabDisabled: function() {
            var collabModel = App.CollaborationModel;
            var currentConversation = collabModel.currentConversation;
            
            var ticketClosed = _COLLAB_PVT.isTicketClosed(currentConversation.co_id);
            var collaboratorMaxOut = _COLLAB_PVT.isCollaboratorMaxOut(currentConversation.co_id);
            var iAmCollaborator = _COLLAB_PVT.isCollaborator(collabModel.currentUser.uid);
            
            return ticketClosed ||
                (collaboratorMaxOut && !iAmCollaborator) ||
                Collab.networkDisconnected;
        },

        disableCollabUiIfNeeded: function() {
            var collabModel = App.CollaborationModel;
            var currentConversation = collabModel.currentConversation;
            var $collabSidebar = $("#collab-sidebar");
            
            if($collabSidebar.length) {
                if(_COLLAB_PVT.collabDisabled()) {
                    console.log("Collaboration disabled!");

                    $collabSidebar.addClass("closed-conversation");

                    $collabSidebar.off(".enabledCollab");

                    var $sendMessageBox = $("#send-message-box");
                    $sendMessageBox.addClass("disabled-box");
                    $sendMessageBox.attr("readonly", "");
                    var placeholderContent = $sendMessageBox.attr("placeholder");
                    if(placeholderContent) {
                        $sendMessageBox.attr("data-placeholder-bak", placeholderContent);
                        $sendMessageBox.attr("placeholder", "");
                    }

                    var $msgBox = $("#collab-sidebar #send-message-box");
                    setTimeout(function() {
                        $msgBox.blur();
                    })

                    var $pagearea = $("#Pagearea");
                    $pagearea.off("mouseup.collab");

                    var $hovercard = $("#collab-hovercard-cover");
                    $hovercard.off('click');
                } else if($collabSidebar.hasClass("closed-conversation")) {
                    console.log("Re-enabling Collaboration that was disabled!");

                    $collabSidebar.removeClass("closed-conversation");

                    var $sendMessageBox = $("#send-message-box");
                    $sendMessageBox.removeClass("disabled-box");
                    $sendMessageBox.removeAttr("readonly");
                    $sendMessageBox.attr("placeholder", $sendMessageBox.attr("data-placeholder-bak"));

                    _COLLAB_PVT.unbindEvents();
                    _COLLAB_PVT.events();
                }
            }
        },

        resetAnnotationsForTicket: function() {
            $(".annotation[data-message-id]").toArray().forEach(function(ann) {
                ann.replace($(ann).html());
            });
            if($(".annotation[data-message-id]").length) {
                _COLLAB_PVT.resetAnnotationsForTicket();
            }
        },

        setCollaboratorsCount: function () {
            var collabModel = App.CollaborationModel;
            var convo = collabModel.conversationsMap[collabModel.currentConversation.co_id];
            var collaborators_count = !!convo ? Object.keys(convo.members).length : 0;
            $("#collaborators-count").text(collaborators_count);
            if(collaborators_count) {
                $("#collaborators-tab-btn").removeClass("disabled");
            }
        },

        showDiscussionDD: function(event) {
            if(!$(event.currentTarget).hasClass("collab-temp-annotation")) {
                var selectionRectsForVp = event.currentTarget.getBoundingClientRect();
                var lineHeightBuffer = selectionRectsForVp.bottom - selectionRectsForVp.top;
                var $showDiscussionDD = $("#show-discussion-dd");
                var dropDownWidth = $showDiscussionDD.width();
                if(!!selectionRectsForVp) {
                    var leftcontentRects = $("#Pagearea .leftcontent")[0].getBoundingClientRect();
                    var dropDownPos = {
                        left: selectionRectsForVp.left - leftcontentRects.left + selectionRectsForVp.width/2 - dropDownWidth/2,
                        top: selectionRectsForVp.top - leftcontentRects.top + lineHeightBuffer
                    };
                    $showDiscussionDD.attr('data-message-id', event.currentTarget.getAttribute('data-message-id'));

                    var $annotatorImage = $("#annotator-image");
                    $annotatorImage.html(_COLLAB_PVT.getAvatarHtml(event.currentTarget.getAttribute('data-annotator-id'), "small"));

                    $showDiscussionDD.css({
                        left: dropDownPos.left,
                        top: dropDownPos.top,
                        display: "block"
                    });
                }
            }
        },

        isMouseOverTarget: function(X, Y, targetClass, targetId) {
            var e = document.elementFromPoint(X, Y);
            return $(e).hasClass(targetClass) || $(e).parents("." + targetClass).length || (!!targetId ? $(e).attr("id") == targetId : "");
        },

        hideDiscussionDD: function(event) {
            // if event doesn't trigger this; force hide it.
            if(!!event) {
                setTimeout(function() {
                    if(!_COLLAB_PVT.isMouseOverTarget(event.clientX, event.clientY, "show-discussion-dd", "annotation-" + $("#show-discussion-dd").attr('data-message-id'))) {
                        $("#show-discussion-dd").attr('data-message-id', "");
                        $("#show-discussion-dd").css({
                            left: 0,
                            top: 0,
                            display: "none"
                        });
                    }
                });
            } else {
                $("#show-discussion-dd").css({
                    left: 0,
                    top: 0,
                    display: "none"
                });
            }
        },

        generateCollaboratorListData: function(userId, context) {
            var collabModel = App.CollaborationModel;
            var modelUserData = collabModel.usersMap[userId] || CONST.DUMMY_USER;
            var selfUserName = String(collabModel.currentUser.uid);
            var isSelf = String(userId) === selfUserName;

            return {
                name: modelUserData ? (isSelf ? "Me (" + modelUserData.name + ")" : modelUserData.name) : "",
                email: modelUserData && modelUserData.email ? modelUserData.email : "",
                username: modelUserData && modelUserData.email ? modelUserData.email.substring(0, modelUserData.email.indexOf("@")) : "",
                job_title: modelUserData ? modelUserData.title : "",
                id: userId,
                is_online: collabModel.isOnline(userId),
                is_self: isSelf,
                id_post_fix: context,
                is_deleted: modelUserData ? (modelUserData.deleted === "1") : false
            }
        },
        updateNotiCount: function() {
            if(!!App.CollaborationModel.unreadNotiCount) {
                $("#noti-count").removeClass("hide");
            } else {
                $("#noti-count").addClass("hide");
            }
        },
        refreshAttachmentUri: function(elem, fid, retry_count) {
            retry_count++;
            // retry max-out
            if(retry_count >= CONST.DEFAULT_FETCH_RETRY) {
                $(elem).attr("src", CONST.DEF_PIC_URL);
                $(elem).attr("data-fetch-retry-count", CONST.DEFAULT_FETCH_RETRY);

                var sec = $(elem).parents(".collab-attached-image-section");
                sec.addClass("collab-download-disabled");
                sec.removeAttr("href");
                sec.removeAttr("download");
            } else {
                App.CollaborationModel.refreshAttachmentUri(fid, function(response) {
                    $(elem).parents(".collab-attached-image-section").attr("href", response.dl);
                    $(elem).attr("src", response.pl);
                    $(elem).attr("data-fetch-retry-count", retry_count);
                });
            }
        },
        getMentionName: function(user_id) {
            var mention_name;
            var user_data = App.CollaborationModel.usersMap[user_id];
            if(user_data && user_data.email) {
                mention_name = user_data.email.split("@")[0];
            }
            return mention_name;
        },

        generateNotificationListData: function (noti_body_wrapper) {
            var usersMap = App.CollaborationModel.usersMap;
            var mentioned_by_id = noti_body_wrapper.body.mentioned_by;
            var mentioned_by_name = usersMap[mentioned_by_id] ? usersMap[mentioned_by_id].name : "";

            /*
                5 kinds of notifications:>
                - invitation 1. "%{user_name} wants to collaborate with you on ticket %{ticket_id}"
                - invitation 2. "You were added as collaborator on ticket %{ticket_id}"
                - Mention
                    - 3. Fist mention "%{who} has mentioned you in 1 message in ticket %{ticket_id}"
                    - Nth mention
                        - 4. Nth mention multi_msg "%{who} has mentioned you in %{how_many} messages in ticket %{ticket_id}"
                        - 5. Nth mention multi_msg_multi_user "%{who_all} have mentioned you in %{how_many} messages in ticket %{ticket_id}"
            */

            var noti_text, noti_html, existing_row, 
                is_unread, convo_user_ids, data_mentionedby_names, 
                data_noti_ids_arr, message_id;

            var is_invitation = !!noti_body_wrapper.body.invite;
            var cid = noti_body_wrapper.body.co_id;
            var all_mentioned_by = mentioned_by_name;
            var convo_user_ids = mentioned_by_id;
            var mentioned_msgs = 0;
            var data_noti_ids = noti_body_wrapper.nid;

            message_id = noti_body_wrapper.body.mid;

            if(is_invitation) {
                if(!!mentioned_by_id) {
                // Invitation:> "x wants to collab... with you on ticket #XYZ";
                    noti_text = I18n.translate("collaboration.invited_notification", 
                        {user_name: mentioned_by_name, ticket_id: cid});
                    noti_html = I18n.translate("collaboration.invited_notification", 
                        {user_name: "<b class='collab-noti-uname'>" + mentioned_by_name + "</b>", ticket_id: "<b>#" + cid + "</b>"});
                    mentioned_msgs++;
                } else {
                // Invitation:> "You were added in collab... on ticket #XYZ";
                    noti_text = I18n.translate("collaboration.added_to", {ticket_id: cid});
                    noti_html = I18n.translate("collaboration.added_to", {ticket_id: "<b>#" + cid + "</b>"});
                    mentioned_msgs++;
                }
            } else {
            // Mention:>
                is_read = noti_body_wrapper.is_read;
                existing_row = $(".collab-notification-list-item.noti-" + (is_read ? "read" : "unread") + ":not(.noti-invite) a[data-convo-cid='" + cid + "']");
                if(!existing_row.length) {
                // First mention:> "X has mentioned you in 1 message in ticket #XYZ";
                    noti_text = I18n.translate("collaboration.first_mention", 
                        {who: mentioned_by_name, ticket_id: cid});
                    noti_html = I18n.translate("collaboration.first_mention", 
                        {who: "<b class='collab-noti-uname'>" + mentioned_by_name + "</b>", ticket_id: "<b>#" + cid + "</b>"});
                    mentioned_msgs++;
                } else {
                // Nth mention:>
                    var to_be_grouped = true;
                    data_noti_ids_arr = existing_row.attr("data-noti-ids").split(",");
                    data_noti_ids_arr.push(noti_body_wrapper.nid);
                    data_noti_ids = data_noti_ids_arr.join(",");
                    message_id = existing_row.attr("data-msg-id");

                    convo_user_ids = existing_row.attr("data-user-ids").split(",");
                    mentioned_msgs = Number(existing_row.attr("data-mentioned-msgs-count")) + 1;
                    if((convo_user_ids.length === 1) && (convo_user_ids[0] === mentioned_by_id)) {
                    // multi_msg;
                        noti_text = I18n.translate("collaboration.nth_mention", 
                            {who: mentioned_by_name, how_many: (mentioned_msgs), ticket_id: cid});
                        noti_html = I18n.translate("collaboration.nth_mention", 
                            {who: "<b class='collab-noti-uname'>" + mentioned_by_name + "</b>", how_many: "<b>" + (mentioned_msgs) + "</b>", ticket_id: "<b>#" + cid + "</b>"});
                    } else {
                    // multi_msg_multi_user;
                        data_mentionedby_names = existing_row.attr("data-mentionedby-names");
                        if(convo_user_ids.indexOf(mentioned_by_id) === -1){
                            convo_user_ids.push(mentioned_by_id);
                            all_mentioned_by = mentioned_by_name + (data_mentionedby_names.length ? ", " + data_mentionedby_names : "");
                        } else {
                            all_mentioned_by = data_mentionedby_names;
                        }
                        
                        noti_text = I18n.translate("collaboration.nth_mention_multi_users", 
                            {who_all: all_mentioned_by, how_many: (mentioned_msgs), ticket_id: cid});
                        noti_html = I18n.translate("collaboration.nth_mention_multi_users", 
                            {who_all: "<b class='collab-noti-uname'>" + all_mentioned_by + "</b>", how_many: "<b>" + (mentioned_msgs) + "</b>", ticket_id: "<b>#" + cid + "</b>"});
                    }
                }
            }

            noti_body_wrapper.invite = is_invitation;
            noti_body_wrapper.notiText = noti_text;
            noti_body_wrapper.notiHtml = noti_html;
            noti_body_wrapper.notificationIds = data_noti_ids;
            noti_body_wrapper.userIds = convo_user_ids;
            noti_body_wrapper.toBeGrouped = to_be_grouped;
            noti_body_wrapper.existingRow = existing_row;
            noti_body_wrapper.mentionedMsgsCount = mentioned_msgs;
            noti_body_wrapper.mentionedByNames = all_mentioned_by;
            noti_body_wrapper.mid = message_id;

            return noti_body_wrapper;
        },

        showScrollBar: function(el) {
            if(el.scrollTop === 0) {
                el.scrollTop += 1;
                el.scrollTop -= 1;
            } else {
                el.scrollTop -= 1;
                el.scrollTop += 1;
            }
        },

        getUserInfo: function(uid, cb) {
            App.CollaborationModel.getUserInfo(uid, cb);
        },

        updateDpCharToImage: function(elem, image_path) {
            elem.removeClassName("hide");
            elem.setAttribute("src", image_path);
            App.CollaborationModel.profileImages[elem.getAttribute("data-user-id")] = {"path": image_path};
        }
    };

    var Collab = {
        annotationEvents: [{
            eventName: "mouseenter",
            eventHandler: _COLLAB_PVT.showDiscussionDD
        }, {
            eventName: "mouseleave",
            eventHandler: _COLLAB_PVT.hideDiscussionDD
        }],
        hasExapndedTicket: false,

        unbindEvents: function() {
            _COLLAB_PVT.unbindEvents();
        },

        collabImgError: function(event) {
            $(event.target).trigger('collabAttachmentImageError', event);
        },

        isCollabOpen: function() {
            return $("#collab-sidebar").hasClass("expand");
        },

        updateCollaboratorsList: function(membersMap) {
            var membersList = [];
            for(var id in membersMap) {
                if(membersMap.hasOwnProperty(id)) {
                    membersMap[id]["id"] = id;
                    membersList.push(membersMap[id]);
                }
            }

            membersList = membersList.sort(function (a, b) {
                if (a.added_at < b.added_at) { 
                    return -1;
                } else if (a.added_at > b.added_at) {
                    return 1
                } else { // nothing to split them
                    return 0;
                }
            });

            var collabModel = App.CollaborationModel;
            var currentConversation = collabModel.conversationsMap[collabModel.currentConversation.co_id];
            var collab_list_context = "collab-list";

            for (var i=0; i<membersList.length; i++) {
                var id = membersList[i]["id"];
                var new_html_e = $(JST[CONST.COLLABORATORS_LIST_ITEM_TEMPLATE]({data: _COLLAB_PVT.generateCollaboratorListData(id, collab_list_context)}));
                if($("#collaborator-icon-" + id + "-" + collab_list_context).length) {
                    $("#collaborator-icon-" + id + "-" + collab_list_context).replaceWith(new_html_e);
                } else {
                    $("#collaborators-list-items").append(new_html_e);
                }

                // TODO (mayank): See if existing data can be updated using Object.extend()
                if(!!currentConversation && !currentConversation.members[id]) {
                    currentConversation.members[id] = {
                        "id": id,
                        "added_at": App.CollaborationModel.getCurrentUTCTimeStamp()
                    }
                }
            }

            _COLLAB_PVT.setCollaboratorsCount();
        },

        showError: function(error_i18n_kind, params) {
            error_i18n_kind = error_i18n_kind || CONST.DEFAULT_ERR;
            $("#collab-error-text").text(I18n.translate("collaboration.error." + error_i18n_kind, params));
            $("#collab-chat-section").addClass("collab-error-shown");
            setTimeout(function() {
                $("#collab-chat-section").removeClass("collab-error-shown");
            }, CONST.HIDE_ERROR_DURATION);
        },

        removeCollaboratorsFromList: function(id){
            var collabModel = App.CollaborationModel;
            var currentConversation = collabModel.conversationsMap[collabModel.currentConversation.co_id];
            var collab_list_context = "collab-list";

            if(!!currentConversation && !!currentConversation.members[id]){
                if($("#collaborator-icon-" + id + "-" + collab_list_context).length) {
                        $("#collaborator-icon-" + id + "-" + collab_list_context).remove();
                }
                delete currentConversation.members[id];
            }
            
            _COLLAB_PVT.setCollaboratorsCount();
        },

        askInitUi: function(config) {
            // init UI if model is inited; or else save config
            // on connection init if config is pending; initUi will be called onModelInited
            config = config || Collab.parseJson($("#collab-ui-data").attr("data-ui-payload"));
            config.expandCollabOnLoad = !!Collab.getUrlParameter("collab");
            config.scrollToMsgId = Collab.getUrlParameter("msg");

            if(!!App.CollaborationModel.initedWithData) {
                Collab.initUi(config);
            } else {
                Collab.pendingConfig = config;
            }

            $.each(["show-discussion-dd", "collab-option-dd", "collab-sidebar"], function(idx, elem_id) {
                $("#" + elem_id).removeClass("hide");
            })
        },

	    initUi: function(config) {
	    	var collabModel = App.CollaborationModel;
            // TODO (mayank): don't set this if convo isn't present
	        collabModel.currentConversation = {
	            "name": config.currentConversationName,
	            "co_id": config.currentConversationId,
                "owned_by": config.ownedBy,
                "is_closed": config.isClosed,
                "token": config.convoToken
	        }

            /*
            *   TODO (mayank):  don't proceed with UI elements 
            *       if conversation is not loaded
            */ 
            Collab.fetchCount = 0;
            Collab.loadConversation(function() {
                if(!Collab.initingPostReconnect) {
                    Collab.enableMentions();
                }
                Collab.initingPostReconnect = false;
            });
            Collab.expandCollabOnLoad = config.expandCollabOnLoad;
            Collab.scrollToMsgId = config.scrollToMsgId;

            _COLLAB_PVT.unbindEvents();
	        _COLLAB_PVT.events();
            console.log("Started collaboration.");
	    },

        loadConversation: function(cb) {
            var collabModel = App.CollaborationModel;
            collabModel.loadConversation(function(response) {
                if(!!response) {
                    $("#collab-chat-section").removeClass("empty-chat-view");
                    _COLLAB_PVT.conversationCreateOrLoadCb(response)
                } else {
                    Collab.fetchCount++;
                    _COLLAB_PVT.setCollaboratorsCount();
                    $("#collab-chat-section").addClass("empty-chat-view");
                    if(Collab.fetchCount === 1) {
                        _COLLAB_PVT.disableCollabUiIfNeeded();
                    }
                }
                if(typeof cb === "function") cb(response);
            });
        },

	    createConversation: function(cn, members, cb) {
	    	var collabModel = App.CollaborationModel;
	    	var currentConversation = collabModel.currentConversation;
            cn = cn || currentConversation.co_id;
            collabModel.currentConversation.name = cn;
            members = members || [];

            var conversationObj = {
                "co_id": cn,
                "members": members,
                "owned_by": currentConversation["owned_by"]
            }

            collabModel.createConversation(conversationObj, function(response) {
                _COLLAB_PVT.conversationCreateOrLoadCb(response);
                cb(response);
            });
        },

        showDiscussBtn: function() {
            $("#collab-btn").removeClass("hide");
        },

        hideDiscussBtn: function(response) {
            $("#collab-btn").addClass("hide");
        },

        addNotificationHtml: function(notiBodyWrapper) {
            $("#collab-notification-dd").find("li.info").hide();
            notiBodyWrapper.body = Collab.parseJson(notiBodyWrapper.body);
            notiBodyWrapper = _COLLAB_PVT.generateNotificationListData(notiBodyWrapper);

            var notificationListItem = $(JST[CONST.NOTIFICATION_LIST_ITEM_TEMPLATE]({
                notification: notiBodyWrapper
            }));

            if(!!notiBodyWrapper.toBeGrouped) {
                notiBodyWrapper.existingRow.parent(".collab-notification-list-item").replaceWith(notificationListItem);
            } else {
                $("#collab-notification-list").prepend(notificationListItem);
            }
            _COLLAB_PVT.updateNotiCount();
        },

        addMessageHtml: function(msg, render_type) {
	        if(!msg.body) {
                return;
            }

            var msg_meta, annotation_meta, is_annotation_invalid;
            if(!!msg.metadata) {
                msg_meta = Collab.parseJson(msg.metadata);
                annotation_meta = msg_meta.annotations ? Collab.parseJson(msg_meta.annotations) : null;

                if(App.CollaborationModel.invalidAnnotationMessages.indexOf(msg.mid) >= 0) {
                    is_annotation_invalid = true;
                }
            }



            if(msg.incremental && !!annotation_meta) {
                annotation_meta.messageId = msg.mid;
                App.CollaborationModel.restoreAnnotations(annotation_meta);
            }

            
            var collabModel = App.CollaborationModel;
            var userId = !!msg.s_id ? msg.s_id : (render_type === CONST.TYPE_SENT ? collabModel.currentUser.uid : "");
            var add_method = msg.forcePrepend ? "prepend" : "append";
            var sender_name = collabModel.usersMap[msg.s_id] ? collabModel.usersMap[msg.s_id].name : CONST.DUMMY_USER.name;

            function renderMsg(msg_body, msg_type) {
                $("#collab-sidebar #scroll-box")[add_method](JST[CONST.COLLABORATION_MESSAGE_TEMPLATE]({
                    avatar_html: !!userId ? _COLLAB_PVT.getAvatarHtml(userId) : "",
                    sender_id: userId,
                    sender_name: collabModel.currentUser.name !== sender_name ? sender_name : "",
                    msg_body: msg_body,
                    /*
                    *   TODO (mayank): Need to take care of time zone here
                    */
                    time_stamp_text: collabModel.formatTimestamp(Math.floor((new Date().getTime() - App.CollaborationModel.parseUTCDateToLocal(msg.created_at).getTime()) / 1000)),
                    msg_id: msg.mid,
                    msg_render_type: render_type,

                    // TODO (mayank): add more safechecks
                    annotation_body: annotation_meta ? annotation_meta.textContent : "",
                    is_attachment: msg_type ? !!msg_type.attachment : false,
                    is_annotation_invalid: !!is_annotation_invalid,
                    invalid_annotation_text: I18n.translate("collaboration.error.highlight_missing")
                }));
            }

            // HTMLescape > Smilify > LinkifyUnames > LinkifyAllLinks >
            if(msg.m_type === CONST.MSG_TYPE_CLIENT) {
                var msg_body, emoji_class_attr, msg_text_content, msg_with_emojis, img_tags;
                if(typeof smilify !== "undefined") {
                    msg_with_emojis = smilify(msg.body);
                    img_tags = msg_with_emojis.match(CONST.IMAGE_TAG_RE) || [];
                    msg_text_content = $("<span>" + msg_with_emojis + "</span>").text().trim();
                    emoji_class_attr = (!!msg_text_content || (img_tags.length > CONST.MAX_JUMBOMOJI_COUNT)) ? "class='emoji'" : "class='jumbo emoji'";
                    msg_body = smilify(msg.body, emoji_class_attr, CONST.EMOJIS_URL);

                    var um = App.CollaborationModel.usersMap;
                    var uarr = [];
                    for(var uid in um) {
                        if(um.hasOwnProperty(uid) && !!um[uid].email && um[uid].deleted !== "1") {
                            uarr.push(um[uid].email.split("@")[0]);
                        }
                    }
                    msg_body = Collab.strongifyUserNames(msg_body, uarr);
                } else {
                     msg_body = msg.body;
                }
                msg.created_at = msg.created_at || App.CollaborationModel.getCurrentUTCTimeStamp();
                renderMsg(msg_body);
            } else if(msg.m_type === CONST.MSG_TYPE_CLIENT_ATTACHMENT) {
                var msg_body = Collab.parseJson(msg.body);
                msg.created_at = msg.created_at || App.CollaborationModel.getCurrentUTCTimeStamp();
                renderMsg(msg_body, {"attachment": true});
            }
            
            _COLLAB_PVT.scrollToBottom();
	    },

        strongifyUserNames: function(text, uarr) {
            var self_name = App.CollaborationModel.currentUser.email.split("@")[0];
            var self_class;
            return text.replace(CONST.MENTION_RE,
            function (matched, username, offset, source_string) {
                self_class = (username === self_name ? "collab-my-mention-name" : "");
                return uarr.indexOf(username) >= 0 ? ("<b class='collab-mention-name "+ self_class +"'>"+ matched +"</b>") : matched;
            });
        },


        // TODO (mayank): must be called on every ticket_detail load
        // should be called only once per ticket;
        enableMentions: function() {
            var usersToMention = [];
            var collabModel = App.CollaborationModel;
            var is_colab_max_out = _COLLAB_PVT.isCollaboratorMaxOut(collabModel.currentConversation.co_id);
            var mention_list_context = "mention-item";

            if(is_colab_max_out) {
                var members = collabModel.conversationsMap[collabModel.currentConversation.co_id].members;
                for (var mid in members) {
                    if(members.hasOwnProperty(mid) && mid !== collabModel.currentUser.uid) {
                        usersToMention.push(_COLLAB_PVT.generateCollaboratorListData(mid, mention_list_context));
                    }
                }
            } else {
                for(var userId in collabModel.usersMap) {
                    var user = collabModel.usersMap[userId];
                    if(userId !== collabModel.currentUser.uid && (user.deleted !== "1")) {
                        usersToMention.push(_COLLAB_PVT.generateCollaboratorListData(userId, mention_list_context));
                    }
                }
            }

            usersToMention.push({
                mention_text: "everyone",
                job_title: "All collaborators on this tickets",
                id_post_fix: "mention-list"
            });
            menu_prefix = "<label class='info'>"+ I18n.translate("collaboration.collab_max_out_info", {max_collaborators: "<b>" + CONST.HELPKIT_MAX_COLLABORATORS + "</b>", contact_person: "<b>" + "your Admin" + "</b>"}) +"</label>";
            menu_item = '<div id="collab-mention-picker" class="collab-mention-picker ' + (is_colab_max_out ? "max-out" : "") + '"> ' + menu_prefix + ' <ul></ul></div>';

            var options = {
                "data": usersToMention, 
                "editor": "#collab-sidebar #send-message-box",
                "menuHtml": menu_item,
                "maxItems": 5,
                "filterKeys": ["name", "username", "mention_text"],
                "tagAttribute": "username"
            };
            var lm = new lightMention(options);
            lm.bindMention();
        },

        parseJson: function (data) {
            if(typeof data === "string") {
                return JSON.parse(data)
            } else {
                return data;
            }
        },

        getUrlParameter: function getUrlParameter(sParam) {
            var sPageURL = decodeURIComponent(window.location.search.substring(1)),
                sURLVariables = sPageURL.split('&'),
                sParameterName,
                i;

            for (i = 0; i < sURLVariables.length; i++) {
                sParameterName = sURLVariables[i].split('=');

                if (sParameterName[0] === sParam) {
                    return sParameterName[1] === undefined ? true : sParameterName[1];
                }
            }
        },
        invalidateAnnotationMessage: function(msg_id) {
            // invalidates on the fly.
            var ann_msg = $("#collab-" + msg_id);
            var ann_msg_text = ann_msg.find(".annotation-text");

            if(ann_msg_text.length) {
                ann_msg_text.addClass("invalid-annotation");
            }

            var ann_msg_info = ann_msg.find(".collab-msg-info");
            if(ann_msg_info.length) {
                ann_msg_info.addClass("invalid-ann-info-show");
            }
        },
        onDisconnectHandler: function(response) {
            Collab.networkDisconnected = true;
            _COLLAB_PVT.disableCollabUiIfNeeded();
            Collab.showError("network_err");
        },
        onReconnecthandler: function(response) {
            Collab.networkDisconnected = false;
            var config = $("#collab-ui-data").attr("data-ui-payload");
            if(config) {
                Collab.initingPostReconnect = true;
                App.CollaborationUi.initUi(Collab.parseJson(config));
            }
            _COLLAB_PVT.disableCollabUiIfNeeded();
        },
        activateBellListeners: function() {
            _COLLAB_PVT.bellEvents();
        },
        dpLoadErr: function(elem) {
            var uid = elem.getAttribute("data-user-id");

            function pullProfileImage() {
                // FETCH CASE
                App.CollaborationModel.profileImages[uid] = {"fetching": true};
                $.get("/users/" + uid + "/profile_image_path", function(response) {
                    if(!!response.path){
                        _COLLAB_PVT.updateDpCharToImage(elem, response.path);
                    }
                    App.CollaborationModel.profileImages[uid].fetching = false;
                });
            }

            if(uid) {
                var profile_image_obj = App.CollaborationModel.profileImages[uid];
                if(profile_image_obj) {
                    // FETCHING CASE
                    if(profile_image_obj.fetching) {
                        setTimeout(function() {
                            Collab.dpLoadErr(elem);
                        }, CONST.RETRY_DELAY_FOR_PENDING_DP_REQ);
                    } else if(profile_image_obj.path) {
                        // CACHEC CASE
                        _COLLAB_PVT.updateDpCharToImage(elem, profile_image_obj.path);
                    } else {
                        pullProfileImage();
                    }
                } else {
                    pullProfileImage();
                }
            } else {
                console.log("Something went wrong in setting DP image; uid not found in -data- attr;");
            }
        }
    };
    return Collab;
})(window.jQuery);
