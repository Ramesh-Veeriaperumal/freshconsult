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
		this.$liveCalls = this.$dashboard.find('.live-calls');
		this.$dashboardTable = this.$dashboard.find('.freshfone_dash');
		this.$contentContainer = $('.freshfone_content_container');
		this.$freshfoneAvailableAgentsList = this.$contentContainer.find('.ffone_available_agents');
		this.$freshfoneAvailableAgentsListContainer = this.$freshfoneAvailableAgentsList.find('.transfer_call_container');
		this.onlineAgents = 0;
		this.onloadUserarray = [];
     this.onloadGrouparray = [];
		this.connectionCreatedAt = "";
		this.connectionClosedAt = "";
		this.connection = null;

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
			self.registerCallbacks();
      this.freshfone_socket_channel.on('connect', function () {
        self.freshfone_socket_channel.emit('init_freshfone_socket', {
        'user' : freshfone.current_user, 
        'account': freshfone.current_account,
        'account_url': freshfone.account_url });

        if (reconnectionAttempts++ >= MAX_RECONNECT_ATTEMPTS) {
          reconnectionAttempts = 1;
          reconnectTimeout = setTimeout(function () { self.freshfone_socket_channel.socket.reconnect(); }, reconnectFailureDelay);
        }
      });
    },
    $freshfoneAvailableAgentsListSearch: $('.ffone_available_agents .search'),
    $freshfoneAvailableAgentsListSearchSpan: $('.ffone_available_agents #search-agents'),
    $noAvailableAgent: $('.ffone_available_agents .no_available_agents'),
    $availableAgentsList: $('.ffone_available_agents #online-agents-list'),
    handleFailure: function () {
    },
    loadDependencies: function(freshfonecalls) {
      this.freshfonecalls = freshfonecalls;
    },
    disconnect: function () {
      if (this.freshfone_socket_channel === undefined) { return; }
      // this.freshfone_socket_channel.socket.disconnect();
      this.freshfone_socket_channel.io.disconnect();
      // this.freshfone_socket_channel = false;
      this.connectionClosedAt = new Date();
    },
    connect: function () {
      this.freshfone_socket_channel = freshfone_io.connect(this.freshfone_nodejs_url(), 
                                        {'sync disconnect on unload': false,
                                        'max reconnection attempts': MAX_RECONNECT_ATTEMPTS});
      this.connectionCreatedAt = new Date();
    },
    freshfone_nodejs_url: function(){
      var query = freshfone.current_user+'&|&'+freshfone.current_account+'&|&'+$.cookie('helpdesk_node_session');
      return freshfone.freshfone_nodejs_url + "?s=" + encodeURIComponent(Base64.encode(query));
    },
    registerCallbacks: function () {
      var self = this;

			this.freshfone_socket_channel.on('agent_available', function (data) {
				data = JSON.parse(data) || {};
				if(data.user.id == freshfone.current_user) {
          self.toggleUserStatus(userStatus.ONLINE);
          return;
        }
				if (data.user) { self.addToAvailableAgents(data.user); }
			});

				this.freshfone_socket_channel.on('rooms_count', function(data){ 
					ffLogger.tabs_count = data.number_of_rooms;
				});

				this.freshfone_socket_channel.on('agent_available', function (data) {
					data = JSON.parse(data) || {};
					if(data.user.id == freshfone.current_user) { self.toggleUserStatus(userStatus.ONLINE); return;}

					if (data.user) { 
						self.addToAvailableAgents(data.user);
						ffLogger.logIssue("Freshfone Agent online :: ac_" + freshfone.current_account  + " :: user_" + freshfone.current_user_details.id , {
							user_id: data.user.id,
							user_name: data.user.name
						});
            self.updateAvailableGroups();
					}
				});

				this.freshfone_socket_channel.on('agent_unavailable', function (data) {
					data = JSON.parse(data) || {};
		
					if (data.user && data.user.id) { self.removeFromAvailableAgents(data.user.id); }
					if(data.user.id == freshfone.current_user) { self.toggleUserStatus(userStatus.OFFLINE); }
					ffLogger.logIssue("Freshfone Agent Offline :: ac_" + freshfone.current_account  + " :: user_" + freshfone.current_user_details.id, {
						user_id: data.user.id,
						user_name: data.user.name
					});
          self.updateAvailableGroups();
          self.noAvailableAgentsToggle();
				});
				
				this.freshfone_socket_channel.on('agent_busy', function (data) {
					data = JSON.parse(data) || {};
		
					if (data.user && data.user.id) { self.removeFromAvailableAgents(data.user.id); }
					if(data.user.id == freshfone.current_user) { self.toggleUserStatus(userStatus.BUSY); }
				});

			this.freshfone_socket_channel.on('credit_change', function (data) {
				(data === 'enable') ? freshfonewidget.enableFreshfoneWidget() : 
															freshfonewidget.disableFreshfoneWidget();
					
			});

			this.freshfone_socket_channel.on('token', function (data) {
				data = JSON.parse(data) || {};
				self.updataTwilioDevice(data.token);
			});

			this.freshfone_socket_channel.on('get_calls_agents_status', function () {
				self.getAvailableAgents();
			});

			this.freshfone_socket_channel.on('message', function (data) {
				data = JSON.parse(data);
				switch (data.type) {
				case 'total_agents_available':
					self.totalAgents = data.members;
					self.tryUpdateDashboard();
					break;
				case 'new_call':
				case 'completed_call':
					self.activeCalls = data.members;
					self.tryUpdateDashboard();
					break;
				}
			});

			this.freshfone_socket_channel.on('connect_failed', function () {
				self.handleFailure();
			});

			this.freshfone_socket_channel.on('error', function () {
				self.handleFailure();
			});  
			
			this.freshfone_socket_channel.on('CallTreansferSuccess', function (data) {
				data = JSON.parse(data);
				self.successTransferCall(data.result);
			});
			$('body').on('pjaxDone', function() {
				self.$dashboard = $('.freshfone_dashboard');
				self.$availableAgents = self.$dashboard.find('.live-available-agents');
				self.$liveCalls = self.$dashboard.find('.live-calls');

				self.tryUpdateDashboard();
			});
		},
		tryUpdateDashboard: function () {
			if ((this.$availableAgents || this.$liveCalls) === undefined) { return false; }

			this.$availableAgents.text(this.totalAgents);
			this.$liveCalls.text(this.activeCalls);
		},
		onlineUserCount: function () {
			var offset = freshfoneuser.isOnline() ? -1 : 0;
			return (this.totalAgents + offset < 0) ? 0 : (this.totalAgents + offset) || 0 ;
		},
		getAvailableAgents: function () {
      var self = this;
      $.ajax({
        dataType: "json",
        url: '/freshfone/dashboard_stats',
        success: function(data) {
          self.available_agents=data.available_agents;
          self.activeCalls = data.active_calls;
          self.populateAvailableAgentsCount();
          self.tryUpdateDashboard();
        }
      });
		},

		populateAvailableAgentsCount: function () {
			freshfonesocket.totalAgents = this.available_agents;
			freshfonesocket.tryUpdateDashboard();
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
        this.updateAvailableGroups();
				this.$freshfoneAvailableAgentsListSearchSpan.toggle(this.agentList.items.length > 7);
				this.noAvailableAgentsToggle();
				if(freshfonecalls.tConn) { this.bindTransfer();	}
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
        group.agents_count = agent_ids.length+" agents available";
        if(agent_ids.length > 0){
          groupArray.push(group);
        }
      });
      groupArray.each(function(grp){
        self.agentList.add(grp);
      }); 
    },

		addToAvailableAgents: function (user) {
			if (user.id === freshfone.current_user || this.agentList === undefined) { return false; }
			if (!this.agentList.get("id", user.id)) {
				this.agentList.add(this.formatListItem(user));
        this.agentList.sort('sortname', { asc: true });
				this.$freshfoneAvailableAgentsListSearchSpan.toggle(this.agentList.items.length > 7);
				this.noAvailableAgentsToggle();
			}
		},

		removeFromAvailableAgents: function (id) {
			if (id === freshfone.current_user || this.agentList === undefined) { return false; }
			this.agentList.remove("id", id);
			this.noAvailableAgentsToggle();
		},

		removeOfflineAgents: function (ids) {
			var self = this;
			if ( !ids  ) { return false; }
			ids.each (
				function (id) {
					self.onloadUserarray = self.onloadUserarray.reject(function (user) { if(user.id == parseInt(id) ) { return user; } });
				}	
			 );
			this.noAvailableAgentsToggle();
		},
		
		toggleUserStatus: function  (status) {
			if (status !== userStatus.BUSY) {
				freshfoneuser.online = freshfoneuser.isOnline();
			}
			freshfoneuser.setStatus(status);
			freshfoneuser.userPresenceDomChanges();
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

		bindTransfer: function () {
			var self = this;
			$('#freshfone_available_agents .available_agents_list li').die('click');
			$('#freshfone_available_agents .available_agents_list li').live('click', function () {
        var group_id = $(this).find('.group_id').html();
        self.freshfonecalls.transferCall($(this).find('.id').html(), group_id);
			});
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
		formatListItem: function (user) {
      return {"id":user.id, "available_agents_name" : user.name, "sortname" : "A_"+user.name, "available_agents_avatar": user.avatar }
		}
	};
}(jQuery));
