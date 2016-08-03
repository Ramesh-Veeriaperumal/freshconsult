! function ($) {
    var message_utilities = (function () {
        var current_user = '';
        var current_user_id = '';
        var agents = {
            viewing: [],
            replying: []
        };
        var tickets = {};
        var updated_tickets = [];

        var setInstanceVariables = function (user, id) {
            if (user) {
                current_user = user;
            }
            current_user_id = id;
        };

        var getAgents = function () {
            return agents;
        }

        var humanize_name_list = function (data, action) {
            var text = '';
            if(data.length >0){
                var _data = {
                        userId:data[0].userId,
                        name:data[0].name,
                        length:data.length,
                        action:action,
                        chatAvailable:(window.freshchat && window.freshchat.chatIcon)? window.freshchat.chatIcon:false
                 };
                text = JST["agent_collision"](_data);
                window.agentCollisionData = data;
            }
            return text;
        };

        var removeUnwantedData = function (message) {
            for (var i = 0; i < message.data.length; i++) {
                var element = message.data[i];
                for (var j = i + 1; j < message.data.length; j++) {
                    if (j != i) {
                        if (element.userId.toString() === message.data[j].userId.toString()) {
                            if ((element.reply) && (element.reply === 'true')) {
                                message.data.splice(j, 1);
                            } else if ((message.data[j].reply) && (message.data[j].reply === 'true')) {
                                message.data.splice(i, 1);
                                i = i - 1;
                            }
                        }
                    }
                }
            }
            return message;
        }

        var checkUniq = function (myArray, obj, type, otherOption) {
            var found = false;
            var otherArrayFound = false;
            if ((unescapeHtml(obj.name.toString()) === unescapeHtml(current_user)) && (obj.userId.toString() === current_user_id.toString())) {
                return false;
            }
            for (var i = 0; i < myArray.length; i++) {
                if ((obj.name.toString() === myArray[i].name.toString()) && (obj.userId.toString() === myArray[i].userId.toString())) {
                    found = true;
                }
            }
            if (otherOption && (!found)) {
                if (obj) {
                    for (var i = 0; i < otherOption.length; i++) {
                        if ((obj.name.toString() === otherOption[i].name.toString()) && (obj.userId.toString() === otherOption[i].userId.toString())) {
                            found = true;
                            if (type == 'replying') {
                                myArray = otherOption;
                            }
                        }
                    }
                }
            }
            if (!found) {
                myArray.push(obj);
            }
        };

        var update_notification_ui_ticket = function (agent) {
            jQuery("#agents_viewing").toggleClass("active", (agents.viewing.length != 0)).effect("highlight", {
                color: "#fffff3"
            }, 400);
            jQuery("#agents_viewing .flip-back").html(agents.viewing.length);
            jQuery("#agents_replying").toggleClass("active", (agents.replying.length != 0)).effect("highlight", {
                color: "#fffff3"
            }, 400);
            jQuery("#agents_replying .flip-back").html(agents.replying.length);
            jQuery(".list_agents_replying").toggleClass("hide", (agents.replying.length == 0)).html(humanize_name_list(agents.replying, 'replying'));
        };

        var update_viewing_notification_ui = function (key, viewing) {
            if (viewing.length == 0) {
                jQuery('[data-ticket-id="' + key + '"]').removeClass('view_collision').find("span[rel=viewing_agents_tip]").html("");
                jQuery('[data-ticket-id="' + key + '"]').find("span[rel=viewing_count]").html('');
            } else {
                jQuery('[data-ticket-id="' + key + '"]').addClass('view_collision').find("span[rel=viewing_agents_tip]").html(humanize_name_list(viewing, 'viewing'));
                jQuery('[data-ticket-id="' + key + '"]').addClass('view_collision').find("span[rel=viewing_count]").html(viewing.length);
            }
            updateToolTipIndex(key, 'viewing', humanize_name_list(viewing, 'viewing'));
        }


        var update_replying_notification_ui = function (key, replying) {
            if (replying.length == 0) {
                jQuery('[data-ticket-id="' + key + '"]').removeClass('reply_collision').find("span[rel=replying_agents_tip]").html("");
                jQuery('[data-ticket-id="' + key + '"]').find("span[rel=replying_count]").html("");
            } else {
                jQuery('[data-ticket-id="' + key + '"]').addClass('reply_collision').find("span[rel=replying_agents_tip]").html(humanize_name_list(replying, 'replying'));
                jQuery('[data-ticket-id="' + key + '"]').addClass('reply_collision').find("span[rel=replying_count]").html(replying.length);
            }
            updateToolTipIndex(key, 'replying', humanize_name_list(replying, 'replying'));
        }

        var updateToolTipIndex = function (ticket_id, type, value) {
            if (jQuery('#working_agents_' + ticket_id).length == 0) {
                working_agents = jQuery('<div class="working-agents" id="working_agents_' + ticket_id + '" />');
                jQuery(working_agents).append(jQuery('<div rel="viewing_agents" class="hide symbols-ac-viewingon-listview" />'));
                jQuery(working_agents).append(jQuery('<div rel="replying_agents" class="hide symbols-ac-replyon-listview" />'));
                var container;
                if (jQuery('#ui-tooltip-' + ticket_id).length > 0) {
                    container = jQuery('#ui-tooltip-' + ticket_id);
                } else {
                    container = jQuery('#agent_collision_container');
                }
                container.append(working_agents);
            }
            working_agents = jQuery('#working_agents_' + ticket_id);
            var collision_dom = jQuery('[data-ticket-id="' + ticket_id + '"]')
            if (type == "viewing") {
                viewing_agents = jQuery(working_agents).find("[rel=viewing_agents]");
                if (collision_dom.find("[rel=viewing_agents_tip]").html() != '') {
                    jQuery('#ui-tooltip-' + ticket_id).addClass('hasViewers');
                    viewing_agents.removeClass('hide');
                    jQuery('#working_agents_' + ticket_id).show();
                } else {
                    jQuery('#ui-tooltip-' + ticket_id).removeClass('hasViewers');
                    viewing_agents.addClass('hide');
                }
                viewing_agents.html(collision_dom.find("[rel=viewing_agents_tip]").html());

            } else if (type == "replying") {
                replying_agents = jQuery(working_agents).find("[rel=replying_agents]");
                if (collision_dom.find("[rel=replying_agents_tip]").html() != '') {
                    jQuery('#ui-tooltip-' + ticket_id).addClass('hasReplying');
                    replying_agents.removeClass('hide');
                    jQuery('#working_agents_' + ticket_id).show();
                } else {
                    jQuery('#ui-tooltip-' + ticket_id).removeClass('hasReplying');
                    replying_agents.addClass('hide');
                }
                replying_agents.html(collision_dom.find("[rel=replying_agents_tip]").html());

            }

        }

        var collisionMessageHandlerShow = function (message) {
            agents.replying = [];
            agents.viewing = [];
            var client_list = message.data;
            if(!((typeof message.data == 'string' || message.data instanceof String))){
                client_list = removeUnwantedData.call(this, message).data;
                if(client_list.length == 1){
                    window.FreshdeskNode.clearPolling();
                }
                else if(client_list.length > 1 ){
                    if(!window.FreshdeskNode.getValue('interval')){
                        window.FreshdeskNode.initPolling();
                    }
                }
                for (var i = 0; i < client_list.length; i++) {
                    if(client_list[i]){
                        if ((client_list[i].reply) && (client_list[i].reply == 'true')) {
                            checkUniq(agents.replying, client_list[i], 'viewing', agents.viewing);
                        } else if ((client_list[i].view) && (client_list[i].view == 'true')) {
                            checkUniq(agents.viewing, client_list[i], 'replying', agents.replying);
                        }
                    }
                }
                update_notification_ui_ticket(agents);
            }
        };

        var collisionMessageHandlerIndex = function (message) {
            var ticketId_array = message.channel.toString().split('/');
            var ticketId = ticketId_array[ticketId_array.length - 1];
            message = removeUnwantedData(message);
            if (!tickets[ticketId]) {
                tickets[ticketId] = {
                    agents: {
                        viewing: [],
                        replying: []
                    }
                };
            }
            tickets[ticketId].agents.viewing = [];
            tickets[ticketId].agents.replying = [];
            for (var i = 0; i < message.data.length; i++) {
                if(message.data[i]){
                    if ((message.data[i].reply) && (message.data[i].reply == 'true')) {
                        checkUniq(tickets[ticketId].agents.replying, message.data[i], 'viewing', tickets[ticketId].agents.viewing);
                    } else if ((message.data[i].view) && (message.data[i].view == 'true')) {
                        checkUniq(tickets[ticketId].agents.viewing, message.data[i], 'replying', tickets[ticketId].agents.replying);
                    }
                }
            }
            update_viewing_notification_ui(ticketId, tickets[ticketId].agents.viewing);
            update_replying_notification_ui(ticketId, tickets[ticketId].agents.replying);
        }
        var get_due_by_value = function (time) {
            switch (true) {
            case time < 0:
                return '1';
            case time < 8 && time > 0:
                return '4';
            case time < 24 && time > 8:
                return '2';
            case time < 48 && time > 48:
                return '3';
            }
        };
        var show_refresh_alert = function (ticket_id, type) {
            if (type == "new") {
                window.FreshdeskNode.getValue('faye_realtime').new_ticket_ids.push(ticket_id);
                update_counter("#new_ticket_message", window.FreshdeskNode.getValue('faye_realtime').new_ticket_ids.length);
            }

            if (type == "update") {
                if (window.FreshdeskNode.getValue('faye_realtime').updated_ticket_ids.indexOf(ticket_id) < 0) window.FreshdeskNode.getValue('faye_realtime').updated_ticket_ids.push(ticket_id);
                update_counter("#update_message", window.FreshdeskNode.getValue('faye_realtime').updated_ticket_ids.length);
            }

            $("#index_refresh_alert").slideDown(100);
            flash_ticket(ticket_id);
        };
        var update_counter = function (id, count) {
            $this = $(id);
            $this.text((count > 1) ? $this.data("textOther") : $this.data("textOne"))
                .attr("data-count", count)
                .show();
        };
        var flash_ticket = function (ticket_id) {
            if (jQuery("[data-ticket=" + ticket_id + "]")) {
                jQuery("[data-ticket=" + ticket_id + "] .status-source").addClass('source-detailed-auto-refresh');
                jQuery("[data-ticket=" + ticket_id + "] .status-source").attr("title", ticketUpdateTitle);
                updated_tickets.push("[data-ticket=" + ticket_id + "] td");
            }
        };
        var refreshCallBack = function (message) {
            var filter_options = JSON.parse(jQuery("input[name=data_hash]").val());
            var count = 0;

            if (jQuery("[data-ticket=" + message.ticket_id + "]").length != 0) {
                show_refresh_alert(message.ticket_id, message.type);
            } else if (filter_options.length != 0) {
                for (var i = 0; i < filter_options.length; i++) {
                    if ((filter_options[i].condition != "due_by") &&
                        (filter_options[i].condition != "created_at") &&
                        (filter_options[i].ff_name == "default")) {
                        if (filter_options[i].condition == "responder_id") {
                            if ((filter_options[i].value.split(',')).indexOf('0') >= 0) {
                                filter_options[i].value += "," + current_user_id;
                            }
                        }
                        if ((filter_options[i].value.split(',')).indexOf(message[filter_options[i].condition] + '') >= 0) {
                            count++;
                        }
                    } else if ((filter_options[i].ff_name != "default")) {
                        if ((filter_options[i].value.split(',')).indexOf(message[filter_options[i].ff_name] + '') >= 0) {
                            count++;
                        }
                    } else {
                        switch (filter_options[i].condition) {
                        case "due_by":
                            var time = message[filter_options[i].condition];
                            if ((filter_options[i].value.split(',')).indexOf(get_due_by_value(time)) >= 0) {
                                count++;
                            }
                            break;
                        case "created_at":
                            var created_at = Date.parse(message[filter_options[i].condition]);
                            var created_at_filter = filter_options[i].value;
                            if (!isNaN(created_at_filter)) {
                                if (((Date.now() - created_at) / 60000) < ((filter_options[i].value) - '')) {
                                    count++;
                                }
                            } else {
                                if (created_at_filter == "yesterday") {
                                    if ((created_at < Date.today()) && (created_at > Date.today().add({
                                        days: -1
                                    }))) {
                                        count++;
                                    }
                                } else if (created_at_filter.split("-").length == 2) {
                                    var date_arr = created_at_filter.split("-");
                                    var start_date = Date.parse(date_arr[0]);
                                    var end_date = Date.parse(date_arr[1]);
                                    if (created_at > start_date && created_at < end_date) {
                                        count++;
                                    }
                                } else {
                                    if (created_at > ticketFilterDateoptions[created_at_filter]) {
                                        count++;
                                    }
                                }
                            }
                            break;
                        }
                    }
                };
                if (count == filter_options.length) {
                    show_refresh_alert(message.ticket_id, message.type);
                }
            } else {
                show_refresh_alert(message.ticket_id, message.type);
            }
        };

        var refreshShowCallBack = function(message){
            if(message.ticket_id == window.FreshdeskNode.getValue('agent_collision_show_data').ticket_id){
                 jQuery('.source-badge-wrap .source').addClass('collision_refresh').attr('title', 'Click here to refresh the ticket');
            }
        }

        return {
            collisionMessageHandlerShow: collisionMessageHandlerShow,
            collisionMessageHandlerIndex: collisionMessageHandlerIndex,
            setInstanceVariables: setInstanceVariables,
            getAgents: getAgents,
            refreshCallBack: refreshCallBack,
            refreshShowCallBack: refreshShowCallBack
        };



    })();

    var faye_utilies = (function (msg_utils) {
        var client = null;
        var setClient = function (opt) {
            client = opt;
        }
        var subscribe = function (channel, callback) {
            var context = msg_utils;
            var subscription = client.subscribe(channel, (callback).bind(context));
            window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions.push(subscription);
            return subscription;
        };
        var then = function (subscription, success_callback, err_callback) {
            if (err_callback) {
                subscription.then(success_callback, err_callback);
            } else {
                subscription.then(success_callback);
            }
        };
        addExtension = function (extension) {
            client.addExtension(extension);
        };
        return {
            addExtension: addExtension,
            then: then,
            subscribe: subscribe,
            setClient: setClient
        };
    })(message_utilities);

    var FreshdeskNode = (function (faye_utils, msg_utils) {
        var opts = {
            retry: 10,
            timeout: 120
        };
        var initial_opts = null;
        var channels = null;
        var common_variables = {
            faye_auth_params: null,
            agent_names: null,
            faye_server: '',
            current_user_id: '',
            current_user: '',
            auto_refresh_data: null,
            agent_collision_index_data: null,
            agent_collision_show_data: null,
            channel_obj: null,
            clients : [],
            interval : null,
            interval_time : 0.1,
            index_interval_time : 0.1,
            index_needed : true,
            needed : true,
            faye_realtime: {
                faye_subscriptions: [],
                fayeClient: null,
                faye_channels: [],
                new_ticket_ids: [],
                updated_ticket_ids: [],
                addChannel: null,
                extension_set: false
            },
            reply_on_load: false
        };

        common_variables.faye_realtime.addChannel = function (channel) {
            if (window.FreshdeskNode.getValue('faye_realtime').faye_channels.indexOf(channel) == -1) {
                window.FreshdeskNode.getValue('faye_realtime').faye_channels.push(channel);
                return true;
            }
            else{
                return false;
            }
        }
        var host = '';
        //utilites
        var extend = function (methods) {
            for (var key in methods) {
                if (methods.hasOwnProperty(key)) {
                    this[key] = methods[key];
                }
            }
            return this;
        };

        var addClient = function (opt) {
            common_variables.clients.push(opt);
        };

        var init = function () {
            for (var i = 0; i < common_variables.clients.length; i++) {
                common_variables.clients[i].init();
            }
        };

        var initPolling = function(){
            if(common_variables.needed){
                for (var i = 0; i < common_variables.clients.length; i++) {
                    try{
                        common_variables.clients[i].setLongPolling(common_variables.interval_time);
                    }
                    catch(e){
                        // console.log('does not have a poller ');
                    }
                }
            }
        }

        var replyOnLoad = function(){
            common_variables.reply_on_load = true;
        }

        var clearReplyOnLoad = function(){
            common_variables.reply_on_load = false;
        }

        var getValue = function (variable) {
            return common_variables[variable];
        };

        var clearClient = function(){
            common_variables.clients = [];
        }



        var setEvents = function () {
            if($.browser.mozilla){
                $(window).on('unload',function(event){
                    console.log("unload change test"); //need to be removed after testing
                     $.ajax({
                      url: window.FreshdeskNode.getValue('faye_server'),
                      timeout: 300,
                      async: 'false',
                      type: "POST",
                      data: {'channels' : window.FreshdeskNode.getValue('faye_realtime').faye_channels , 'clientId' : window.FreshdeskNode.getValue('faye_realtime').fayeClient._clientId, 'domainName' : window.FreshdeskNode.getValue('faye_auth_params').domainName }
                    })
                      .done(function( data ) {
                        // console.log('I am in the ajax');
                      });
                    if (window.FreshdeskNode.getValue('faye_realtime').fayeClient) {
                        for (var i = 0; i < window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions; i++) {
                            window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions[i].cancel();
                        }
                    }
                    if(window.FreshdeskNode.getValue('faye_realtime').fayeClient){
                        window.FreshdeskNode.getValue('faye_realtime').fayeClient.disconnect();
                    }
                });
            }
            else{
                window.addEventListener('beforeunload',function(event){
                    if (window.FreshdeskNode.getValue('faye_realtime').fayeClient) {
                        for (var i = 0; i < window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions; i++) {
                            window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions[i].cancel();
                        }
                    }
                    if(window.FreshdeskNode.getValue('faye_realtime').fayeClient){
                        window.FreshdeskNode.getValue('faye_realtime').fayeClient.disconnect();
                    }
                });
            }
        };

        var setPollingInterval = function(interval){
            common_variables.interval = interval;
        }

        var clearPolling = function(){
            if(common_variables.interval){
                window.clearInterval(common_variables.interval);
                common_variables.interval = null;
            }
        }

        var setPollingInfo = function(interval,needed){
            if(!((common_variables.interval_time == interval) && (common_variables.needed == needed))){
                common_variables.interval_time = interval;
                common_variables.needed = needed;
                clearPolling();
                initPolling();
            }
        }

        var setPollingInfoIndex = function(interval,needed){
            if(!((common_variables.index_interval_time == interval) && (common_variables.needed == needed))){
                common_variables.index_interval_time = interval;
                common_variables.needed = needed;
                clearPolling();
                initPolling();
            }
        }

        var data = function (opts) {
            initial_opts = opts;
            initClient(opts.faye_host, opts.client_opts);
            common_variables.faye_auth_params = opts.faye_auth_params;
            common_variables.current_user_id = opts.current_user_id;
            common_variables.current_user = opts.current_user;
            common_variables.agent_names = opts.agent_names;
            common_variables.faye_server = opts.faye_server;
            if (opts.auto_refresh) {
                addClient(window.AutoRefreshIndex);
                common_variables.auto_refresh_data = opts.auto_refresh
                window.ticketFilterDateoptions = common_variables.auto_refresh_data.ticketFilterDateoptions;
                window.ticketUpdateTitle = common_variables.auto_refresh_data.ticketUpdateTitle;
            }
            if (opts.agent_collision_index) {
                addClient(window.AgentCollisionIndex);
                common_variables.agent_collision_index_data = opts.agent_collision_index;
            }
            if (opts.agent_collision_show) {
                addClient(window.AgentCollisionShow);
                common_variables.agent_collision_show_data = opts.agent_collision_show;
            }
            msg_utils.setInstanceVariables(common_variables.current_user, common_variables.current_user_id);
            return window.FreshdeskNode;
        };

        var initClient = function (client_host, client_opts) {
            host = client_host;
            opts = extend.call(opts, client_opts);
            if (!window.FreshdeskNode.getValue('faye_realtime').fayeClient) {
                window.FreshdeskNode.getValue('faye_realtime').fayeClient = new Faye.Client(host, opts);
            }
            client = window.FreshdeskNode.getValue('faye_realtime').fayeClient;
            faye_utils.setClient(client);
        };

        var addSubscriptions = function () {
            for (var channel in common_variables.channel_obj) {
                var added = window.FreshdeskNode.getValue('faye_realtime').addChannel(channel);
                var subscription = faye_utils.subscribe(channel, common_variables.channel_obj[channel]);
                // faye_utils.then(subscription,function(){console.log('successfull subsction',subscription);},function(err){console.log('The subscription was not successfull',err);})
            }
        };

        var addExtension = function (obj) {
            if (!window.FreshdeskNode.getValue('faye_realtime').extension_set) {
                for (var extension in obj) {
                    var client_extension = {};
                    client_extension[extension] = obj[extension];
                    faye_utils.addExtension(client_extension);
                }
            }
        };

        return {
            addChannels: function (obj) {
                channels = obj
                var extensions = {};
                extensions['outgoing'] = function (message, callback) {
                    message.ext = common_variables.faye_auth_params;
                    message.ext['channel'] = window.FreshdeskNode.getValue('faye_realtime').faye_channels;
                    callback(message);
                };
                extensions['incoming'] = function(message,callback){
                    if((message.interval == 0) || (message.interval == false)){
                         window.FreshdeskNode.setPollingInfo(message.interval,false);
                    }
                    else{
                        window.FreshdeskNode.setPollingInfo(message.interval,true);
                    }
                    if((message.index_interval == 0) || (message.index_interval == false)){
                         window.FreshdeskNode.setPollingInfoIndex(message.index_interval,false);
                    }
                    else{
                        window.FreshdeskNode.setPollingInfoIndex(message.index_interval,true);
                    }
                    callback(message);
                }
                addExtension(extensions)
                setEvents();
                common_variables.channel_obj = obj
                addSubscriptions();
                return window.FreshdeskNode;
            },
            addExtensions: function (obj) {
                if (!window.FreshdeskNode.getValue('faye_realtime').extension_set) {
                    for (var extension in obj) {
                        var client_extension = {};
                        client_extension[extension] = obj[extension];
                        faye_utils.addExtension(client_extension);
                    }
                }
            },
            addSubscriptions: addSubscriptions,
            init: init,
            initClient: initClient,
            addClient: addClient,
            data: data,
            clearClients : clearClient,
            getValue: getValue,
            replyOnLoad: replyOnLoad,
            clearReplyOnLoad: clearReplyOnLoad,
            setPollingInterval: setPollingInterval,
            clearPolling: clearPolling,
            initPolling: initPolling,
            setPollingInfo: setPollingInfo,  
            setPollingInfoIndex: setPollingInfoIndex 
        };
    })(faye_utilies, message_utilities);

    window.FreshdeskNode = FreshdeskNode;

    var AgentCollisionShow = (function (freshdesk_node, msg_utilites, faye_utils) {

        var checkingForCollisionData = function(){
            return freshdesk_node.getValue('agent_collision_show_data')    
        }

        var interval = null;

        var reply_event_interval = function(){
            var data = checkingForCollisionData();
            if(data){
                if(interval){
                    window.clearInterval(interval);
                }
                window.replySubscription = faye_utils.subscribe(freshdesk_node.getValue('agent_collision_show_data').ticket_reply_channel, function (message) {});
                freshdesk_node.getValue('faye_realtime').faye_channels.push(freshdesk_node.getValue('agent_collision_show_data').ticket_reply_channel);
                window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions.push(window.replySubscription);
            }
        }

        var reply_event = function(){
            interval = window.setInterval(reply_event_interval,500);  
        }

        var pollingEvent = function(){
            window.FreshdeskNode.getValue('faye_realtime').fayeClient.publish(freshdesk_node.getValue('agent_collision_show_data').ticket_channel,{data : 'polling' , channel : freshdesk_node.getValue('agent_collision_show_data').ticket_channel , 'domainName' : window.FreshdeskNode.getValue('faye_auth_params').domainName  });
        }

        var setLongPolling = function(interval){
            var interval = window.setInterval(pollingEvent,interval*1000);
            window.FreshdeskNode.setPollingInterval(interval);
        }

        var setEvents = function () {           
            $('[data-note-type]').on("click.agent_collsion",function (e) {
                // window.replySubscription = faye_utils.subscribe(freshdesk_node.getValue('agent_collision_show_data').ticket_reply_channel, function (message) {});
                // window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions.push(window.replySubscription);
            });

            $('.reply_agent_collision').on("click.agent_collsion",function () {
                if (window.replySubscription) {
                    window.replySubscription.cancel();
                }
                window.FreshdeskNode.getValue('faye_realtime').faye_channels.splice(window.FreshdeskNode.getValue('faye_realtime').faye_channels.indexOf(window.FreshdeskNode.getValue('agent_collision_show_data').ticket_reply_channel),1);
                window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions.splice(window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions.indexOf(window.relySubscription), 1);
            });

            $('.link').click(function () {
                if (window.FreshdeskNode.getValue('faye_realtime').fayeClient) {
                    for (var i = 0; i < window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions.length; i++) {
                        window.FreshdeskNode.getValue('faye_realtime').faye_subscriptions[i].cancel();
                    }
                }
                window.FreshdeskNode.getValue('faye_realtime').fayeClient.disconnect();
            });

            $("[rel=notice-popover]")
                .popover({
                html: true,
                trigger: "manual",
                content: function () {
                    container = "";
                    if (this.id != "notification") {
                        agents = msg_utilites.getAgents();
                        agents[$(this).data("object")].each(function (item) {
                            container += "<div>" + item.name + "</div>";
                        });
                    } else {
                        container += "Click to refresh ticket...";
                    }
                    return container;
                },
                template: '<div class="arrow notice-arrow"></div><div class="ticket-notice-popover"><div class="title"></div><div class="content"><p></p></div></div>'
            }).on({
                mouseenter: function () {
                    if ($(this).hasClass("active"))
                        $(this).popover('show');
                },
                mouseleave: function () {
                    $(this).popover('hide');
                }
            });

            $("#notification").bind("click", function (ev) {
                if (jQuery(this).hasClass("active")) {
                    window.location = freshdesk_node.getValue('agent_collision_show_data').helpdesk_ticket_path;
                }
            })

            function update_reload() {
                $('.source-badge-wrap .source').addClass('collision_refresh').attr('title', 'Click here to refresh the ticket');
            }

        };

        var ticketChannelCallback = function (message) {
            this.collisionMessageHandlerShow.call(this, message);
        };

        var viewChannelCallback = function (message) {};

        var init = function () {
            $('#agent_collision_placeholder').append($('#agent_collision_show').detach());
            setEvents();       
        };
        return {
            init: init,
            ticketChannelCallback: ticketChannelCallback,
            viewChannelCallback: viewChannelCallback,
            reply_event: reply_event,
            setLongPolling: setLongPolling
        }
    })(FreshdeskNode, message_utilities, faye_utilies);

    window.AgentCollisionShow = AgentCollisionShow;

    var AgentCollisionIndex = (function (freshdesk_node, msg_utilites, faye_utils) {

        var pollingEvent = function(){
            window.FreshdeskNode.getValue('faye_realtime').fayeClient.publish(freshdesk_node.getValue('agent_collision_index_data').collision_channel,{data : 'index_polling' , channel : freshdesk_node.getValue('agent_collision_index_data').collision_channel , 'domainName' : window.FreshdeskNode.getValue('faye_auth_params').domainName  });
        };

        var setLongPolling = function(interval){
            var interval = window.setInterval(pollingEvent,window.FreshdeskNode.getValue('index_interval_time')*1000);
            window.FreshdeskNode.setPollingInterval(interval);

        };

        var setEvents = function () {
            $('#agent_collision_placeholder').append($('#agent_collision_show').detach());
        };

        var callback = function (message) {
            this.collisionMessageHandlerIndex(message);
        };

        var init = function () {
            setEvents();   
        };
        return {
            init: init,
            callback: callback,
            setLongPolling: setLongPolling
        }
    })(FreshdeskNode, message_utilities, faye_utilies);

    window.AgentCollisionIndex = AgentCollisionIndex;

    var AutoRefreshIndex = (function (freshdesk_node, msg_utilites, faye_utils) {

        var setLongPolling = function(){
            //console.log('can set poller if you want');
        }
        var setEvents = function () {

            $("#index_refresh_alert").bind("click", function (ev) {
                $("#index_refresh_alert").slideUp(100);
                $("#FilterOptions").trigger("change");
                getFilterData();
            });

            $(".filter_item").bind("change", function () {
                $("#index_refresh_alert").slideUp(100);
            });


            $("#SortMenu, .prev_page, .next_page, .toolbar_pagination_full").on("click", function () {
                $("#index_refresh_alert").slideUp(100);
            });
        };


        var callback = function (message) {
            this.refreshCallBack(message);
        };

        var init = function () {
            setEvents();  
        };

        return {
            init: init,
            callback: callback,
            setLongPolling: setLongPolling
        }
    })(FreshdeskNode, message_utilities, faye_utilies);

    window.AutoRefreshIndex = AutoRefreshIndex;

    var AutoRefreshShow = (function (freshdesk_node, msg_utilites, faye_utils) {

        var setLongPolling = function(){
            //console.log('can set poller if you want');
        }
        var setEvents = function () {
            // console.log('I am setting events for auto_refresh show');
        };


        var callback = function (message) {
            this.refreshShowCallBack(message);
        };

        var init = function () {
            setEvents();  
        };

        return {
            init: init,
            callback: callback,
            setLongPolling: setLongPolling
        }
    })(FreshdeskNode, message_utilities, faye_utilies);

    window.AutoRefreshShow = AutoRefreshShow;

}(window.jQuery);