/*jslint browser: true, devel: true */
/*global  App, FreshWidget, escapeHtml */

window.App = window.App || {};
(function ($) {
    "use strict";

    App.UserNotification = {
        numResultsToFetch: 50,
        notifications: [],
        allNotifications: [],
        groupedNotifications: [],
        next_page: false,
        initialize: function () {
            var self = this;
            this.getJwt(function(jwt){
                self.initIris(jwt);
                self.fetchNotifications(self.numResultsToFetch);
            });
            
            this.bindDocumentClick();
            this.bindNotification();
            this.bindNotificationClick();
            this.bindLoadMoreNotifications();
            this.bindReadAll();
        },
        getJwt: function(done){
            jQuery.get('/notification/user_notification/token', function(result){
                if(result && result.jwt){
                    done(result.jwt)
                } else {
                    console.error("Could not get the JWT.")
                }
            })
        },
        seenAll: function(){
            var self = this;
            this.iris.seenAll(function(){
                self.setSeenIndicator(true);
            })
        },
        setSeenIndicator: function(bool){
            if(bool){
                $("#user-notification-icon").removeClass("unseen");
            } else {
                $("#user-notification-icon").addClass("unseen");
            }
        },
        initIris: function(jwt){
            var self = this;
            if(window.Iris && window.RTS && window.PUBSUBio){
              this.iris = new Iris({
                jwt: jwt,
                live: true,
                onNotification: function(data){
                    if(!data.msg) return;
                    data = JSON.parse(JSON.parse(data.msg).payload);

                    if(!data.extra || !!data.system) return;
                    data.extra = JSON.parse(data.extra);
                    var actionObj = self.flattenNotificationObject(data);

                    data.action = I18n.t("user_notifications."+data.action, actionObj)
                    var notification = {
                        content: data.actor+" "+data.action,
                        created_at: data.created_at,
                        notification_type: data.notification_type.replace(/_/g,' '),
                        unreadIds: data.id+"",
                        action_url: data.extra.action_url,
                        actor_text: data.actor,
                        actor_id: data.extra.actor_id
                    };
                    self.allNotifications.unshift(notification);
                    self.groupedNotifications.push(notification);
                    self.renderOneNotification(notification);
                    self.setSeenIndicator(false);
                    self.readAllButtonCheck();

                    if(data.notification_type === "discussion") {
                        var collab_event = new CustomEvent('collabNoti', { 'detail': {
                            "ticket_id": data.extra.ticket_id,
                            "noti_id": data.id
                        }});
                        document.dispatchEvent(collab_event);
                    }
                }
              })
            }
        },
        fetchNotifications: function(numResults, next, done){
            var self = this;
            var fnName = next ? "fetchNextNotifications" : "fetchNotifications";

            if(this.iris){
                this.iris[fnName](numResults, function(err,result){
                    if(!err && result && result.notifications.length){
                        self.allNotifications = self.allNotifications.concat(result.notifications);
                        self.notifications = result.notifications;
                        self.next_page = !!result.next_page;
                    }
                    self.renderNotifications();
                    if(done) done();
                })
            }
        },
        bindDocumentClick: function () {
            $(document).on("click.usernotification", function (ev) {
                var parent_check = $(ev.target).parents("#user-notifications-popover");
                if (!parent_check.get(0)) {
                    $("#user-notifications-popover").addClass("hide");
                }
            });
        },
        bindNotification: function () {
            var self = this;
            $(document).on("click.usernotification","#user-notification-icon",function(ev){
                ev.stopPropagation();
                $("#user-notifications-popover").toggleClass('hide');
                self.seenAll();
            })
        },
        bindReadAll: function () {
            var self = this;
            $(document).on("click.usernotification",".user-notifications-read-all",function(ev){
                ev.preventDefault();
                ev.stopPropagation();
                self.iris.readAll(function(err,result){
                    if(!err){
                        $('#user-notifications-popover .notifications-list a').addClass("read").data("unreadIds","");
                    }
                }); 
                self.seenAll();
            })
        },
        markNotificationRead: function(elem) {
            var self = this;
            if(!elem.hasClass('read')){
                var unreadIds = elem.data('unreadIds');
                unreadIds = (typeof unreadIds == "number") ? [unreadIds+""] : unreadIds.split(",");
                self.iris.readNotification(unreadIds, function(err,result){
                    elem.addClass("read").removeClass("unread");
                }); 
                self.readAllButtonCheck();
            }
        },
        bindNotificationClick: function(){
            var self = this;
            $(document).on('click.usernotification', '#user-notifications-popover .notifications-list a', function(ev){
                ev.preventDefault();
                ev.stopPropagation();
                var elem = $(this);
                self.markNotificationRead(elem);
                pjaxify(elem.attr("href"));
            })
        },
        bindLoadMoreNotifications: function(){
            var self = this;
            var notifList = $(".notifications-list");
            $(document).on("click.usernotification","#load-more-notifications",function(ev){
                ev.stopPropagation();
                $("#load-more-notifications").addClass("loading");
                // Load more notifications
                self.fetchNotifications(self.numResultsToFetch, true, function(){
                    // Remove the spinner
                    notifList.animate({scrollTop: notifList[0].scrollHeight}, 1000)
                    $("#load-more-notifications").removeClass("loading");
                });
            })
        },
        hideLoadMoreButton: function(){
            $("#load-more-notifications").css('display','none');
        },
        showLoadMoreButton: function(){
            $("#load-more-notifications").css('display','block');
        },
        getGroupedNotifications: function(){
            var collapsed = {};
            
            for (var i = 0; i < this.notifications.length; i++) {
                var n = this.notifications[i];
                n.extra = JSON.parse(n.extra);
                n.extra.collapse_key = n.extra.collapse_key || new Date().getTime()+""+i;
                var cObj = collapsed[n.extra.collapse_key] = collapsed[n.extra.collapse_key] || {nArray:[], unreadIds:[], actor_ids: [], actor_names: []};
                
                cObj.nArray.push(n);

                // For unread notifications
                if(!n.read_at)  cObj.unreadIds.push(n.id);
                
                // For multiple actors
                if(cObj.actor_ids.indexOf(n.extra.actor_id)==-1) {
                    cObj.actor_names.push(n.actor);
                    cObj.actor_ids.push(n.extra.actor_id);
                }

                // Set the seen indicator
                if(!n.seen_at) this.setSeenIndicator(false);
            }

            for(var key in collapsed){
                var created_at = new Date("1970-01-01");
                var unread = false;
                var unreadIds = [];
                var actor_text, action_text;
                var ngroup = collapsed[key].nArray;
                var actors = collapsed[key].actor_names;
                var last = ngroup[0];
                
                var unread_notifications = ngroup.filter(function(n) {return !(n.read_at)});
                if(unread_notifications.length) {
                    last = unread_notifications.sort(function(a, b) {
                        return new Date(a.created_at) - new Date(b.created_at)
                    })[0];
                }

                if(actors.length == 1){
                    actor_text = actors[0];
                } else if(actors.length==2){
                    actor_text = I18n.t("user_notifications.actor_text_2",{actor_name_1:actors[0], actor_name_2: actors[1]});
                } else {
                    actor_text = I18n.t("user_notifications.actor_text_multi",{actor_name_1:actors[0], more_actors_count: actors.length-1});
                }

                var action = "user_notifications."+last.action;
                var actionObj = this.flattenNotificationObject(last);
                if(ngroup.length>1){
                    actionObj.count = ngroup.length;
                    action_text = I18n.t(action+"_multi", actionObj);
                } else {
                    action_text = I18n.t(action, actionObj);
                }

                this.groupedNotifications.push({
                    content: actor_text+" "+action_text,
                    created_at: new Date(last.created_at),
                    notification_type: last.notification_type.replace(/_/g,' '),
                    unreadIds: collapsed[key].unreadIds.join(','),
                    action_url: last.extra.action_url,
                    actor_text: actor_text,
                    actor_id: last.extra.actor_id
                });
            }

            return this.groupedNotifications.sort(function(a,b){
                return b.created_at - a.created_at;
            });
        },
        renderNotifications: function(){
            if(this.allNotifications.length==0){
                $(".notifications-list").html("<a class='read no-notification-message'>No new notifications.</a>");
            } else {
                $(".notifications-list").html("");
                var groupedNotifications = this.getGroupedNotifications();
                for (var i = groupedNotifications.length - 1; i >= 0; i--) {
                    this.renderOneNotification(groupedNotifications[i]);
                }
            }

            this.next_page ? this.showLoadMoreButton() : this.hideLoadMoreButton();
            this.readAllButtonCheck();
        },
        renderOneNotification: function(notification){
            var jstUrl = 'app/user_notifications/templates/user_notification_item';
            var nItem = JST[jstUrl](notification);
            $(nItem).prependTo("#user-notifications-popover .notifications-list");
        },
        readAllButtonCheck: function(){
            if(!$("#user-notifications-popover .notifications-list .unread").length){
                $(".user-notifications-read-all").addClass("hide");
            } else {
                $(".user-notifications-read-all").removeClass("hide");
            }
        },
        flattenNotificationObject: function(notification){
            var obj = {};

            // Copy object
            for(var key in notification){
                if(key!="extra"){
                    obj[key] = notification[key];
                }
            }

            if(!notification.extra){
                return obj;
            }

            if(typeof notification.extra == "string"){
                obj.extra = JSON.parse(notification.extra)
            }

            for(var key in notification.extra){
                obj[key] = notification.extra[key];
            }
            return obj;
        },
        destroy: function () {
            $(document).off(".usernotification");
        }
    };
}(window.jQuery));