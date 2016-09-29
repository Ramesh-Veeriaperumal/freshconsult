var FreshfoneSocket;
(function ($) {
		"use strict";
	var MAX_RECONNECT_ATTEMPTS = 10,
		reconnectionAttempts = 1,
		reconnectTimeout,
		reconnectFailureDelay = 2*60*1000; // in milliseconds
	FreshfoneSocket = function () {
		this.className = "FreshfoneSocket";
		this.$dashboard = $('.freshfone_dashboard');
		this.$availableAgents = this.$dashboard.find('.live-available-agents');
		this.$liveCalls = this.$dashboard.find('.live-active-calls');
    this.$queuedCalls = this.$dashboard.find('.live-queued-calls');
    this.$busyAgents = this.$dashboard.find('.live-busy-agents');
		this.$dashboardTable = this.$dashboard.find('.freshfone_dash');
		this.$contentContainer = $('.freshfone_content_container');
		this.$freshfoneAvailableAgentsList = this.$contentContainer.find('.ffone_available_agents');
		this.$freshfoneAvailableAgentsListContainer = this.$freshfoneAvailableAgentsList.find('.transfer_call_container');
		this.onlineAgents = 0;
		this.onloadUserarray = [];
      this.onloadGrouparray = [];
    this.onloadexternalNumbersarr= [];
		this.connectionCreatedAt = "";
		this.connectionClosedAt = "";
		this.connection = null;
    this.available_agents= 0;
    this.busyAgents = 0;
    this.activeCalls = 0;
    this.queuedCalls = 0;

//  Intercept emit && listeners to print args
//  self.freshfone_socket_channel_channel.emit = function () {
//    console.log('***', 'emit', Array.prototype.slice.call(arguments));
//    emit.apply(self.dashboard_socket, arguments);
//  };
//  self.freshfone_socket_channel_channel.$emit = function () {
//    console.log('***', 'on', Array.prototype.slice.call(arguments));
//    $emit.apply(self.dashboard_socket, arguments);
//  };
//  Dashboard Socket Initialize
	};
	
	FreshfoneSocket.prototype = {
		init: function (freshfoneuser) {
			var self = this;
			this.freshfoneuser = freshfoneuser;
			this.connect();
      this.bindUnload();
      this.bindTransfer();
    },
    $freshfoneAvailableAgentsListSearch: $('.ffone_available_agents #online-agents-list .search'),
    $freshfoneAvailableAgentsListSearchSpan: $('.ffone_available_agents #search-agents'),
    $noAvailableAgent: $('.ffone_available_agents .no_available_agents'),
    $noAvailableNumbers: $('.ffone_available_agents .no_available_numbers'),
    $availableAgentsList: $('.ffone_available_agents #online-agents-list .list-component'),
    $externalNumbersList: $('.ffone_available_agents #external-numbers-list .list-component'),
    selectedElement: null,
    handleFailure: function () {
    },
  loadDependencies: function(freshfonecalls,fresfoneNetworkError) {
      this.freshfonecalls = freshfonecalls;
      this.freshfoneNetworkError = freshfoneNetworkError;
    },
    disconnect: function () {
      if (this.freshfone_socket_channel === undefined) { return; }
      // this.freshfone_socket_channel.socket.disconnect();
      this.freshfone_socket_channel.io.disconnect();
      // this.freshfone_socket_channel = false;
      this.connectionClosedAt = new Date();
    },
    notify_ignore: function (callId) {
      this.freshfone_socket_channel.emit('ignore', { 
        call_id: callId,
        agent: freshfone.current_user,
        account: freshfone.current_account
      });
    },
    notify_transfer_success: function(params){
      this.freshfone_socket_channel.emit('transfer_success',params);
    },
    connect: function () {
      this.freshfone_socket_channel = freshfone_io.connect(this.freshfone_nodejs_url(), 
                                        {'sync disconnect on unload': false,
                                        'max reconnection attempts': MAX_RECONNECT_ATTEMPTS});
      this.connectionCreatedAt = new Date();

      this.registerCallbacks();
    },
    reconnect: function() {
      this.freshfone_socket_channel.connect();
    },
    freshfone_nodejs_url: function(){
      var query = freshfone.current_user+'&|&'+freshfone.current_account+'&|&'+$.cookie('helpdesk_node_session');
      return freshfone.freshfone_nodejs_url + "?s=" + encodeURIComponent(Base64.encode(query));
    },
    registerCallbacks: function () {
      var self = this;
      this.freshfone_socket_channel.on('connect', function () {
        self.freshfone_socket_channel.emit('init_freshfone_socket', {
        'user' : freshfone.current_user, 
        'account': freshfone.current_account,
        'account_url': freshfone.account_url });
        if (reconnectionAttempts++ >= MAX_RECONNECT_ATTEMPTS) {
          reconnectionAttempts = 1;
          reconnectTimeout = setTimeout(function () { self.freshfone_socket_channel.io.reconnect(); }, reconnectFailureDelay);
        }
        $(window).trigger('ffone.networkUp');//for non-chromium based browsers
      });

			this.freshfone_socket_channel.on('agent_available', function (data) {
				data = JSON.parse(data) || {};
        var result = {
            user: data.user,
            event: "agent_available"
        }
        trigger_event('ffone_socket', result);
				if(data.user.id == freshfone.current_user) {
          self.toggleUserStatus(userStatus.ONLINE);
          return;
        }
				if (data.user) { 
          self.addToAvailableAgents(data.user); 
          ffLogger.logIssue("Freshfone Agent online :: ac_" + freshfone.current_account  + " :: user_" + freshfone.current_user_details.id , {
              user_id: data.user.id,
              user_name: data.user.name
            });
          self.updateAvailableGroups();
          }
			});

				this.freshfone_socket_channel.on('rooms_count', function(data){ 
					ffLogger.tabs_count = data.number_of_rooms;
				});


				this.freshfone_socket_channel.on('agent_unavailable', function (data) {
					data = JSON.parse(data) || {};
		
					if (data.user && data.user.id) { self.removeFromAvailableAgents(data.user.id); }
					if(data.user.id == freshfone.current_user) { self.toggleUserStatus(userStatus.OFFLINE); }
					ffLogger.logIssue("Freshfone Agent Offline :: ac_" + freshfone.current_account  + " :: user_" + freshfone.current_user_details.id, {
						user_id: data.user.id,
						user_name: data.user.name
					});
          self.updateAgentListView();

          var result = {
            user: data.user,
            event: "agent_unavailable"
          }
          trigger_event('ffone_socket', result);
       
				});
				
				this.freshfone_socket_channel.on('agent_busy', function (data) {
					data = JSON.parse(data) || {};
					if (data.user && data.user.id) { self.removeFromAvailableAgents(data.user.id); }
					if(data.user.id == freshfone.current_user) { self.toggleUserStatus(userStatus.BUSY); }
          self.updateAgentListView();
          var result = {
            user: data.user,
            event: "agent_busy"
          }
          trigger_event('ffone_socket', result);
				}); 

				this.freshfone_socket_channel.on('agent_in_acw_state', function (data){
					data = JSON.parse(data) || {};
					if(data.user.id == freshfone.current_user){
						self.toggleUserStatus(userStatus.ACW);
					}
					self.updateAgentListView();
					var result = {
						user: data.user,
						event: "agent_in_acw_state"
					}
					trigger_event('ffone_socket', result);
				}); 

			this.freshfone_socket_channel.on('credit_change', function (data) {
				(data === 'enable') ? freshfonewidget.enableFreshfoneWidget() : 
															freshfonewidget.disableFreshfoneWidget();
					
			});

      this.freshfone_socket_channel.on('toggle_device', function (data) {
        data = JSON.parse(data) || {};
         var result = {
            user: data.user,
            event: "toggle_device"
          }
          trigger_event('ffone_socket', result);
          if(data.user.id == freshfone.current_user){
            self.togglePhone(data.user.on_phone);
          }
      });

			this.freshfone_socket_channel.on('token', function (data) {
				data = JSON.parse(data) || {};
				self.updataTwilioDevice(data.token);
			});

			this.freshfone_socket_channel.on('get_calls_agents_status', function () {
				if(self.$dashboard.length || $('#freshfone_calls_dashboard').length){
					self.getAvailableAgents();
				}
			});

			this.freshfone_socket_channel.on('message', function (data) {
				data = JSON.parse(data);
				switch (data.type) {
				case 'total_agents_available':
					self.totalAgents = data.members;
					break;
				case 'new_call':
            self.incrementBusyAgentsCount();
            break;
				case 'completed_call':
              self.decrementBusyAgentsCount();
            break;
        case 'queued_call':
            self.incrementQueuedCallsCount();
            $("#freshfone_dashboard_events").trigger(data.type, data);
            break;
        case 'dequeued_call':
            self.decrementQueuedCallsCount();
            $("#freshfone_dashboard_events").trigger(data.type, data);
            break;
        case 'new_active_call':
            self.incrementActiveCallsCount();
            $("#freshfone_dashboard_events").trigger(data.type, data);
            break;
        case 'active_call_end':
            self.decrementActiveCallsCount();
            $("#freshfone_dashboard_events").trigger(data.type, data);
            break;
        case 'disable_supervisor_call':
        case 'enable_supervisor_call':
            if(data.call_details.user_id != freshfone.current_user)
            {
              $("#freshfone_dashboard_events").trigger(data.type, data);
            }
            break;
				}
        self.tryUpdateDashboard();
			});

			this.freshfone_socket_channel.on('connect_failed', function () {
				self.handleFailure();
			});

			this.freshfone_socket_channel.on('error', function () {
				self.handleFailure();
			});  

      this.freshfone_socket_channel.on('disconnect', function() {
        $(window).trigger('ffone.networkDown'); //for non-chromium based browsers
      });

      this.freshfone_socket_channel.on('reconnect',function(){
        $(window).trigger('ffone.networkUp'); // for non-chromium based browsers
      });
			
			this.freshfone_socket_channel.on('CallTransferSuccess', function (data) {
				data = JSON.parse(data);
				self.successTransferCall(data.result);
			});


      //Conference events starts here

      this.freshfone_socket_channel.on('transfer_success', function (data) {
        if(data.agent == freshfone.current_user){
          self.successTransferConferenceCall(data.call_sid);
          //Twilio.Device.disconnect(data);
        }
      });
      this.freshfone_socket_channel.on('transfer_reconnected', function(data){        
        if(data.agent == freshfone.current_user){ self.transferReconnected(); }
      });

      this.freshfone_socket_channel.on('transfer_unanswered', function(data){        
        if(data.agent == freshfone.current_user){ 
          freshfonecalls.freshfoneCallTransfer.enableTransferResume(); }
      });
      
      this.freshfone_socket_channel.on('call_holded', function (data) {
        freshfonecalls.toggleWidgetOnHold(true);
      });

      this.freshfone_socket_channel.on('call_unholded', function (data) {
        freshfonecalls.toggleWidgetOnHold(true);
      });

      this.freshfone_socket_channel.on('agent_conference_success', function(data) {
        if(data.agent == freshfone.current_user) {
          trigger_event('agent_conference', { event: 'success' });
        }
      });

      this.freshfone_socket_channel.on('agent_conference_completed', function(data) {
        if(data.agent == freshfone.current_user) {
          var result = { event: 'complete', status: data.call_status };
          trigger_event('agent_conference', result);
        }
      });

      this.freshfone_socket_channel.on('agent_conference_unanswered', function(data) {
        if(data.agent == freshfone.current_user) {
          trigger_event('agent_conference', { event: 'unanswered'});
        }
      });

      this.freshfone_socket_channel.on('agent_conference_connecting', function(data) {
        if(data.agent == freshfone.current_user) {
          trigger_event('agent_conference', { event: 'connecting' });
        }
      });
      
      this.freshfone_socket_channel.on('update_presence', function(data) {
        if(data.agent == freshfone.current_user) {
          freshfoneuser.updatePresence();
        }
      });

      //Conference events end here

      //Call Notifier events
      this.freshfone_socket_channel.on('incoming', function (data) {
        if(self.deviceWithActiveConnection()){
          var incomingConnection = new IncomingConnection(data, incomingNotification);
          incomingConnection.reject();
        }
        else{
          if(freshfoneuser.isOnline()){
            incomingNotification.notify(data);
          }
          self.freshfone_socket_channel.emit('incoming_ack', data); 
        }   
      });
      this.freshfone_socket_channel.on('transfer', function(data){
        incomingNotification.notify(data);
        self.freshfone_socket_channel.emit('transfer_ack',data);
      });
      this.freshfone_socket_channel.on('warm_transfer', function(data){
        incomingNotification.notify(data);
        self.freshfone_socket_channel.emit('warm_transfer_ack',data);
      });
      this.freshfone_socket_channel.on('ignore', function (data) {
        incomingNotification.removeNotification(data.call_id);
      });

      this.freshfone_socket_channel.on("round_robin", function(data){
        if(freshfoneuser.isOnline()){
          incomingNotification.notify(data);
        }
        self.freshfone_socket_channel.emit('round_robin_ack', data);
      });
      this.freshfone_socket_channel.on('accepted', function (data) {
        var currentConnection = incomingNotification.currentConnection();
        if(currentConnection == undefined) {
          incomingNotification.popOngoingNotification(data.call_id);
        }else{
          incomingNotification.popAllNotification();
        }
      });
      this.freshfone_socket_channel.on('cancelled', function (data) {
        incomingNotification.popOngoingNotification(data.call_id);
        self.freshfone_socket_channel.emit('cancelled_ack', data);
      });

      this.freshfone_socket_channel.on('completed', function (data) {
        incomingNotification.popOngoingNotification(data.call_id);
        self.freshfone_socket_channel.emit('completed_ack', data);
      });

      //Call Notifier events end


			$('body').on('pjaxDone', function() {
				self.$dashboard = $('.freshfone_dashboard');
				self.$availableAgents = self.$dashboard.find('.live-available-agents');
				self.$liveCalls = self.$dashboard.find('.live-active-calls');
        self.$queuedCalls = self.$dashboard.find('.live-queued-calls');
        self.$busyAgents = self.$dashboard.find('.live-busy-agents');
        self.getAgents();
				self.tryUpdateDashboard();
			});

		},
    notifyAccept: function(data){
      this.freshfone_socket_channel.emit('accepted',data); //send accepted to cancel notification in  other tabs
    },
    tryUpdateDashboard: function () {
			if ((this.$availableAgents || 
            this.$liveCalls || 
            this.$queuedCalls) === undefined) { return false; }

			this.$availableAgents.text(this.totalAgents);
			this.$liveCalls.text(this.activeCalls);
      this.$queuedCalls.text(this.queuedCalls);
      this.$busyAgents.text(this.busyAgents);

		},
		onlineUserCount: function () {
			var offset = freshfoneuser.isOnline() ? -1 : 0;
			return (this.totalAgents + offset < 0) ? 0 : 
                (this.totalAgents + offset) || 0 ;
		},
		getAvailableAgents: function () {
      var self = this;
      $.ajax({
        dataType: "json",
        url: '/phone/dashboard/dashboard_stats',
        success: function(data) {
          self.available_agents=data.available_agents;
          self.busyAgents = data.busy_agents;
          self.activeCalls = data.active_calls_count;
          self.queuedCalls = data.queued_calls_count;
          self.populateAvailableAgentsCount();
          self.tryUpdateDashboard();
        }
      });
		},

		populateAvailableAgentsCount: function () {
			freshfonesocket.totalAgents = this.available_agents;
			freshfonesocket.tryUpdateDashboard();
		},

    populateNumberList: function(){
      var options = {
        item: 'numbers-item',
        listClass: 'available_numbers_list',
        valueNames: [ 'available_agents_avatar', 'external_number' ]
      };
      var self = this;
      if(!this.numberList){
        if(this.onloadexternalNumbersarr.length){
          this.numberList = new List('external-numbers-list',options, this.onloadexternalNumbersarr);
        }
        else
        {
          this.numberList = new List('external-numbers-list',options);
          if(!this.$availableAgentsList.is(':visible')){
            this.$noAvailableNumbers.show();
          }
        }
      }
    },
		populateAvailableAgents: function () {
			var options = {
				item: 'agents-item',
				listClass: 'available_agents_list',
				valueNames: [ 'available_agents_name', 'available_agents_avatar' ]
				// page: 10
			}, list;
			freshfonesocket.totalAgents = this.onloadUserarray.length - this.onloadGrouparray.length;
			freshfonesocket.tryUpdateDashboard();

			if (!this.agentList) {
				list = $.grep(this.onloadUserarray, function (user) { return user.id !== freshfone.current_user; });
				if (list.length) {
					this.agentList = new List('online-agents-list', options, list);
				} else {
					this.agentList = new List('online-agents-list', options);
				}
        this.agentList.sort('sortname', { asc: true });
        this.updateAgentListView();
			}
      this.$freshfoneAvailableAgentsListSearch.focus();
			// else {
				// this.agentList.add(this.onloadUserarray); // temporary
			// }
		},

    updateAvailableGroups: function(){
      var self = this;
      var groupArray =[];
      var userArray = [];
      this.$freshfoneAvailableAgentsList.find('span.id').each(function(v,i){  
        var val = jQuery(i).html();
        if(val != undefined && val != ""){ userArray.push(parseInt(val)); }
      });
      userArray = userArray.without(0,freshfone.current_user);

      this.onloadGrouparray.each(function(group) { 
      self.agentList.remove("id",0);
      var agent_ids = userArray.reject(function(id) { 
          return (group.agents_ids.indexOf(id) == -1);
        });
        group.agents_count = agent_ids.length + " " +
              (agent_ids.length > 1 ? freshfone.agents_count : freshfone.agent_count);
        if(agent_ids.length > 0){
          groupArray.push(group);
        }
      });
      groupArray.each(function(grp){
        self.agentList.add(grp);
      }); 
    },
    numberSearch: function(number){
      var searchResult = this.numberList.matchingItems;
      if(number == undefined || number == "" || searchResult.length != 0){
        jQuery('#external_number_label').html("");
        jQuery('#new_external_number').hide();
      }
      else{
        this.selectedElement = null;
        number = "+"+number;
        if(self.freshfonecalls.exceptionalNumberValidation(number)){
          if(!jQuery('#external-number').hasClass('transfer-external-selected')){
            jQuery('#external-number').addClass('transfer-external-selected');
          }
        }else{
          jQuery('#external-number').removeClass('transfer-external-selected');
        }
        jQuery('#external_number_label').html(number);
        jQuery('#new_external_number').show();
      }
    },
		addToAvailableAgents: function (user) {
			if (user.id === freshfone.current_user || this.agentList === undefined) { return false; }
			if (!this.agentList.get("id", user.id)) {
				this.agentList.add(this.formatListItem(user));
        this.agentList.sort('sortname', { asc: true });
        if(!this.$externalNumbersList.is(':visible')){
				  this.noAvailableAgentsToggle();
        }
			}
		},

		removeFromAvailableAgents: function (id) {
			if (id === freshfone.current_user || this.agentList === undefined) { return false; }
			this.agentList.remove("id", id);
      if(!this.$externalNumbersList.is(':visible')){
			 this.noAvailableAgentsToggle();
      }
		},

		removeOfflineAgents: function (ids) {
			var self = this;
			if ( !ids  ) { return false; }
			ids.each (
				function (id) {
					self.onloadUserarray = self.onloadUserarray.reject(function (user) { if(user.id == parseInt(id) ) { return user; } });
				}	
			 );
      if(!this.$externalNumbersList.is(':visible')){
			 this.noAvailableAgentsToggle();
      }
		},
		
		toggleUserStatus: function  (status) {
			freshfoneuser.manageAvailabilityToggle(status);
			freshfoneuser.setStatus(status);
			if (freshfoneuser.isOnlineOrOffline()) {
				freshfoneuser.online = freshfoneuser.isOnline();
			}
			freshfoneuser.userPresenceDomChanges();
		},
		togglePhone: function(availability){
			freshfoneuser.userPresenceDomChanges(availability, true);
		},
		updataTwilioDevice: function (token) {
			if (freshfoneuser.newTokenGenerated) {
				freshfoneuser.newTokenGenerated = !freshfoneuser.newTokenGenerated;
			}else{ 
				freshfoneuser.setupDevice(token);
			}
		},
		noAvailableAgentsToggle: function () {
			var showAgentsList = (this.agentList && this.agentList.items.length) ? true : false;
      this.$noAvailableAgent.toggle(!showAgentsList);
			this.$availableAgentsList.toggle(showAgentsList);
		},
    toggleAgentsView: function(viewClass){
      var removeList = $('#transfer-list').data('list');
      $('#transfer-list .'+removeList).hide();
      $('#transfer-list .'+viewClass).show();
      $('.ffone_available_agents .'+viewClass+' .search').focus();
      $('#transfer-list').data('list',viewClass);
      this.cleanUpLabels();
    },
    cleanUpLabels: function(){
      if(!this.$externalNumbersList.is(':visible')){
        this.noAvailableAgentsToggle();
      }
      $('#new_external_number .external_number_label').html ("");
      $('#new_external_number').hide();
      if(this.selectedElement){
        $(this.selectedElement).removeClass('transfer-active');
        $(this.selectedElement).removeClass('group-transfer');
        this.selectedElement = null;
      }
    },
    bindDropDownMenus: function(){
      var self = this;
       $(document).on('click.freshfonetransfer','#transfer-menu-items li',function(){
        var menu = $('#transfer-icon-menu').data('menu');
        $('#transfer-menu-items .'+menu).removeClass('hide');
        self.toggleAgentsView($(this).attr('class'));

        $('#transfer-icon-menu').data('menu',$(this).attr('class'))
        $(this).addClass('hide');
        $('#transfer-menu-btn').html($(this).html());
      });

      $(document).on('click.freshfonetransfer','#external-number-menu',function(){
        if(self.onloadexternalNumbersarr.length){
          return true; //don't fetch if already fetched.
        }
        self.$externalNumbersList.addClass('sloading');
        $.ajax({
            type: 'GET',
            dataType: "json",
            url: '/freshfone/call_transfer/available_external_numbers',
            success: function (data) {
              self.onloadexternalNumbersarr.push.apply(self.onloadexternalNumbersarr,data);
              self.$externalNumbersList.removeClass('sloading');
              self.populateNumberList();
            },
            error: function(error){
              self.$externalNumbersList.removeClass('sloading');
              console.log('Error fetching external numbers:'+error);
            }
          });
      });
    },
    resetEvents: function(){
      $(document).off('.freshfonetransfer');
    },
    bindUnload: function(){
      $(window).on('unload', function() {
        $('#transfer-list').off('mousewheel.transfer');
      });
    },
    validateSearchInput: function(){
      var self = this;
       $(document).on('keypress.freshfonetransfer','.ffone_available_agents #search-external',function(event){
        var keyVal = String.fromCharCode(event.which);
        var typedVal = $(this).val();
        if(typedVal.length < 15){
          if ((event.which > 47 &&  event.which < 58) || (event.which == 8 || event.which == 46 || event.which == 37 || event.which == 39)
            || (event.ctrlKey && event.which == 86)){
           return true;
          }
        } 
        else if(typedVal.length == 15 && (event.which == 8 || event.which == 46 || event.which == 37 || event.which == 39)){
           return true;
        }
        event.preventDefault();
        return false;
      });

      $(document).on('keyup.freshfonetransfer','.ffone_available_agents #search-external',function(){
        var typedVal = $(this).val();
        self.numberSearch(typedVal.trim());
      });

      $(document).on('click.popup','.popupbox-tabs .transfer_call', function(){ 
        if(self.$externalNumbersList.is(':visible')){
            $('.ffone_available_agents #search-external').focus();
        }
      });

    },
		bindTransfer: function () {
			var self = this;
      
      this.resetEvents();//Turn off all freshfonetransfer events if registered.

      this.bindDropDownMenus();

      this.validateSearchInput();
      this.handleClickTransfers();
      this.bindScrollEvents('available_numbers_list');
      this.bindScrollEvents('available_agents_list');

      this.bindKeyTraversal('external-numbers-list','available_numbers_list','transfer-external-selected transfer-active');
      this.bindMouseEvents();
		},
    bindScrollEvents: function(element, list){
      var self = this;
      $( '.'+element ).on('mousewheel.transfer', function ( ev,delta ) {
        var t = $(this);
        if (self.scrollTopCheck(delta, t.scrollTop()) || 
          self.scrollDownCheck(delta, t.scrollTop(), t.get(0).scrollHeight, t.innerHeight())) {
           ev.preventDefault();
        }
      });
    },
    scrollTopCheck: function(delta,top) {
      return (delta > 0 && top === 0);
    },
    scrollDownCheck: function(delta, top, height, innerHeight) {
      return (delta < 0 && (top == height - innerHeight));
    },
    bindMouseEvents: function(){
      var self = this;

      $('#freshfone_available_agents').on('mouseenter mouseleave',' #online-agents-list ul >li', function(event) {
        self.selectedElement == null;
        self.$freshfoneAvailableAgentsList.find('#online-agents-list li.transfer-active')
                                          .removeClass('transfer-active group-transfer');
        if(event.type == 'mouseenter'){
          $(this).addClass('transfer-active');
          var agent_id = self.$freshfoneAvailableAgentsList.find('#online-agents-list li.transfer-active .id')
                                                           .text();
          if (agent_id == "0") {
            $(this).addClass('group-transfer');
          }
        }
      });

      $('#freshfone_available_agents').on('mouseenter mouseleave','.available_numbers_list li',function(event) {
        self.selectedElement == null;
        $('#freshfone_available_agents .available_numbers_list li.transfer-external-selected').removeClass('transfer-external-selected');
        $('#freshfone_available_agents .available_numbers_list li.transfer-active').removeClass('transfer-active');
        if(event.type == 'mouseenter'){
          $(this).addClass('transfer-external-selected transfer-active');
        }
      });

    },
    bindKeyTraversal:function(searchElem,elem,hoverClass){
      var self = this;
      this.handlePasteEvents();
        $('#'+searchElem+' .search').on('keydown.freshfonetransfer',function(event){
            switch(event.which){
              case 13://enter key
                if(self.selectedElement != undefined && self.selectedElement.length){
                  $(self.selectedElement).trigger('click.freshfonetransfer');
                }
                else if($('#new_external_number').is(':visible')){
                  $('#new_external_number').trigger('click.freshfonetransfer');
                }
                break;
              case 38: //up arrow
                var toselect = $(self.selectedElement).prev();
                var defaultSelect = $('#freshfone_available_agents .'+elem+' li').last();
                self.handleArrowAction(toselect,defaultSelect,hoverClass);
                break;
              case 40://down arrow
                var toselect = $(self.selectedElement).next();
                var defaultSelect = $('#freshfone_available_agents .'+elem+' li').first();
                self.handleArrowAction(toselect,defaultSelect,hoverClass);
                break;
          }
      });
    },
    handleArrowAction: function(toselect,defaultSelect,hoverClass){
      var self = this;
      if(toselect.length){
        if($(self.selectedElement).hasClass(hoverClass)){
          $(self.selectedElement).removeClass(hoverClass);
        }
        self.selectedElement = toselect
        $(self.selectedElement).addClass(hoverClass);
      }
      else{
         $(self.selectedElement).removeClass(hoverClass);
         self.selectedElement = defaultSelect;
         if(!$(self.selectedElement).hasClass(hoverClass)){
          $(self.selectedElement).addClass(hoverClass);
        }
      }
    },
    handlePasteEvents: function(){
      //to handle ctrl+v and mouse right click paste
      $('.ffone_available_agents').on('paste','#search-external',function(event){ 
        var element = this;
        var text = $(element).val();
        setTimeout(function(){
          var number = text.match(/[0-9]/g);
          if(number){
            text = number.join('');
            text = text.substring(0, 12);
          }
          else
          {
            text ='';
          }
          $(element).val(text);
        },0);
      });
    },
    handleClickTransfers: function(){
      var self = this;
      $('#freshfone_available_agents .available_agents_list').on('click.freshfonetransfer',' .transfer', function () {
        var group_id = $(this).parents("li.transfer-active").find('.group_id').html();
        var agent_id = $(this).parents("li.transfer-active").find('.id').html();
        self.freshfonecalls.transferCall(agent_id, group_id);
      });

      $('#freshfone_available_agents .available_agents_list').on('click.freshfonetransfer', '.add_agent', function() {
        var agent_id = $(this).parents("li.transfer-active").find('.id').html();
        self.freshfonecalls.addAgent(agent_id);
      });

      $('#freshfone_available_agents .available_agents_list').on('click.freshfonetransfer',' .warm_transfer', function () {
        var agent_id = $(this).parents("li.transfer-active").find('.id').html();
        self.freshfonecalls.warmTransferCall(agent_id);
      });

      $('#freshfone_available_agents .available_numbers_list').on('click.freshfonetransfer', '.transfer', function () {
          var external_number = $(this).parents("li.transfer-active").find('.external_number').html();
          var id = $(this).parents("li.transfer-active").find('.id').html();
          self.freshfonecalls.transferCall(id, null, external_number);
      });

      $('#freshfone_available_agents').on('click.freshfonetransfer','#new_external_number',function(){
        var external_number = jQuery('#external_number_label').html();
        if(self.freshfonecalls.exceptionalNumberValidation(external_number)){
          self.addToNumberList(external_number);
          self.$noAvailableNumbers.hide();
          self.freshfonecalls.transferCall(external_number, null, external_number);
        }
      });
    },
    addToNumberList: function(number){
      this.numberList.add(this.formatNumberItem(number));
      jQuery('#new_external_number').hide();
      //This is invoked to make listjs apply filter match to added element.
      this.numberList.search(number);
    },
		loadAvailableAgents: function (forceLoading) {
			if (!freshfonesocket.onloadUserarray.length || forceLoading) {
				this.$freshfoneAvailableAgentsList.addClass('loading-small sloading');
				this.$freshfoneAvailableAgentsListContainer.hide();
					$.ajax({
						data: { "existing_users_id": this.onloadUserarray.pluck('id') },
            dataType: "script",
						url : freshfone.transfer_list_path
						// error: function () {
						// 	$recentCalls.removeClass('loading-small sloading');
						// 	$recentCallsContainer.show();
						// }
					});
			}
			else {
				this.populateAvailableAgents();
			}

		},
		successTransferCall: function (transfer_success) {
			freshfonecalls.freshfoneCallTransfer.successTransferCall(transfer_success);
		},
    successTransferConferenceCall: function(call_sid) {
      if(freshfonecalls.isCallActive() && !freshfonecalls.freshfoneCallTransfer.cancelled){
        freshfonecalls.freshfoneCallTransfer.disconnectAgent(call_sid);
        freshfonecalls.freshfoneCallTransfer.successTransferCall('true');
      }
    },
    formatNumberItem: function (number) {
      return {"id":number, "external_number" : number}
    },
		formatListItem: function (user) {
      return {"id":user.id, "available_agents_name" : user.name, "sortname" : "A_"+user.name, "available_agents_avatar": user.avatar }
		},
    transferReconnected: function() {
      freshfonecalls.freshfoneCallTransfer.resetTransferState();
    },
    updateAgentListView: function(){
      this.updateAvailableGroups();
      if(!this.$externalNumbersList.is(':visible')){
        this.noAvailableAgentsToggle();
      }
    },
    incrementBusyAgentsCount: function () { this.busyAgents+=1; },
    incrementQueuedCallsCount: function () { this.queuedCalls+=1; },
    incrementActiveCallsCount: function () { this.activeCalls+=1; },
    decrementBusyAgentsCount: function() { 
      if(this.busyAgents>0) { this.busyAgents-=1; } 
    },
    decrementQueuedCallsCount: function() { 
      if(this.queuedCalls>0) {  this.queuedCalls-=1; }
    },
    decrementActiveCallsCount: function() { 
     if(this.activeCalls>0) {  this.activeCalls-=1; }
    },
    getAgents: function() {
      if(this.$dashboard.length){
          this.getAvailableAgents();
      }
    },
    deviceWithActiveConnection: function(){
      var activeConnection = Twilio.Device.activeConnection();
      return (activeConnection && activeConnection.status()=="open");
    }


	};
}(jQuery));
