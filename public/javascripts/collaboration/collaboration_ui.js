/*
*	For collaboration feature.
*	DOM related functions fall here.
*	Expects $ to be loaded before it.
*   To be included in cdn/collaboration.js
*/

window.App = window.App || {};
App.CollaborationUi = (function ($) {

    var CONST = {
        MENTION_RE: /\B@([\S]+)(?!=[\s])/igm,
        EXTERNAL_URL_RE: /\b(?:(?:(?:(https?:\/\/)|(?:www\d{0,3}\.))[\-a-z0-9+&@#\/%?=~_|!:\.;]+)|(?:([0-9a-z._+\-]+@)?(?:[0-9a-z]+[.\-])+(?:(?:co(?:m|\.[a-z]{2}))|ir|us|cc|biz|mobi|info|uk|org|net|tv|eu|cn|au)(?:[#\/?:][\-a-z0-9+&@#\/%?=~_|!:\.;]*[\-a-z0-9+&@#\/%=~_|]*|\b)))/gim,
        IMAGE_TAG_RE: /<img/igm,
        FILE_EXT_RE: /\.[\w]+$/igm,
        MENTION_EVERYONE_TAG: "@huddle",
        TYPE_SENT: 'sent',
		TYPE_RECEIVED: 'received',
        MSG_TYPE_CLIENT: "1", // Msg from Client
        MSG_TYPE_SERVER_MADD: "2", // Msg from Server, denotes addition of member
        MSG_TYPE_SERVER_MREMOVE: "3", // Msg from Server, denotes removal of member
        MSG_TYPE_CLIENT_ATTACHMENT: "4",
        MSG_TYPE_TYPING: "typing", // not known to server
        MSG_TYPE_READ_RECEIPT: "read_receipt", // not known to server

        DEFAULT_PRESENCE_IVAL: 60 * 1000 * 1, // 1 minute
        RETRY_DELAY_FOR_PENDING_DP_REQ: 1000 * 5, // 5sec
        AVATAR_TEMPLATE: "collaboration/templates/avatar",
        COLLABORATORS_LIST_ITEM_TEMPLATE: "collaboration/templates/collaborators_list_item",
        COLLABORATION_MESSAGE_TEMPLATE: "collaboration/templates/collaboration_message",
        COLLABORATION_TYPING_MESSAGE_TEMPLATE: "collaboration/templates/collaboration_typing_message",
        NOTIFICATION_LIST_ITEM_TEMPLATE: "collaboration/templates/notification_list_item",
        FETCH_MESSAGE_LIMIT: 50,
        DEFAULT_FETCH_RETRY: 5,
        MAX_JUMBOMOJI_COUNT: 3,
        DEF_PIC_URL: "/assets/misc/profile_blank_thumb.jpg",
        EMOJIS_URL: "/images/emojis/",
        HELPKIT_MAX_COLLABORATORS: 20,
        HIDE_ANIMATION_DURATION: 1000, //ms
        DUMMY_USER: {name: "---"},
        HIDE_FLASH_DURATION: 3000, //ms
        MAX_UPLOAD_SIZE: "15MB",
        PREVIEW_SUPPORTED_FILE_TYPES: ["png", "jpg", "jpeg"],
        MAX_TYPINGMSG_SENDING_STATUS_AGE: '2000',
        MAX_TYPING_STATUS_AGE: '2000'
    };

    var _COLLAB_PVT = {
        savedScrollHeight:0,
        bellEvents: function() {
            jQuery(document).on("collabNoti", function(event){
                App.CollaborationModel.markNotiReadForCollabOpen(event.detail);
            });
        },
        events: function(){
            var $collabBtn = $("#sticky_header");
            var $collabSidebar = $("#collab-sidebar");
            var $pagearea = $("#Pagearea");
            var $scrollBox = $("#collab-sidebar #scroll-box");

            $collabSidebar.on("click.collab", "#collab-close-icon", _COLLAB_PVT.closeCollabSidebar);
            $collabSidebar.on("click.collab", "#collaborators-tab-btn", _COLLAB_PVT.showCollaboratorsListView);
            $collabSidebar.on("click.collab", "#discussion-tab-btn", _COLLAB_PVT.showDiscussionView);
            $collabSidebar.on("mouseover.collab", ".avatar-cover", _COLLAB_PVT.showHoverCard);
            $collabSidebar.on("mouseleave.collab", ".avatar-cover", _COLLAB_PVT.hideHoverCard);
            $collabBtn.on("click.collab", "#collab-btn", function() {
                if (App.CollaborationModel.getSelectionInfo().isAnnotableSelection) {
                    _COLLAB_PVT.askToMarkAnnotation();
                } else {
                    Collab.loadConversation(_COLLAB_PVT.openCollabSidebar);
                }
            });
            $pagearea.on("click.collab", ".pseudo_reply #DiscussButton", function() {
                Collab.loadConversation(_COLLAB_PVT.openCollabSidebar);
            });
            $collabSidebar.on("change.collab", ".collab-follow-btn input", function(event) {
              _COLLAB_PVT.followConvo(event.target.checked);
            });
            $collabSidebar.on("click.enabledCollab", ".collab-highlightmode-icon", function() {
              _COLLAB_PVT.setHighlightMode(!$(event.target).closest('.collab-highlightmode-btn').hasClass('collab-active'));
            });
            $collabSidebar.on("click.collab", ".collab-reply-btn", function(event){
                var annotation_in_progress = $("#annotation").attr("data-annotation");
                if(!annotation_in_progress) {
                    var parent_msg_box = $(event.currentTarget).closest('.collab-message-box');
                    var msg = $(parent_msg_box).find(".msg");
                    var msg_body = $(msg).hasClass("collab-attachment-msg") ?
                                   String($(parent_msg_box).find(".collab-attachment-details").attr("title")).trim() :
                                   String($(msg).attr("data-raw-msg")).trim();
                    var msg_id = String($(parent_msg_box).attr("id")).replace("collab-", "").trim();
                    var sender_id = String($(parent_msg_box).children("div").attr("data-sender-id")).trim();
                    var reply_data = {"msg_id" : msg_id, "r_id" : sender_id, "msg_body" : msg_body};
                    _COLLAB_PVT.setCollabReplyToAttr(reply_data);
                }
            });
            $collabSidebar.on("mouseleave.collab", "#collab-hovercard-cover", _COLLAB_PVT.hideHoverCard);
            $scrollBox.on("scroll.collab", _COLLAB_PVT.displayScrollDownBtn);
            $collabSidebar.on("click.collab", "#collab-scroll-bottom-btn", _COLLAB_PVT.smoothScrollToBottom);
            $collabSidebar.on("collabAttachmentImageError.collab", ".collab-attachment-msg .image", function(event) {
                var fid = event.target.getAttribute("data-fid");
                var retry_count = event.target.getAttribute("data-fetch-retry-count");
                if(retry_count === "") {
                    retry_count = 0;
                }
                _COLLAB_PVT.refreshImageAttachmentUri(event.target, fid, retry_count);
            });
            $collabSidebar.on("click.collab", ".collab-attachment-msg .image,.collab-attachment-details", function(event) {
                var elem = $(event.target).parents(".collab-attached-image-section");
                var fn = $(elem).find(".collab-attachment-details")[0].getAttribute("title");
                var dl = $(elem).find(".collab-attachment-downloader")[0].getAttribute("href");
                _COLLAB_PVT.showAttachmentPreview(fn, dl);
            });
            $pagearea.on("mouseup.collab", ".leftcontent .conversation:not(.activity)", function(event) {
                var containerEl = event.currentTarget;
                setTimeout(function () {
                    _COLLAB_PVT.showAnnotationOption(containerEl);
                });
            });
            $pagearea.on("mouseleave.collab", "#show-discussion-dd", _COLLAB_PVT.hideDiscussionDD);
            $pagearea.on("click.collab", "#collab-option-dd", function(){
                _COLLAB_PVT.askToMarkAnnotation();
            });
            $scrollBox.on("scroll.collab", _COLLAB_PVT.hasChatReachedTop); // scroll doesn't bubble

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
            $collabSidebar.on("click.enabledCollab", "#cancel-reply", _COLLAB_PVT.cancelReply);
            $collabSidebar.on("click.enabledCollab", "#collab-attachment-cancel-icon", function(event) {
                _COLLAB_PVT.resetAttachmentFormView();
            });
            $collabSidebar.on("click.collab", "#collaborators-list-items .tag-handle, #collab-chat-section .tag-handle", function(event) {
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
                var key = event.which || event.keyCode;
                if(key === 13 && !event.shiftKey) {
                    event.preventDefault();
                    _COLLAB_PVT.sendMessageSubmit();
                } else if(key === 27 && !event.shiftKey) {
                    event.preventDefault();
                    _COLLAB_PVT.closeCollabSidebar();
                }
            });
            $collabSidebar.on("keypress.enabledCollab", "#send-message-box", function(event) {
                var key = event.which || event.keyCode;
                if(!Collab.shouldBlockTypingMsgSend && key !== 13) {
                    Collab.shouldBlockTypingMsgSend = true;
                    _COLLAB_PVT.sendTypingMessage();
                    setTimeout(function() {
                        Collab.shouldBlockTypingMsgSend = false;
                    }, CONST.MAX_TYPINGMSG_SENDING_STATUS_AGE);
                }
            });
            $collabSidebar.on("click.collab", ".collab-reply-to-text", function(event) {
                var data_reply_to_id = event.currentTarget.getAttribute('data-reply-to-id');
                var animation_class = "collab-reply-blink";
                _COLLAB_PVT.scrollToMessage(data_reply_to_id, CONST.DEFAULT_FETCH_RETRY, animation_class);
            });
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
                if(!$(event.target).hasClass("annotation")) {
                    $("#show-discussion-dd").removeClass('stick-discussion-dd');
                    _COLLAB_PVT.hideDiscussionDD();
                }
            });
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

        askToMarkAnnotation: function() {
            var reply_in_progress = $("#collab-msg-reply-to").attr("data-reply");
            if (_COLLAB_PVT.collabDisabled()) {
                if (!Collab.isCollabOpen()) {
                    _COLLAB_PVT.openCollabSidebar();
                }
            } else if (!reply_in_progress) {
                _COLLAB_PVT.markAnnotation();
            }
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
                    if(response.annotation.tempAnnotation) {
                        var ann = jQuery("[data-message-id=" + response.annotation.selectionMeta.messageId+"]");
                        ann.addClass("collab-temp-annotation");
                    }
                    prepareDataMarkAnnotation();
                    _COLLAB_PVT.openCollabSidebar();
                });
            } else {
                prepareDataMarkAnnotation();
                _COLLAB_PVT.openCollabSidebar();
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
            App.CollaborationModel.resetSelectionInfo();
        },

        setCollabSelectableStyle: function(state) {
          if(state && Collab.highlightMode) {
            $('.conversation #ticket_original_request, .conversation [id^="note_details_"]').addClass('collab-selectable');
          } else {
            $('.conversation #ticket_original_request, .conversation [id^="note_details_"]').removeClass('collab-selectable');
          }
        },

        setHighlightMode: function(state) {
          if(state) {
            Collab.highlightMode = true;
            $('#collab-sidebar .collab-highlightmode-btn').addClass('collab-active').attr('data-original-title', I18n.translate("collaboration.highlight_mode_on"));
            if(Collab.isCollabOpen()) {
              _COLLAB_PVT.setCollabSelectableStyle(true);
            }
          } else {
            Collab.highlightMode = false;
            $('#collab-sidebar .collab-highlightmode-btn').removeClass('collab-active').attr('data-original-title', I18n.translate("collaboration.highlight_mode_off"));
            if(Collab.isCollabOpen()) {
              _COLLAB_PVT.setCollabSelectableStyle(false);
            }
          }
        },

        cancelReply: function() {
            // reset message-box
            var $replyHolder = $("#collab-msg-reply-to");
            $replyHolder.attr("data-reply", "");
            $replyHolder.find(".text").empty();

            var $chatSection = $("#collab-chat-section");
            $chatSection.removeClass("reply-added");
        },

        followConvo: function(follow) {
          var collabModel = App.CollaborationModel;
          collabModel.followConvo(follow);

          if(follow) {
            Collab.showFlash('info.follow_flash', {duration: 6000, addl_class: 'collab-flash-3-lines'});
          } else {
            Collab.showFlash('info.unfollow_flash', {duration: 6000, addl_class: 'collab-flash-4-lines'});
          }
        },

        resetAttachmentFormView: function() {
            $("#collab-chat-section").removeClass("collab-file-attached");
            _COLLAB_PVT.scrollToBottom();
            $("#collab-attachment-name").text("");
            $("#collab-attachment-image .image").remove();
            $("#collab-attachment-size").text("");
            $(".collab-attached-image-section").attr("data-file", "");
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

        displayScrollDownBtn: function() {
            var $scrollBox = $("#collab-sidebar #scroll-box");
            if($scrollBox.length) {
                if ($scrollBox[0].scrollTop < ($scrollBox[0].scrollHeight - ($scrollBox[0].clientHeight)*1.5)){
                    $("#collab-scroll-bottom-btn").css('display', 'block');
                } else {
                    $("#collab-scroll-bottom-btn").css('display', 'none');
                }
            } else {
                console.log("Could not find the scrollbox; displayScrollDownBtn called anyway.")
            }
        },

        smoothScrollToBottom: function() {
            var $scrollBox = $("#collab-sidebar #scroll-box");
            $scrollBox.animate({
                scrollTop: $scrollBox[0].scrollHeight
                }, 400);
        },

        scrollToBottom: function() {
            var $scrollBox = $("#collab-sidebar #scroll-box");
            if($scrollBox) {
        	   $scrollBox[0].scrollTop = $scrollBox[0].scrollHeight;
            } else {
                console.log("Could not find the scrollbox; scrollToBottom called anyway.")
            }
        },
        openCollabSidebar: function() {
            var $collabSidebar = $("#collab-sidebar");
            var $msgBox = $("#collab-sidebar #send-message-box");

            $collabSidebar.removeClass("expand navFromRightBounceIn");

            $collabSidebar.addClass("expand navFromRightBounceIn");

            setTimeout(function() {
                _COLLAB_PVT.scrollToBottom();
                if(!_COLLAB_PVT.collabDisabled()) {
                    $msgBox.focus();
                }
            });
            var collabModel = App.CollaborationModel;
            var convo = collabModel.conversationsMap[collabModel.currentConversation.co_id];
            if(!!convo && collabModel.features.markReadEnabled) {
                var messageList = convo.msgs || [];
                var read_marker = convo.read_marker || {};
                var my_id = collabModel.currentUser.uid;

                if ( messageList.length !== 0 ) {
                    var lastClientMessageId = _COLLAB_PVT.getLastClientMessageId(messageList);
                    if( !read_marker[my_id] || ( parseInt(read_marker[my_id]) < parseInt(lastClientMessageId) ) ) {
                        collabModel.updateReadMarker(lastClientMessageId);
                    }
                }
                _COLLAB_PVT.hideUnreadMessageIndicator();
            }

            _COLLAB_PVT.setCollabSelectableStyle(true);
        },

        closeCollabSidebar: function() {
            var $collabSidebar = $("#collab-sidebar");
            var $msgBox = $("#collab-sidebar #send-message-box");

            $collabSidebar.removeClass("expand navFromRightBounceIn");
            $msgBox.blur();
            _COLLAB_PVT.setCollabSelectableStyle(false);
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
                            $("#collab-attachment-name").text(Collab.getFileDisplayName(escape(response.fn)));
                            $("#collab-attachment-name").attr("title", escape(response.fn));
                            if (typeof(response.pl) !== "undefined") {
                                $("#collab-attachment-image").prepend("<img class='image' src='"+ response.pl +"'><span class='valign-helper'></span>");
                            } else {
                                $("#collab-attachment-image").prepend("<i class='ficon-file fsize-36' size='14'></i><span class='valign-helper'></span>");
                            }
                            $("#collab-attachment-size").text(response.fs);
                            $(".collab-attached-image-section").attr("data-file", JSON.stringify(response));
                            break;
                        }
                        case 413: {
                            Collab.showFlash("error.size_exceeded", {max_size: CONST.MAX_UPLOAD_SIZE});
                            _COLLAB_PVT.resetAttachmentFormView();
                            break;
                        }
                        case 415: {
                            Collab.showFlash("error.wrong_file_format");
                            _COLLAB_PVT.resetAttachmentFormView();
                            break;
                        }
                    }
                    $("#send-message-box").focus();
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
                "pl" : msgBodyJSON.pl
            }

            var msg = {
                "m_type": CONST.MSG_TYPE_CLIENT_ATTACHMENT,
                "s_id": collabModel.currentUser.uid,
                "attachment_link": JSON.stringify(attachment_link)
            };

            function sendAndRender() {
                var $chatSection = $("#collab-chat-section");
                $chatSection.removeClass("empty-chat-view");
                if(!msg.mid) {
                    msg.ts = msg.ts || Date.now().toString();
                }

                Collab.addMessageHtml({
                    "body": msgBodyJSON,
                    "s_id": collabModel.currentUser.uid,
                    "metadata": msg.metadata,
                    "mid": msg.mid,
                    "ts": msg.ts,
                    "m_type": CONST.MSG_TYPE_CLIENT_ATTACHMENT,
                    "incremental": true
                }, CONST.TYPE_SENT);

                delete msgBodyJSON.dl;
                delete msgBodyJSON.pl;
                _COLLAB_PVT.resetAttachmentFormView();

                msg.body = JSON.stringify(msgBodyJSON);

                collabModel.sendMessage(msg, currentConvo.co_id);

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

        sendTypingMessage: function() {
            var collabModel = App.CollaborationModel;
            var currentConvo = collabModel.currentConversation;
            var convoObject = collabModel.conversationsMap[currentConvo.co_id];
            if (!convoObject) {
                // Conversation doesn't exists or there is no message in msgBody
                return
            }

            var msg = {
                "body": JSON.stringify({
                    "t_id": collabModel.currentUser.uid
                }),
                "m_type": CONST.MSG_TYPE_TYPING,
                "ts": Date.now().toString(),
                "persist": false
            }
            collabModel.sendMessage(msg, currentConvo.co_id);
        },

	    sendMessageSubmit: function() {
            var $chatSection = $("#collab-sidebar #collab-chat-section");

            var $msgBox = $("#collab-sidebar #send-message-box");
            var collabModel = App.CollaborationModel;
            var currentConvo = collabModel.currentConversation;
            var currentConvoMembers = (!!collabModel.conversationsMap[currentConvo.co_id] ? collabModel.conversationsMap[currentConvo.co_id].members : {});
            var totalMembersInCurrentConvo = Object.keys(currentConvoMembers).length;
            var usersMap = collabModel.usersMap;
            var usersTagMap = collabModel.usersTagMap;
            var msgBody = $msgBox.val().trim();

            var attachmentData = $(".collab-attached-image-section").attr("data-file");

            if(!!attachmentData) {
                _COLLAB_PVT.sendAttachmentMessage(attachmentData);
            }

            if(!msgBody) {
                return;
            }

            var msg = {
                "body": msgBody,
                "m_type": CONST.MSG_TYPE_CLIENT
            }

            var userMentionName;
            var usersToNotify = [];
            var groupsToNotify = [];
            var usersMapToAdd = {};
            var userMentions = msgBody.match(CONST.MENTION_RE) || [];

            var $replyHolder = $("#collab-msg-reply-to");
            var replyData = $replyHolder.attr("data-reply");

            // set reply metadata
            if(replyData) {
                msg.metadata = msg.metadata || {};
                msg.metadata.reply = Collab.parseJson(replyData);
                msg.metadata.reply.no_notif = true;
            }

            $("form#send-collab-message-form")[0].reset();

            var $annotationHolder = $("#annotation");
            var annotationData = $annotationHolder.attr("data-annotation");

            // Set annotations metadata
            if(annotationData) {
                msg.metadata = msg.metadata || {};
                msg.metadata.annotations = Collab.parseJson(annotationData);
                msg.ts = Collab.parseJson(annotationData).messageId;
            }

            $annotationHolder.attr("data-annotation", "");
            $annotationHolder.find(".text").empty();
            $chatSection.removeClass("annotated");
            collabModel.resetSelectionInfo();

            $replyHolder.attr("data-reply", "");
            $replyHolder.find(".text").empty();
            $chatSection.removeClass("reply-added");

            // Set metadata for tagged users
            if(userMentions.length) {
                var group_ids = [];
                userMentions.forEach( function (grp) {
                    var group_name = grp.replace("@" , "");
                    if(collabModel.groupsTagMap.hasOwnProperty(group_name)) {
                        group_ids.push(collabModel.groupsTagMap[group_name]);
                    }
                });
                if(group_ids.length) {
                    msg.metadata = msg.metadata || {};
                    msg.metadata.hk_group_notify = group_ids;
                }

                if(userMentions.indexOf(CONST.MENTION_EVERYONE_TAG) !== -1) {
                    usersToNotify = Object.keys(currentConvoMembers);
                    var current_user_idx = usersToNotify.indexOf(collabModel.currentUser.uid);
                    if(current_user_idx >= 0) {
                        usersToNotify.splice(usersToNotify.indexOf(collabModel.currentUser.uid), 1);
                    }
                }

                for (var i = 0; i < userMentions.length && totalMembersInCurrentConvo < CONST.HELPKIT_MAX_COLLABORATORS; i++) {

                    userMentionName = userMentions[i].trim().substr(1).toLowerCase();
                    var id = usersTagMap.hasOwnProperty(userMentionName) ? usersTagMap[userMentionName].uid : "";
                    if(id !== ""
                    && id !== collabModel.currentUser.uid // not self
                    && usersTagMap[userMentionName].deleted !== "1" // not deleted agent
                    && (!!currentConvoMembers[id] || totalMembersInCurrentConvo < CONST.HELPKIT_MAX_COLLABORATORS) // already a member || can be added as member
                    && usersToNotify.indexOf(id) === -1) { // not already in the list
                        usersToNotify.push(id);

                        if(!currentConvoMembers[id] && totalMembersInCurrentConvo < CONST.HELPKIT_MAX_COLLABORATORS) {
                            usersMapToAdd[id] = {"id": id, "added_at": collabModel.getCurrentUTCTimeStamp()};
                            totalMembersInCurrentConvo++;
                        }
                    }
                }

                if(usersToNotify.length) {
                    msg.metadata = msg.metadata || {};

                    userInfos = [];
                    usersToNotify.forEach( function(userId) {
                        userInfos.push({
                            user_id: userId,
                            invite: currentConvoMembers ? !currentConvoMembers[userId] : true
                        });
                    });
                    msg.metadata.hk_notify = userInfos;
                }
            }

            function sendAndRender() {
                $chatSection.removeClass("empty-chat-view");
                if(!msg.mid) {
                    msg.ts = msg.ts || Date.now().toString();
                }
                Collab.addMessageHtml({
                    "body": msg.body,
                    "s_id": collabModel.currentUser.uid,
                    "metadata": msg.metadata,
                    "mid": msg.mid,
                    "m_type": CONST.MSG_TYPE_CLIENT,
                    "ts": msg.ts,
                    "incremental": true
                }, CONST.TYPE_SENT);

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
                    class_list: class_list,
                    deleted: usersMap[userId].deleted
                }});
	        return avatarHtml;
	    },

        getSelectionVpLoc: function(containerEl) {
            var range = window.getSelection().getRangeAt(0);
            var rects=range.getClientRects();
            var extremeBoundary = {left: Infinity, right:0};

            for(var i=0;i<rects.length;i++) {
                if(extremeBoundary.left > rects[i].left) {
                    extremeBoundary.left = rects[i].left;  // minimum left
                }
                if(extremeBoundary.right < rects[i].right) {
                    extremeBoundary.right = rects[i].right;  // maximum right
                }
            }

            // First rect has top most range's numbers
            extremeBoundary.top = rects[0].top;
            extremeBoundary.center = (extremeBoundary.right - extremeBoundary.left)/2;
            return extremeBoundary;
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

            var s_id = App.CollaborationModel.currentUser.uid;
            var selectionInfo = App.CollaborationModel.setSelectionInfo(s_id);
            if (!selectionInfo.isAnnotableSelection || !Collab.highlightMode || !Collab.isCollabOpen()) {
                return;
            }
            var selectionRectsForVp = _COLLAB_PVT.getSelectionVpLoc(containerEl);
            var $collabOptionsDD = $("#collab-option-dd");
            var dropDownWidth = $collabOptionsDD.width();
            if(!!selectionRectsForVp) {
                var leftcontentRects = $("#Pagearea .leftcontent")[0].getBoundingClientRect();
                var dropDownPos = {
                    left: selectionRectsForVp.right - leftcontentRects.left - selectionRectsForVp.center - (dropDownWidth/2),
                    top: selectionRectsForVp.top - leftcontentRects.top - 41 // collabOptionsDD.height=41(approx)
                };
                $collabOptionsDD.css({
                    left: dropDownPos.left,
                    top: dropDownPos.top,
                    display: "block"
                });
            }
        },

        scrollToMessage: function(data_msg_id, retryCounter, animation_class) {
            animation_class = animation_class || "collab-ann-blink";
            _COLLAB_PVT.hideDiscussionDD();
            _COLLAB_PVT.openCollabSidebar();
            _COLLAB_PVT.showDiscussionView();
            var msg_e = $("#collab-" + data_msg_id);
            retryCounter = (retryCounter >= 0) ? retryCounter : CONST.DEFAULT_FETCH_RETRY;
            if(!!msg_e.length) {
                // TODO (kshitij) : find a way to optimize the scroll to msg animation
                $("#scroll-box").animate({
                    scrollTop: msg_e[0].offsetTop - 60
                }, 500, function() {
                    msg_e.addClass(animation_class);
                    setTimeout(function(){msg_e.removeClass(animation_class);}, 5000); /* this time has to be in sync with animation timing; */
                });

            } else if(retryCounter > 0) {
                _COLLAB_PVT.fetchMoreMessages(function () {
                    _COLLAB_PVT.scrollToMessage(data_msg_id, --retryCounter, animation_class);
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
                // TODO(:mayank) add safecheck here
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
                var scrollingUp = Collab.scrollBoxScrollTop ? Collab.scrollBoxScrollTop > scrollTop : false;
                if (scrollingUp && scrollTop < 150){
                    _COLLAB_PVT.savedScrollHeight = $chatBox[0].scrollHeight - $chatBox[0].scrollTop - $chatBox[0].clientHeight;
                    _COLLAB_PVT.fetchMoreMessages();

                }
                Collab.scrollBoxScrollTop = scrollTop;
            } else {
                console.log("Could not find the scrollbox; But hasChatReachedTop was called.")
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
                        // TODO(:mayank) verify that scroll postion is not messed up because of this.
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

                    if (collabModel.usersMap[hovercardUserId] && collabModel.usersMap[hovercardUserId].deleted !== '1') {
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
        // event function to fetch attribute data for reply
        setCollabReplyToAttr: function(reply_data) {
            var $replyHolder = $("#collab-msg-reply-to");
            var $chatSection = $("#collab-chat-section");
            $chatSection.addClass("reply-added");
            $replyHolder.find(".text").text('\"' + reply_data.msg_body + '\"');
            $replyHolder.attr("title", reply_data.msg_body);
            $replyHolder.attr('data-reply', JSON.stringify(reply_data));

            $("#send-message-box").focus();
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
            var messageList = conversationData.msgs || [];

            if(messageList.length !== 0 && collabModel.features.markReadEnabled) {
                var my_id = collabModel.currentUser.uid;
                var read_marker = response.conversation.read_marker || {};
                var lastClientMessageId = _COLLAB_PVT.getLastClientMessageId(messageList);
                if( read_marker[my_id] && ( parseInt(read_marker[my_id]) < parseInt(lastClientMessageId) ) ) {
                    _COLLAB_PVT.showUnreadMessageIndicator();
                } else {
                    _COLLAB_PVT.hideUnreadMessageIndicator();
                }
            }
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
                window.clearInterval(window.getPresenceIval);
                window.getPresenceIval = setInterval(function() {
                    collabModel.collaboratorsGetPresence();
                }, collabModel.MEMBER_PRESENCE_POLL_TIME);

                // mismatch owner
                if(firstLoad && curConvo.owned_by !== conversationData.owned_by) {
                    App.CollaborationModel.setConvoOwner(curConvo.co_id, curConvo.owned_by);
                }
            }

            var followersList = collabModel.conversationsMap[collabModel.currentConversation.co_id].followers;
            var iAmFollower = followersList && followersList[collabModel.currentUser.uid];

            if(iAmFollower) {
              jQuery('#collab-sidebar').find('input').prop('checked', true);
            }

            /*
            *   Collab expand or not
            */
            if(!!Collab.expandCollabOnLoad) {
                _COLLAB_PVT.openCollabSidebar();
                Collab.expandCollabOnLoad = false;
                if(typeof Collab.scrollToMsgId !== "undefined") {
                    _COLLAB_PVT.scrollToMessage(Collab.scrollToMsgId);
                }

                if (Collab.followAction === "false" && iAmFollower) {
                    _COLLAB_PVT.followConvo(false);
                    Collab.updateFollowConvoUi(false);
                }
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
            var accSuspended = currentConversation.acc_suspend;

            return ticketClosed ||
                accSuspended ||
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

                    var $hovercard = $("#collab-hovercard-cover");
                    $hovercard.off('click');

                    if(_COLLAB_PVT.isCollaboratorMaxOut(currentConversation.co_id)) {
                        $collabSidebar.find(".collab-disabled-reason").text(I18n.translate("collaboration.disable_collab_info.huddle_max_out", {max_collaborators: CONST.HELPKIT_MAX_COLLABORATORS}));
                    } else {
                        $collabSidebar.find(".collab-disabled-reason").text(I18n.translate("collaboration.disable_collab_info.huddle_closed"));
                    }
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
            var collabUsers = collabModel.usersMap;
            var convo = collabModel.conversationsMap[collabModel.currentConversation.co_id];
            var collaborators_count = 0;
            if (!!convo && convo.members) {
                convoMembers = convo.members;
                for (var id in convoMembers) {
                    if (convoMembers.hasOwnProperty(id) && collabUsers[id].deleted !== '1') {
                        collaborators_count++;
                    }
                }
            }
            $("#collaborators-count").text(collaborators_count);
            if(collaborators_count) {
                $("#collaborators-tab-btn").removeClass("disabled");
            }
        },

        showDiscussionDD: function(event) {
            var $showDiscussionDD = $("#show-discussion-dd");
            if(!(event.type === "mouseenter" && $showDiscussionDD.hasClass('stick-discussion-dd'))) {
                if(!$(event.currentTarget).hasClass("collab-temp-annotation")) {

                    var message_id = event.currentTarget.getAttribute('data-message-id');
                    var dropDownWidth = $showDiscussionDD.width();
                    var leftcontentRects = $("#Pagearea .leftcontent")[0].getBoundingClientRect();

                    var annotations = jQuery(".annotation[data-message-id="+ message_id +"]");
                    var extremeBoundary = {left: Infinity, right: 0, top: Infinity};

                    annotations.each(function(idx, ann) {
                        var rect = ann.getBoundingClientRect();
                        if (extremeBoundary.left > rect.left) {
                            extremeBoundary.left = rect.left;  // minimum left
                        }
                        if (extremeBoundary.right < rect.right) {
                            extremeBoundary.right = rect.right;  // maximum right
                        }
                        if (extremeBoundary.top > rect.top) {
                            extremeBoundary.top = rect.top; // minimum top
                        }
                    });
                    extremeBoundary.center = (extremeBoundary.right - extremeBoundary.left)/2;

                    var dropDownPos = {
                        left: extremeBoundary.right - leftcontentRects.left - extremeBoundary.center - dropDownWidth/2,
                        top: extremeBoundary.top - leftcontentRects.top - 40 // dropDownHeight=40(approx)
                    };
                    $showDiscussionDD.attr('data-message-id', message_id);

                    var $annotatorImage = $("#annotator-image");
                    $annotatorImage.html(_COLLAB_PVT.getAvatarHtml(event.currentTarget.getAttribute('data-annotator-id'), "small x-small"));

                    $showDiscussionDD.css({
                        left: dropDownPos.left,
                        top: dropDownPos.top,
                        display: "block"
                    });
                    if(event.type === "click") {
                        $showDiscussionDD.addClass('stick-discussion-dd');
                    }
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
                var $showDiscussionDD = $("#show-discussion-dd");
                if(!$showDiscussionDD.hasClass('stick-discussion-dd')) {
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
                }
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
                username: modelUserData && modelUserData.tag ? modelUserData.tag : "",
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
        refreshImageAttachmentUri: function(elem, fid, retry_count) {
            retry_count++;
            // retry max-out
            if(retry_count >= CONST.DEFAULT_FETCH_RETRY) {
                $(elem).attr("src", CONST.DEF_PIC_URL);
                $(elem).attr("data-fetch-retry-count", CONST.DEFAULT_FETCH_RETRY);

                var sec = $(elem).parents(".collab-attached-image-section");
                sec.addClass("collab-download-disabled");
                var download_anchor = $(sec).find(".collab-attachment-downloader");
                download_anchor.removeAttr("href");
                download_anchor.removeAttr("download");
            } else {
                App.CollaborationModel.refreshAttachmentUri(fid, function(response) {
                    $(elem).parents(".collab-attached-image-section").find(".collab-attachment-downloader").attr("href", response.dl);
                    $(elem).attr("src", response.pl);
                    $(elem).attr("data-fetch-retry-count", retry_count);
                });
            }
        },
        refreshAttachmentUri: function(fid) {
                App.CollaborationModel.refreshAttachmentUri(fid, function(response) {
                    var elem = jQuery("[data-fid='" + fid + "']");
                    $(elem).parents(".collab-attached-image-section").find(".collab-attachment-downloader").attr("href", response.dl);
                });
        },
        showAttachmentPreview: function(file_name, file_link) {
            var fn = file_name.toLowerCase();
            var ext = _COLLAB_PVT.checkSupportedImageFile(file_name);
            if(ext !== "") {
                var preview_params = {
                    filename: file_name,
                    filetype: ext,
                    filelink: file_link,
                    multifile: false,
                    currentPos: 0
                };
                var elem_close = document.getElementsByClassName("av-close")[0];
                if (typeof(elem_close) !== "undefined") {
                    $(elem_close).trigger("click");
                }
                App.TicketAttachmentPreview.showPopup(preview_params);
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
        updateConvoMessageCount: function(total_messages) {
            if(typeof total_messages !== "undefined" && Collab.showTotalCount) {
                var message_count_e = $("#collab-btn .collab-message-count");
                message_count_e.text("("+ total_messages +")");
                message_count_e.attr("data-message-count", total_messages);

                var collabModel = App.CollaborationModel;
                $("#collab-btn").removeClass("collab-inited");
                if(total_messages > 0){
                    $("#collab-btn").addClass("collab-inited");
                }
            }
        },
        showCollaboratorsWithLogo: function() {
            var collabModel = App.CollaborationModel;
            var image_class = "convo-started-icon";
            $("#collab-btn ."+ image_class +"").remove();
            if(!!collabModel.currentConversation){
                var convo_data = collabModel.conversationsMap[collabModel.currentConversation.co_id];
                var chosen_member_id;
                if(!!convo_data && convo_data.msgs) {
                    for(var i=0; i<convo_data.msgs.length; i++) {
                        if(convo_data.msgs[i].s_id) {
                            chosen_member_id = convo_data.msgs[i].s_id
                            break;
                        }
                    }
                    avatar_html = _COLLAB_PVT.getAvatarHtml(chosen_member_id, image_class);
                    $("#collab-btn").prepend(avatar_html);
                }
            }
        },

        mentionListSorter: function(arr, item) {
            var huddle = "huddle";
            var collabModel = App.CollaborationModel;
            var currentConvo = collabModel.conversationsMap[collabModel.currentConversation.co_id];
            var remove_huddle_mention = false;

            // Decide when to remove huddle_mention
            if(!currentConvo) {
                remove_huddle_mention = true;
            } else {
                var loopCount = 0;
                for (var member_id in currentConvo.members) {
                    if(loopCount > 0) {
                        remove_huddle_mention = false;
                        break;
                    }
                    if(member_id === collabModel.currentUser.uid) {
                        remove_huddle_mention = true;
                    }
                    loopCount++;
                }
            }

            /*
                dictionary sort + @huddle on top             => nothing after @
                dictionary sort + @huddle removed            => nothing after @, no member or only member is me
                Length+Dictionary sort + @huddle removed     => typed after @, no member or only member is me
                Length+Dictionary sort                       => typed after @
            */

            if(item.length > 0) {
                // Length+Dictionary sort
                if(remove_huddle_mention) {
                    // @huddle brought on top and removed
                    arr = arr.sort(function (a, b) {
                        return (a.username && b.username) ? (a.username == huddle ? -1 : b.username == huddle ? 1 : (a.username.length - b.username.length || (a.username > b.username ? 1 : -1))) : -1;
                    });
                    if(arr.length && (arr[0].username === huddle)) {
                        arr.splice(0, 1);
                    }
                } else {
                    // Length+Dictionary sort
                    arr = arr.sort(function (a, b) {
                        return (a.username && b.username) ? (a.username.length - b.username.length || (a.username > b.username ? 1 : -1)) : -1;
                    });
                }
            } else {
                // dictionary sort
                arr = arr.sort(function (a, b) {
                    return (a.username && b.username) ? (a.username == huddle ? -1 : b.username == huddle ? 1 : (a.username > b.username ? 1 : -1)) : -1;
                });
                if(remove_huddle_mention) {
                    arr.splice(0, 1);
                }
            }
            return arr;
        },

        isCurrentCollabInited: function() {
            var collabModel = App.CollaborationModel;
            return !!collabModel.currentConversation && collabModel.conversationsMap[collabModel.currentConversation.co_id];
        },

        showCollabTour: function() {
            try{
                if(App.CollaborationModel.features.collabTourEnabled && typeof inline_manual_player !== "undefined" && localStorage.collabTourDone !== "true") {
                    inline_manual_player.activateTopic("33220");
                    localStorage.collabTourDone = "true";
                }
            } catch(e) {
                console.log("couldn't show the tour: ", e);
            }
        },

        checkSupportedImageFile: function(file_name) {
            var file_ext = "";
            if (typeof(file_name) !== "undefined") {
                file_ext = (file_name.toLowerCase().match(CONST.FILE_EXT_RE)[0]).substr(1);
                file_ext =  (CONST.PREVIEW_SUPPORTED_FILE_TYPES.indexOf(file_ext) > -1 ? file_ext : "");
            }
            return file_ext;
        },

        showUnreadMessageIndicator: function() {
            $(".collab-unread-indicator").addClass("show-collab-unread-indicator");
        },

        hideUnreadMessageIndicator: function() {
            $(".collab-unread-indicator").removeClass("show-collab-unread-indicator");
        },

        getLastClientMessageId: function(messageList) {
            for(var i=0; i<messageList.length; i++) {
                if(messageList[i].m_type === CONST.MSG_TYPE_CLIENT || messageList[i].m_type === CONST.MSG_TYPE_CLIENT_ATTACHMENT) {
                    return messageList[i].mid;
                }
            }
            return "0";
        }
    };

    var Collab = {
        annotationEvents: [{
            eventName: "mouseenter",
            eventHandler: _COLLAB_PVT.showDiscussionDD
        }, {
            eventName: "mouseleave",
            eventHandler: _COLLAB_PVT.hideDiscussionDD
        }, {
            eventName: "click",
            eventHandler: _COLLAB_PVT.showDiscussionDD
        }],
        hasExapndedTicket: false,
        highlightMode: true,
        shouldBlockTypingMsgSend: false,
        shouldBlockTypingStatusShow: false,

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

        showFlash: function(i18n_kind, params) {
            params = params || {};
            $("#collab-flash-text").html(I18n.translate("collaboration." + i18n_kind, params));
            $("#collab-chat-section").addClass(params.addl_class + " collab-flash-shown");
            $("#collab-chat-section").attr('data-flash-set-time', new Date().getTime());
            var timeout = params.duration || CONST.HIDE_FLASH_DURATION;
            setTimeout(function() {
                if((new Date().getTime() - $("#collab-chat-section").attr('data-flash-set-time')) >= timeout) {
                  $("#collab-chat-section").removeClass("collab-flash-shown collab-flash-3-lines collab-flash-4-lines");
                  $("#collab-flash-popup").removeClass("collab-flash-shown collab-error collab-info");
                }
            }, timeout);
            $("#collab-flash-popup").addClass('collab-' + i18n_kind.split('.')[0]);
        },

        updateFollowConvoUi: function(state) {
          $('#collab-sidebar .collab-follow-btn input').attr('checked', state);
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
            config = config || Collab.parseJson($("#collab-ticket-payload").data("ticketPayload"));

            config.expandCollabOnLoad = !!Collab.getUrlParameter("collab");
            config.scrollToMsgId = Collab.getUrlParameter("message");
            config.followAction = Collab.getUrlParameter("follow");

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
	            "name": config.subject,
	            "co_id": config.display_id,
                "owned_by": config.responder_id,
                "is_closed": config.is_closed,
                "token": config.convo_token,
                "acc_suspend": config.account_suspended
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

            _COLLAB_PVT.showCollabTour();

            Collab.expandCollabOnLoad = config.expandCollabOnLoad;
            Collab.scrollToMsgId = config.scrollToMsgId;
            Collab.followAction = config.followAction;

            _COLLAB_PVT.unbindEvents();
	        _COLLAB_PVT.events();
            if(App.CollaborationModel.features.followerEnabled) {
              $('#collab-sidebar .collab-scroll-box-cover').addClass('follower-enabled');
            }

            _COLLAB_PVT.setHighlightMode(true);
            console.log("Started collaboration.");

	    },

        loadConversation: function(cb) {
            var collabModel = App.CollaborationModel;
            collabModel.loadConversation(function(response) {
                if(!!response) {
                    $("#collab-chat-section").removeClass("empty-chat-view");
                    _COLLAB_PVT.conversationCreateOrLoadCb(response);
                    if(typeof response.mcount !== "undefined") {
                        Collab.showTotalCount=true;
                    }
                    _COLLAB_PVT.updateConvoMessageCount(response.mcount);
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
            members = members || [];

            var conversationObj = {
                "co_id": currentConversation.co_id || cn,
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

        updateSentMessage: function(msg) {
            if(!!$("#collab-" + msg.ts).length) {
                $("#collab-" + msg.ts).attr("id", "collab-" + msg.mid);
                if(App.CollaborationModel.features.markReadEnabled) {
                    App.CollaborationModel.updateReadMarker(msg.mid);
                }
                var ann_elem = $(".annotation[data-message-id=" + msg.ts + "]");
                if(ann_elem.length) {
                    ann_elem.attr("id", "annotation-" + msg.mid);
                    ann_elem.attr("data-message-id", msg.mid);
                }
                // send notification
                App.CollaborationModel.sendNotification(msg);
            }
        },

        updateReadReceipt: function() {
          // UI code for updating read receipt for [TH-1059] YTD 
        },

        addTypingHtml: function(msg) {
            if(!Collab.isCollabOpen() || !msg.body || Collab.shouldBlockTypingStatusShow) {
                return;
            }
            var collabModel = App.CollaborationModel;
            var msg_body = Collab.parseJson(msg.body);
            var typer_name = collabModel.usersMap[msg_body.t_id] ? collabModel.usersMap[msg_body.t_id].name : CONST.DUMMY_USER.name;

            Collab.shouldBlockTypingStatusShow = true;
            $("#collab-typing-status").empty().append(JST[CONST.COLLABORATION_TYPING_MESSAGE_TEMPLATE]({
                    current_typer: typer_name,
            }));

            setTimeout(function() {
                Collab.shouldBlockTypingStatusShow = false;
                $("#collab-typing-status").empty();
            }, CONST.MAX_TYPING_STATUS_AGE);
        },


        addMessageHtml: function(msg, render_type) {
	        if(!msg.body) {
                return;
            }

            var collabModel = App.CollaborationModel;

            var msg_meta, annotation_meta, is_annotation_invalid, reply_to_meta;
            if(!!msg.metadata) {
                msg_meta = Collab.parseJson(msg.metadata);
                annotation_meta = msg_meta.annotations ? Collab.parseJson(msg_meta.annotations) : null;
                reply_to_meta = msg_meta.reply ? Collab.parseJson(msg_meta.reply) : null;

                if(collabModel.invalidAnnotationMessages.indexOf(msg.mid) >= 0) {
                    is_annotation_invalid = true;
                }
            }

            var live_msg_by_others = msg.s_id !== collabModel.currentUser.uid && msg.incremental;
            if(live_msg_by_others && collabModel.features.markReadEnabled) {
                if(Collab.isCollabOpen()) {
                    collabModel.updateReadMarker(msg.mid);
                } else {
                    _COLLAB_PVT.showUnreadMessageIndicator();
                }
            }
            if(live_msg_by_others && !!annotation_meta) {
                annotation_meta.messageId = msg.mid;
                collabModel.restoreAnnotations(annotation_meta);
            }

            if((msg.m_type === CONST.MSG_TYPE_CLIENT || msg.m_type === CONST.MSG_TYPE_CLIENT_ATTACHMENT) && msg.incremental) {
                // Update total message count for every message added incrementally;
                _COLLAB_PVT.updateConvoMessageCount(Number($("#collab-btn .collab-message-count").attr("data-message-count"))+1);
            }

            var userId = !!msg.s_id ? msg.s_id : (render_type === CONST.TYPE_SENT ? collabModel.currentUser.uid : "");
            var add_method = msg.forcePrepend ? "prepend" : "append";
            var sender_name = collabModel.usersMap[msg.s_id] ? (collabModel.usersMap[msg.s_id].deleted !== "1" ? collabModel.usersMap[msg.s_id].name : I18n.translate('collaboration.collab_deleted_user')) : CONST.DUMMY_USER.name;

            function renderMsg(msg_body, msg_type) {
                $("#collab-sidebar #scroll-box")[add_method](JST[CONST.COLLABORATION_MESSAGE_TEMPLATE]({
                    avatar_html: !!userId ? _COLLAB_PVT.getAvatarHtml(userId) : "",
                    sender_id: userId,
                    sender_name: collabModel.currentUser.name !== sender_name ? sender_name : "",
                    msg_body: msg_body,
                    msg_body_raw: msg.body,
                    /*
                    *   TODO (mayank): Need to take care of time zone here
                    */
                    time_stamp_text: collabModel.formatTimestamp(Math.floor((new Date().getTime() - collabModel.parseUTCDateToLocal(msg.created_at).getTime()) / 1000)),
                    msg_id: msg.mid || msg.ts,
                    msg_render_type: render_type,

                    // TODO (mayank): add more safechecks
                    annotation_body: annotation_meta ? annotation_meta.textContent : "",
                    reply_to_meta: reply_to_meta || "",
                    is_attachment: msg_type ? !!msg_type.attachment : false,
                    is_annotation_invalid: !!is_annotation_invalid,
                    invalid_annotation_text: I18n.translate("collaboration.error.highlight_missing"),
                    enable_reply_to: !!collabModel.features.replyToEnabled,
                    reply_tooltip: I18n.translate("collaboration.reply"),
                    is_image_file: _COLLAB_PVT.checkSupportedImageFile(msg_body.fn) !== "",
                }));
            }

            // HTMLescape > Smilify > LinkifyUnames > LinkifyAllLinks >
            if(msg.m_type === CONST.MSG_TYPE_CLIENT) {
                var msg_body, emoji_class_attr, msg_text_content, msg_with_emojis, img_tags;
                if(typeof App.CollaborationEmoji !== "undefined") {
                    msg_with_emojis = App.CollaborationEmoji.smilify(msg.body);
                    img_tags = msg_with_emojis.match(CONST.IMAGE_TAG_RE) || [];
                    msg_text_content = $("<span>" + msg_with_emojis + "</span>").text().trim();
                    emoji_class_attr = (!!msg_text_content || (img_tags.length > CONST.MAX_JUMBOMOJI_COUNT)) ? "class='emoji'" : "class='jumbo emoji'";
                    msg_body = App.CollaborationEmoji.smilify(msg.body, emoji_class_attr, CONST.EMOJIS_URL);

                    var um = collabModel.usersTagMap;
                    var uarr = [];
                    for(var handle in um) {
                        if(!!um[handle].uid && um[handle].deleted !== "1") {
                            uarr.push(handle);
                        }
                    }

                    uarr.push(CONST.MENTION_EVERYONE_TAG.split("@")[1]);

                    var gnm = collabModel.groupsTagMap;
                    for(var name in gnm) {
                        uarr.push(name);
                    }
                    msg_body = Collab.linkifyExternalLinks(Collab.strongifyUserNames(msg_body, uarr));
                } else {
                     msg_body = msg.body;
                }
                msg.created_at = msg.created_at || collabModel.getCurrentUTCTimeStamp();
                renderMsg(msg_body);
            } else if(msg.m_type === CONST.MSG_TYPE_CLIENT_ATTACHMENT) {
                var msg_body = Collab.parseJson(msg.body);
                msg_body.pl = msg_body.pl || " ";
                msg.created_at = msg.created_at || collabModel.getCurrentUTCTimeStamp();
                renderMsg(msg_body, {"attachment": true});
                _COLLAB_PVT.refreshAttachmentUri(msg_body.fid);
            }


            _COLLAB_PVT.scrollToBottom();
	    },

        linkifyExternalLinks: function(msg_body) {
            return msg_body.replace(CONST.EXTERNAL_URL_RE, function(matched, protocol, email_handle, offset, source_string) {
                return "<a href='" + (!!email_handle ? "mailto:" : (!!protocol ? "" : "http://")) + matched + "' target=_blank title='" + matched + "'><u>" + (matched.length <= 70 ? matched : matched.substring(0, 69) + "..") + "</u></a>";
            });
        },

        strongifyUserNames: function(text, uarr) {
            var self_name = App.CollaborationModel.currentUser.email.split("@")[0];
            var everyone_name = CONST.MENTION_EVERYONE_TAG.split("@")[1];
            var mention_to_notify_class;
            return text.replace(CONST.MENTION_RE,
            function (matched, username, offset, source_string) {
                var was_notified_with = (username === self_name || username === everyone_name);
                mention_to_notify_class = (was_notified_with ? "mention-to-notify" : "");
                return uarr.indexOf(username) >= 0 ? ("<span data-mention-text='"+ matched +"' class='collab-mention-name tag-handle "+ mention_to_notify_class +"'>"+ matched +"</span>") : matched;
            });
        },


        // TODO (mayank): must be called on every ticket_detail load
        // should be called only once per ticket;
        enableMentions: function() {
            var usersToMention = [];
            var collabModel = App.CollaborationModel;

            if(!!collabModel.features.groupMentionsEnabled) {
                for(var grp_id in collabModel.groupsMap) {
                    usersToMention.push({
                        name: collabModel.groupsMap[grp_id].name,
                        username: collabModel.groupsMap[grp_id].tag,
                        group: true
                    });
                }
            }

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
                username: "huddle",
                job_title: "All members of this Team Huddle",
                id_post_fix: "mention-list"
            });
            menu_prefix = "<label class='info'>"+ I18n.translate("collaboration.collab_max_out_info", {max_collaborators: "<b>" + CONST.HELPKIT_MAX_COLLABORATORS + "</b>", contact_person: "<b>" + "your Admin" + "</b>"}) +"</label>";
            menu_item = '<div id="collab-mention-picker" class="collab-mention-picker ' + (is_colab_max_out ? "max-out" : "") + '"> ' + menu_prefix + ' <ul></ul></div>';

            var options = {
                "data": usersToMention,
                "editor": "#collab-sidebar #send-message-box",
                "menuHtml": menu_item,
                "maxItems": 7,
                "filterKeys": ["name", "username"],
                "tagAttribute": "username",
                "sort": _COLLAB_PVT.mentionListSorter
            };
            if(typeof lightMention !== "undefined") {
                var lm = new lightMention(options);
                lm.bindMention();
            } else {
                console.warn("lightMention sdk not present. couldn't start @mentions.");
            }
        },

        parseJson: function (data) {
            try {
                if(typeof data === "string") {
                    return JSON.parse(data)
                } else {
                    return data;
                }
            } catch(e) {
                console.error("parse error: ", e, "\n\ntried to parse: ", data);
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
            Collab.showFlash("error.network_err");
        },
        onReconnecthandler: function(response) {
            Collab.networkDisconnected = false;
            if($("#collab-ticket-payload").length) {
                var config = $("#collab-ticket-payload").data("ticketPayload");
                if(config) {
                    Collab.initingPostReconnect = true;
                    App.CollaborationUi.initUi(Collab.parseJson(config));
                }
            }
            _COLLAB_PVT.disableCollabUiIfNeeded();
        },
        activateBellListeners: function() {
            _COLLAB_PVT.bellEvents();
        },
        getFileDisplayName: function(file_name) {
            var display_name = file_name;
            var allowed_fn_length = 18;
            var ext_start_idx = file_name.lastIndexOf(".");
            var extn = file_name.substr(ext_start_idx);

            if(file_name.length > allowed_fn_length) {
                var  slice_on = allowed_fn_length - extn.length - 2;
                display_name = file_name.substr(0, slice_on) + ".." + extn;
            }
            return display_name;
        },
        dpLoadComplete: function(elem) {
            $(elem).removeClass("hide");
        },
        stringify: function(data) {
            if(typeof data === "string") {
                return data;
            }
            return (window.Prototype && window.Prototype.Version < '1.7' && Array.prototype.toJSON && Object.toJSON) ? Object.toJSON(data) : JSON.stringify(data);
        }
    };
    return Collab;
})(window.jQuery);
