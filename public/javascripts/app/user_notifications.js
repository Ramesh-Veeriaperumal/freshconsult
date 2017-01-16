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

                    var notification = {
                        content: data.actor+" "+data.action+" "+data.object,
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
        bindNotificationClick: function(){
            var self = this;
            $(document).on('click.usernotification', '#user-notifications-popover .notifications-list a', function(ev){
                ev.preventDefault();
                ev.stopPropagation();
                var elem = $(this);
                if(!elem.hasClass('read')){
                    var unreadIds = elem.data('unreadIds');
                    unreadIds = (typeof unreadIds == "number") ? [unreadIds+""] : unreadIds.split(",");
                    self.iris.readNotification(unreadIds, function(err,result){
                        elem.addClass("read");
                        pjaxify(elem.attr("href"));
                    }); 
                } else {
                    pjaxify(elem.attr("href"));
                }
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

            // console.log("Grouping these notifications",this.notifications);

            for (var i = 0; i < this.notifications.length; i++) {
                var n = this.notifications[i];
                n.extra = JSON.parse(n.extra);
                n.extra.collapse_key = n.extra.collapse_key || new Date().getTime()+""+i;
                collapsed[n.extra.collapse_key] = collapsed[n.extra.collapse_key] || {nArray:[], unreadIds:[]};
                collapsed[n.extra.collapse_key].nArray.push(n);
                if(!n.read_at) collapsed[n.extra.collapse_key].unreadIds.push(n.id);

                if(!n.seen_at) this.setSeenIndicator(false);
            }

            for(var key in collapsed){
                var created_at = new Date("1970-01-01");
                var unread = false;
                var unreadIds = [];
                var ngroup = collapsed[key].nArray;
                var last = ngroup[0];

                if(ngroup.length==1){
                    var actor_text = last.actor;
                } else if(ngroup.length==2){
                    var actor_text = last.actor+" and "+ngroup[1].actor;
                } else {
                    var actor_text = last.actor+" and "+(ngroup.length-1)+" more";
                }

                this.groupedNotifications.push({
                    content: actor_text+" "+last.action+" "+last.object,
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
        },
        renderOneNotification: function(notification){
            var jstUrl = 'app/user_notifications/templates/user_notification_item';
            var nItem = JST[jstUrl](notification);
            this.tryImageLoad($(nItem).prependTo("#user-notifications-popover .notifications-list").find("img"));
        },
        tryImageLoad: function(img){
            var $img = $(img);
            var userId = $img.data("userId");
            $.get("/users/"+userId+"/profile_image_path", function(result){
                if(result.path){
                    $img.attr('src',result.path);
                    $img.removeClass('hide');
                    $img.siblings().addClass('hide');
                }
            })
        },
        destroy: function () {
            $(document).off(".usernotification");
        }
    };
}(window.jQuery));