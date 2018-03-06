/* jslint browser: true, devel: true */
/* global  App, FreshWidget, escapeHtml, window, jQuery, Iris, I18n, CustomEvent, document, pjaxify, Notification, localStorage, _, JST */
/* eslint-disable indent, strict, space-before-function-paren, space-before-blocks, no-param-reassign, no-extra-boolean-cast, keyword-spacing, max-len, vars-on-top, comma-dangle, no-plusplus */

window.App = window.App || {};
(function ($) {
    'use strict';

    App.UserNotification = {
        numResultsToFetch: 50,
        notifications: [],
        allNotifications: [],
        groupedNotifications: [],
        next_page: false,
        preferences: null,
        muteState: false,
        firstFetch: true,
        initialize: function () {
            var self = this;
            this.getJwt(function(jwt){
                self.initIris(jwt);
                self.fetchCounts();
                // self.fetchNotifications(self.numResultsToFetch);
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
            this.bindMuteChange();
            this.identifyTab();
        },
        getJwt: function(done){
            jQuery.get('/notification/user_notification/token', function(result){
                if(result && result.jwt){
                    done(result.jwt);
                } else {
                    console.error('Could not get the JWT.');
                }
            });
        },
        initIris: function(jwt){
            var self = this;
            if(window.Iris && window.RTS && window.PUBSUBio){
              this.iris = new Iris({
                jwt: jwt,
                live: true,
                onNotification: function(data){
                    if (!data.msg) { return; }
                    data = JSON.parse(JSON.parse(data.msg).payload);
                    if (data.notification_type == 'todo_reminder') { return; }
                    if (!!data.system) { return; }

                    if (!data.extra) { return; }
                    data.extra = JSON.parse(data.extra);
                    var actionObj = self.flattenNotificationObject(data);

                    actionObj.defaultValue = ''; // When I18n translation is missing.
                    var action = I18n.t('user_notifications.' + data.action, actionObj);
                    var actionType = I18n.t('user_notifications.types.' + data.action, actionObj);
                    var actorText = '';
                    if(data.actor.length) actorText = data.actor + '&nbsp;';
                    var notification = {
                        content: '<b>' + actorText + '</b>' + action,
                        content_text: data.actor + ' ' + action.replace(/<[^>]*>/g, ''),
                        created_at: data.extra.action_date || data.created_at,
                        notification_type: actionType,
                        unreadIds: data.id + '',
                        action_url: data.extra.action_url,
                        actor_text: data.actor,
                        actor_id: data.extra.actor_id
                    };

                    // When we get the first notification - [FRESHCHAT-550]
                    $('.no-notification-message').remove();

                    self.allNotifications.unshift(notification);
                    self.groupedNotifications.push(notification);
                    self.renderOneNotification(notification);
                    self.setSeenIndicator(false);
                    self.readAllButtonCheck();

                    // Generate the desktop notification
                    self.notify(data.id, notification);

                    if(data.notification_type === 'discussion') {
                        var collabEvent = new CustomEvent('collabNoti', {
                            detail: {
                                ticket_id: data.extra.ticket_id,
                                noti_id: data.id
                            }
                        });
                        document.dispatchEvent(collabEvent);
                    }
                }
              });
            }
        },
        seenAll: function(){
            var self = this;
            if($('#user-notification-icon').hasClass('unseen') && this.iris){
                this.iris.seenAll(function(){ self.setSeenIndicator(true); });
            }
        },
        setSeenIndicator: function(bool){
            if(bool){
                $('#user-notification-icon').removeClass('unseen');
            } else {
                $('#user-notification-icon').addClass('unseen');
            }
        },
        fetchCounts: function() {
            var self = this;
            if(this.iris) {
                this.iris.fetchCounts(function(err, result) {
                    if(result.unseen > 0) self.setSeenIndicator(false);
                });
            }
        },
        fetchNotifications: function(numResults, next, done){
            var self = this;
            var fnName = next ? 'fetchNextNotifications' : 'fetchNotifications';

            if(this.iris){
                this.iris[fnName](numResults, function(err, result){
                    result.notifications = result.notifications.filter(function(x) { 
                        return x.notification_type != 'todo_reminder'
                    });
                    if(self.firstFetch){
                        self.firstFetch = false;
                        self.allNotifications = [];
                        self.notifications = [];
                        self.groupedNotifications = [];
                    }
                    if(!err && result &&result.notifications&& result.notifications.length){
                        self.allNotifications = self.allNotifications.concat(result.notifications);
                        self.notifications = result.notifications;
                        self.next_page = !!result.next_page;
                    }

                    self.renderNotifications();
                    if(done) done();
                });
            }
        },
        fetchUserPreferences: function(done){
            if(!this.iris){ return done('Iris not found.'); }
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
            if(!this.iris){ return done('Iris not found.'); }
            this.iris.setUserPreference(pref, done);
        },
        bindDocumentClick: function () {
            var self = this;
            $(document).on('click.usernotification', function (ev) {
                var parentCheck = $(ev.target).parents('#user-notifications-popover');
                if (!parentCheck.get(0)) {
                    $('#user-notifications-popover').addClass('hide');
                    self.unbindScroll();
                }
            });
        },
        bindNotification: function () {
            var self = this;
            $(document).on('click.usernotification', '#user-notification-icon', function(ev){
                ev.stopPropagation();
                $('#user-notifications-popover').toggleClass('hide');
                if(!$('#user-notifications-popover').hasClass('hide')){
                    self.bindScroll();
                    self.seenAll();
                }

                if(self.firstFetch) {
                    self.fetchNotifications(self.numResultsToFetch);
                }
            });
        },
        bindReadAll: function () {
            var self = this;
            $(document).on('click.usernotification', '.user-notifications-read-all', function(ev){
                ev.preventDefault();
                ev.stopPropagation();
                if(self.iris){
                    self.iris.readAll(function(err){
                        if(!err){
                            $('#user-notifications-popover .notifications-list a').removeClass('unread').addClass('read').data('unreadIds', '');
                            self.readAllButtonCheck();
                        }
                    });
                }
                self.seenAll();
            });
        },
        markNotificationRead: function(elem) {
            var self = this;
            if(elem.hasClass('unread') && !!elem.data('unreadIds')){
                var unreadIds = elem.data('unreadIds');
                unreadIds = (typeof unreadIds === 'number') ? [unreadIds + ''] : unreadIds.split(',');
                if(self.iris){
                    self.iris.readNotification(unreadIds, function(){
                        elem.addClass('read').removeClass('unread');
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
                pjaxify(elem.attr('href'));
            });
        },
        bindLoadMoreNotifications: function(){
            var self = this;
            var notifList = $('.notifications-list');
            $(document).on('click.usernotification', '#load-more-notifications', function(ev){
                ev.stopPropagation();
                $('#load-more-notifications').addClass('loading');
                var curScrollTop = notifList[0].scrollTop;
                // Load more notifications
                self.fetchNotifications(self.numResultsToFetch, true, function(){
                    // Remove the spinner
                    notifList.animate({ scrollTop: curScrollTop + 300 }, 1000);
                    $('#load-more-notifications').removeClass('loading');
                });
            });
        },
        bindScroll: function(){
            // Making sure we don't duplicate the bindings.
            this.unbindScroll();
            $(document).on('mousewheel.usernotification', '.notifications-list-wrapper', function(e, d) {
                var notifList = $('.notifications-list-wrapper');
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
            $(document).on('click.usernotification', '.show-user-prefs', function(){
                $('.unp-list').addClass('hide');
                $('.unp-prefs').removeClass('hide');
                self.onPrefsShow();
            });
        },
        bindShowNotificationsClick: function(){
            $(document).on('click.usernotification', '.show-user-notifications', function(){
                $('.unp-list').removeClass('hide');
                $('.unp-prefs').addClass('hide');
            });
        },
        bindPrefClick: function(){
            var self = this;
            $(document).on('click.usernotification', '.notif-pref-item a', function(){
                var elem = $(this);
                var isEnabled = elem.hasClass('enabled');
                var ntype = elem.data('ntype');
                var pipe = elem.data('pipe');
                self.setUserPreference({
                    notification_type: ntype,
                    pipe: pipe,
                    enabled: !isEnabled
                }, function(err){
                    if(!err){
                        if(isEnabled) {
                            elem.removeClass('enabled');
                        } else {
                            elem.addClass('enabled');
                        }
                        self.preferences[ntype][pipe] = !isEnabled;
                    } else {
                        console.error('Could not set user preferece.', err);
                    }
                });
            });
        },
        bindEnableDesktopNotifications: function(){
            var self = this;
            // Let's check if the browser supports notifications
            if(!('Notification' in window) || Notification.permission === 'granted'){
                self.desktopNotificationBtnMsg('granted');
                return;
            }

            if(Notification.permission === 'denied'){
                // TODO: Handle this case by publishing a solution article and linking that here.
            }

            $(document).on('click.usernotification', '.enable-desktop-notifications-button', function(){
                self.askNotificationPermission();
                self.desktopNotificationBtnMsg('help');
            });
        },
        bindMuteChange: function() {
            var self = this;

            if(localStorage.getItem('irisMuteState') === 'true' || false) {
                this.muteState = true;
                $('#mute_notification_sound').siblings('.toggle-button').addClass('active');
                $('#mute_notification_sound').prop('checked', this.muteState);
            }

            $(document).on('change.usernotification', '#mute_notification_sound', function(){
                self.muteState = this.checked;
                localStorage.setItem('irisMuteState', self.muteState);
            });
        },
        hideLoadMoreButton: function(){
            $('#load-more-notifications').addClass('hide');
        },
        showLoadMoreButton: function(){
            $('#load-more-notifications').removeClass('hide');
        },
        getGroupedNotifications: function(){
            var collapsed = {};
            var n;
            for (var i = 0; i < this.notifications.length; i++) {
                n = this.notifications[i];
                n.extra = JSON.parse(n.extra);
                n.extra.collapse_key = n.extra.collapse_key || new Date().getTime() + '' + i;
                collapsed[n.extra.collapse_key] = collapsed[n.extra.collapse_key] || { nArray: [], unreadIds: [], actor_ids: [], actor_names: [] };
                var cObj = collapsed[n.extra.collapse_key];

                cObj.nArray.push(n);

                // For unread notifications
                if(!n.read_at) { cObj.unreadIds.push(n.id); }

                // For multiple actors
                if(cObj.actor_ids.indexOf(n.extra.actor_id) === -1) {
                    cObj.actor_names.push(n.actor);
                    cObj.actor_ids.push(n.extra.actor_id);
                }

                // Set the seen indicator
                if(!n.seen_at) this.setSeenIndicator(false);
            }

            for(var key in collapsed){
                var actor_text = '';
                var action_text = '';
                var ngroup = collapsed[key].nArray;
                var actors = collapsed[key].actor_names;
                var last = ngroup[0];
                var oldest = ngroup[0];

                for (var j = ngroup.length - 1; j >= 0; j--) {
                    n = ngroup[j];
                    if(!n.read_at){
                        var created = n.extra.action_date || n.created_at;
                        var oldestCreated = oldest.extra.action_date || oldest.created_at;
                        var isOlder = new Date(created) < new Date(oldestCreated);
                        if(isOlder) oldest = n;
                    }
                }

                actors[0] = this.safe(actors[0]);
                if(actors.length === 1){
                    if(actors[0].length) actor_text = actors[0] + '&nbsp;';
                } else if(actors.length === 2){
                    actors[1] = this.safe(actors[1]);
                    actor_text = I18n.t('user_notifications.actor_text_2', {
                        actor_name_1: actors[0],
                        actor_name_2: actors[1],
                        defaultValue: ''
                    });
                } else {
                    actor_text = I18n.t('user_notifications.actor_text_multi', {
                        actor_name_1: actors[0],
                        more_actors_count: actors.length - 1,
                        defaultValue: ''
                    });
                }

                var actionObj = this.flattenNotificationObject(last);
                actionObj.defaultValue = '';
                var action = 'user_notifications.' + last.action;
                var actionType = I18n.t('user_notifications.types.' + last.action, actionObj);
                if(ngroup.length > 1){
                    actionObj.count = ngroup.length;
                    action_text = I18n.t(action + '_multi', actionObj);
                } else {
                    action_text = I18n.t(action, actionObj);
                }

                this.groupedNotifications.push({
                    content: '<b>' + actor_text + '</b>' + action_text,
                    content_text: actor_text + ' ' + action.replace(/<[^>]*>/g, ''),
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
            if(this.allNotifications.length === 0){
                $('.notifications-list').html("<a class='read no-notification-message'>" + I18n.t('collaboration.no_notifications') + ".</a>");
            } else {
                $('.notifications-list').html('');
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
            $(nItem).prependTo('#user-notifications-popover .notifications-list');
        },
        readAllButtonCheck: function(){
            if(!$('#wrap #user-notifications-popover .notifications-list .unread').length){
                $('.user-notifications-read-all').addClass('hide');
            } else {
                $('.user-notifications-read-all').removeClass('hide');
            }
        },
        flattenNotificationObject: function(notification){
            var obj = {};
            var self = this;

            // Copy object
            for(var key in notification){
                if(key !== 'extra'){
                    obj[key] = self.safe(notification[key]);
                }
            }

            if(!notification.extra){
                return obj;
            }

            if(typeof notification.extra === 'string'){
                obj.extra = JSON.parse(notification.extra);
            }

            for(var key2 in notification.extra){
                obj[key2] = self.safe(notification.extra[key2]);
            }

            // Truncate the subject if it exists
            if(obj.object.length > 70) {
                obj.object = obj.object.substr(0, 67) + '...';
            }

            return obj;
        },
        onPrefsShow: function(){
            var self = this;
            // Check if preferences object exists, else fetch it
            if(!this.preferences){
                this.fetchUserPreferences(function(err, prefs){
                    if(!err){
                        self.mapUserPrefs(prefs);
                        self.renderPrefs();
                        $('.notifications-preferences loader').addClass('hide');
                    } else {
                        console.error('Could not fetch user preferences');
                    }
                });
            } else {
                self.renderPrefs();
                $('.notifications-preferences loader').addClass('hide');
            }
        },
        mapUserPrefs: function(prefs){
            var self = this;
            // Given an array of prefs, creates the appropriate preference object.
            self.preferences = {};
            for(var i = prefs.length - 1; i >= 0; i--){
                var p = prefs[i];
                self.preferences[p.notification_type] = self.preferences[p.notification_type] || {};
                if(p.pipe === 'android' || p.pipe === 'ios') p.pipe = 'mobile';
                self.preferences[p.notification_type][p.pipe] = p.enabled;
            }
        },
        renderPrefs: function(){
            // See which ones need to be disabled
            for(var ntype in this.preferences){
                var pref = this.preferences[ntype];
                for(var pipe in pref){
                    if(!pref[pipe]){
                        $('.notif-pref-item .npa-' + pipe + '[data-ntype=' + ntype + ']').removeClass('enabled');
                    } else {
                        $('.notif-pref-item .npa-' + pipe + '[data-ntype=' + ntype + ']').addClass('enabled');
                    }
                }
            }

            $('.notifications-preferences .loader').addClass('hide');
        },
        notify: function(id, notification){
            var self = this;
            var muteState = localStorage.getItem('irisMuteState') === 'true' || false
            if(!muteState && localStorage.getItem('activeIrisTab') === this.tabId){
                // Play the notification sound
                $('.user-notification-sound')[0].play();
            }

            if(muteState !== this.muteState){
                this.muteState = muteState;
                $('#mute_notification_sound').prop('checked', this.muteState);
                if(muteState){
                    $('#mute_notification_sound').siblings('.toggle-button').addClass('active');
                } else {
                    $('#mute_notification_sound').siblings('.toggle-button').removeClass('active');
                }
            }

            // Let's check if the browser supports notifications
            if (!('Notification' in window)) {
                console.log('This browser does not support desktop notification');
            } else if (Notification.permission === 'granted') {
                // If it's okay let's create a notification
                var n = new Notification(notification.notification_type, {
                    icon: '/images/misc/admin-logo.png',
                    body: notification.content_text,
                    data: { url: notification.action_url },
                    tag: id
                });
                n.onclick = function(event){
                    event.preventDefault();
                    window.open(event.currentTarget.data.url, '_blank');
                    self.iris.readNotification([id], function(){});
                    event.currentTarget.close();
                };
            }
        },
        askNotificationPermission: function(){
            var self = this;
            Notification.requestPermission(function(permission){
                self.desktopNotificationBtnMsg(permission);
            });
        },
        desktopNotificationBtnMsg: function(msg){
            $('.enable-desktop-notifications-button span').addClass('hide');
            $('.enable-desktop-notifications-button span.' + msg).removeClass('hide');
            if(msg === 'default') {
                $('.enable-desktop-notifications-button').removeClass('disabled');
            } else {
                $('.enable-desktop-notifications-button').addClass('disabled');
            }
        },
        identifyTab: function(){
            var self = this;
            function s4() {
                return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
            }
            this.tabId = s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4();
            this.identifyInterval = setInterval(function(){
                localStorage.setItem('activeIrisTab', self.tabId);
            }, 3000);
        },
        safe: function(str){
            return escapeHtml(str);
        },
        destroy: function () {
            $(document).off('.usernotification');
            clearInterval(this.identifyInterval);
        }
    };
}(window.jQuery));
