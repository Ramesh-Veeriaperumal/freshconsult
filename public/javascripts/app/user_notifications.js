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
        preferences: null,
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
            this.bindShowPreferencesClick();
            this.bindShowNotificationsClick();
            this.bindPrefClick();
            this.bindEnableDesktopNotifications();
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
        initIris: function(jwt){
            var self = this;
            if(window.Iris && window.RTS && window.PUBSUBio){
              this.iris = new Iris({
                jwt: jwt,
                live: true,
                onNotification: function(data){
                    if(!data.msg) return;
                    data = JSON.parse(JSON.parse(data.msg).payload);

                    if(!!data.system){
                        return;
                    }

                    if(!data.extra) {return};
                    data.extra = JSON.parse(data.extra);
                    var actionObj = self.flattenNotificationObject(data);

                    var action = I18n.t("user_notifications."+data.action, actionObj)
                    var actionType = I18n.t("user_notifications.types."+data.action)
                    var notification = {
                        content: "<b>"+data.actor+"</b> "+action,
                        content_text: data.actor+" "+action.replace(/<[^>]*>/g,""),
                        created_at: data.extra.action_date || data.created_at,
                        notification_type: actionType,
                        unreadIds: data.id+"",
                        action_url: data.extra.action_url,
                        actor_text: data.actor,
                        actor_id: data.extra.actor_id
                    };

                    // When we get the first notification - [FRESHCHAT-550]
                    $(".no-notification-message").remove();

                    self.allNotifications.unshift(notification);
                    self.groupedNotifications.push(notification);
                    self.renderOneNotification(notification);
                    self.setSeenIndicator(false);
                    self.readAllButtonCheck();

                    // Generate the desktop notification
                    self.notify(data.id, notification);

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
        seenAll: function(){
            var self = this;
            if($("#user-notification-icon").hasClass("unseen") && this.iris){
                this.iris.seenAll(function(){ self.setSeenIndicator(true);});
            }
        },
        setSeenIndicator: function(bool){
            if(bool){
                $("#user-notification-icon").removeClass("unseen");
            } else {
                $("#user-notification-icon").addClass("unseen");
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
        fetchUserPreferences: function(done){
            if(!this.iris){ return done("Iris not found."); }
            this.iris.getUserPreferences(done);
        },
        setUserPreference: function(pref, done){
            /**
             * pref {
             *     notification_type: "string",
             *     pipe: "rts|mobile",
             *     enabled: "true|false"
             * }
             */
            if(!this.iris){ return done("Iris not found."); }
            this.iris.setUserPreference(pref,done);
        },
        bindDocumentClick: function () {
            var self = this;
            $(document).on("click.usernotification", function (ev) {
                var parent_check = $(ev.target).parents("#user-notifications-popover");
                if (!parent_check.get(0)) {
                    $("#user-notifications-popover").addClass("hide");
                    self.unbindScroll();
                }
            });
        },
        bindNotification: function () {
            var self = this;
            $(document).on("click.usernotification","#user-notification-icon",function(ev){
                ev.stopPropagation();
                $("#user-notifications-popover").toggleClass('hide');
                if(!$("#user-notifications-popover").hasClass('hide')){
                    self.bindScroll();
                    self.seenAll();
                }
            })
        },
        bindReadAll: function () {
            var self = this;
            $(document).on("click.usernotification",".user-notifications-read-all",function(ev){
                ev.preventDefault();
                ev.stopPropagation();
                if(self.iris){
                    self.iris.readAll(function(err,result){
                        if(!err){
                            $('#user-notifications-popover .notifications-list a').removeClass('unread').addClass("read").data("unreadIds","");
                            self.readAllButtonCheck();
                        }
                    }); 
                }
                self.seenAll();
            })
        },
        markNotificationRead: function(elem) {
            var self = this;
            if(elem.hasClass('unread') && !!elem.data('unreadIds')){
                var unreadIds = elem.data('unreadIds');
                unreadIds = (typeof unreadIds == "number") ? [unreadIds+""] : unreadIds.split(",");
                if(self.iris){
                    self.iris.readNotification(unreadIds, function(err,result){
                        elem.addClass("read").removeClass("unread");
                        self.readAllButtonCheck();
                    }); 
                }
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
                var curScrollTop = notifList[0].scrollTop;
                // Load more notifications
                self.fetchNotifications(self.numResultsToFetch, true, function(){
                    // Remove the spinner
                    notifList.animate({scrollTop: curScrollTop + 300}, 1000);
                    $("#load-more-notifications").removeClass("loading");
                });
            })
        },
        bindScroll: function(){
            // Making sure we don't duplicate the bindings.
            this.unbindScroll();
            $(document).on('mousewheel.usernotification', '.notifications-list-wrapper', function(e, d) {
                var notifList = $(".notifications-list-wrapper");
                var scrollHeight = notifList.get(0).scrollHeight;
                var height = notifList.height();
                if((this.scrollTop === (scrollHeight - height) && d < 0) || (this.scrollTop === 0 && d > 0)) {
                  e.preventDefault();
                }
            });
        },
        unbindScroll: function(){
            $(document).off('mousewheel.usernotification');
        },
        bindShowPreferencesClick: function(){
            var self = this;
            $(document).on('click.usernotification','.show-user-prefs', function(){
                $(".unp-list").addClass("hide");
                $(".unp-prefs").removeClass("hide");
                self.onPrefsShow();
            });
        },
        bindShowNotificationsClick: function(){
            $(document).on('click.usernotification','.show-user-notifications', function(){
                $(".unp-list").removeClass("hide");
                $(".unp-prefs").addClass("hide");
            });
        },
        bindPrefClick: function(){
            var self = this;
            $(document).on("click.usernotification",".notif-pref-item a", function(){
                var elem = $(this);
                var isEnabled = elem.hasClass("enabled");
                var ntype = elem.data("ntype");
                var pipe = elem.data("pipe");
                self.setUserPreference({
                    notification_type: ntype,
                    pipe: pipe,
                    enabled: !isEnabled
                }, function(err,result){
                    if(!err){
                        isEnabled ? elem.removeClass("enabled") : elem.addClass("enabled");
                        self.preferences[ntype][pipe] = !isEnabled;
                    } else {
                        console.error("Could not set user preferece.",err);
                    }
                });
            })
        },
        bindEnableDesktopNotifications: function(){
            var self = this;
            // Let's check if the browser supports notifications
            if(!("Notification" in window) || Notification.permission === "granted"){
                self.desktopNotificationBtnMsg("granted");
                return;
            }

            if(Notification.permission === "denied"){
                // TODO: Handle this case by publishing a solution article and linking that here.
            }

            $(document).on('click.usernotification','.enable-desktop-notifications-button', function(){
                self.askNotificationPermission();
                self.desktopNotificationBtnMsg("help");
            })   
        },
        hideLoadMoreButton: function(){
            $("#load-more-notifications").addClass('hide');
        },
        showLoadMoreButton: function(){
            $("#load-more-notifications").removeClass('hide');
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
                var unread = false;
                var unreadIds = [];
                var actor_text, action_text;
                var ngroup = collapsed[key].nArray;
                var actors = collapsed[key].actor_names;
                var last = ngroup[0];
                var oldest = ngroup[0];
                
                for (var i = ngroup.length - 1; i >= 0; i--) {
                    var n = ngroup[i];
                    if(!n.read_at){
                        var created = n.extra.action_date || n.created_at;
                        var oldestCreated = oldest.extra.action_date || oldest.created_at;
                        var isOlder = new Date(created) < new Date(oldestCreated);
                        if(isOlder) oldest = n;
                    }
                }

                actors[0] = this.safe(actors[0])
                if(actors.length == 1){
                    actor_text = actors[0];
                } else if(actors.length==2){
                    actors[1] = this.safe(actors[1]);
                    actor_text = I18n.t("user_notifications.actor_text_2",{actor_name_1:actors[0], actor_name_2: actors[1]});
                } else {
                    actor_text = I18n.t("user_notifications.actor_text_multi",{actor_name_1:actors[0], more_actors_count: actors.length-1});
                }

                var action = "user_notifications."+last.action;
                var actionType = I18n.t("user_notifications.types."+last.action);
                var actionObj = this.flattenNotificationObject(last);
                if(ngroup.length>1){
                    actionObj.count = ngroup.length;
                    action_text = I18n.t(action+"_multi", actionObj);
                } else {
                    action_text = I18n.t(action, actionObj);
                }

                this.groupedNotifications.push({
                    content: "<b>"+actor_text+"</b> "+action_text,
                    content_text: actor_text+" "+action.replace(/<[^>]*>/g,""),
                    created_at: last.extra.action_date || last.created_at,
                    notification_type: actionType,
                    unreadIds: collapsed[key].unreadIds.join(','),
                    action_url: oldest.extra.action_url,
                    actor_text: actor_text,
                    actor_id: last.extra.actor_id
                });
            }

            return _.sortBy(this.groupedNotifications, function(a){
                return -(new Date(a.created_at)).getTime();
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
            if(!$("#wrap #user-notifications-popover .notifications-list .unread").length){
                $(".user-notifications-read-all").addClass("hide");
            } else {
                $(".user-notifications-read-all").removeClass("hide");
            }
        },
        flattenNotificationObject: function(notification){
            var obj = {};
            var self = this;

            // Copy object
            for(var key in notification){
                if(key!="extra"){
                    obj[key] = self.safe(notification[key]);
                }
            }

            if(!notification.extra){
                return obj;
            }

            if(typeof notification.extra == "string"){
                obj.extra = JSON.parse(notification.extra)
            }

            for(var key in notification.extra){
                obj[key] = self.safe(notification.extra[key]);
            }

            // Truncate the subject if it exists
            if(obj.object.length>70) {
                obj.object = obj.object.substr(0,67)+"...";
            }

            return obj;
        },
        onPrefsShow: function(){
            var self = this;
            // Check if preferences object exists, else fetch it
            if(!this.preferences){
                this.fetchUserPreferences(function(err,prefs){
                    if(!err){
                        self.mapUserPrefs(prefs);
                        self.renderPrefs();
                        $(".notifications-preferences loader").addClass("hide");
                    } else {
                        console.error("Could not fetch user preferences");
                    }
                })
            } else {
                self.renderPrefs();
                $(".notifications-preferences loader").addClass("hide");
            }
        },
        mapUserPrefs: function(prefs){
            var self = this;
            // Given an array of prefs, creates the appropriate preference object.
            self.preferences = {};
            for(var i = prefs.length-1; i >= 0; i--){
                var p = prefs[i];
                self.preferences[p.notification_type] = self.preferences[p.notification_type] || {};
                if(p.pipe == "android" || p.pipe == "ios") p.pipe = "mobile";
                self.preferences[p.notification_type][p.pipe] = p.enabled;
            }
        },
        renderPrefs: function(){
            // Initial state
            $(".notif-pref-item .npa-web, .notif-pref-item .npa-mobile").addClass("enabled");

            // See which ones need to be disabled
            for(var ntype in this.preferences){
                var pref = this.preferences[ntype];
                for(var pipe in pref){
                    if(!pref[pipe]){
                        $(".notif-pref-item .npa-"+pipe+"[data-ntype="+ntype+"]").removeClass("enabled");
                    }
                }
            }

            $(".notifications-preferences .loader").addClass("hide");
        },
        notify: function(id, notification){
            var self = this;

            // Play the notification sound
            $(".user-notification-sound")[0].play()

            // Let's check if the browser supports notifications
            if (!("Notification" in window)) {
                console.log("This browser does not support desktop notification");
            }

            // Let's check whether notification permissions have already been granted
            else if (Notification.permission === "granted") {
                // If it's okay let's create a notification
                var n = new Notification(notification.notification_type,{
                    icon: "/images/misc/admin-logo.png",
                    body: notification.content_text,
                    data: {url : notification.action_url },
                    tag: id
                });
                n.onclick = function(event){
                    event.preventDefault();
                    window.open(event.currentTarget.data.url, '_blank');
                    self.iris.readNotification([id], function(err,result){}); 
                    event.currentTarget.close();
                }
            }
        },
        askNotificationPermission: function(){
            var self = this;
            Notification.requestPermission(function(permission){
                self.desktopNotificationBtnMsg(permission);
            })
        },
        desktopNotificationBtnMsg: function(msg){
            $(".enable-desktop-notifications-button span").addClass('hide');
            $(".enable-desktop-notifications-button span."+msg).removeClass('hide');
            if(msg=="default") {
                $(".enable-desktop-notifications-button").removeClass("disabled");
            } else {
                $(".enable-desktop-notifications-button").addClass("disabled");
            }
        },
        safe: function(str){
            var tmp = document.implementation.createHTMLDocument("New").body;
            tmp.innerHTML = str;
            return tmp.textContent || tmp.innerText || "";
            // return String(str).replace(/<(?:.|\n)*?>/gm, '');
        },
        destroy: function () {
            $(document).off(".usernotification");
        }
    };
}(window.jQuery));