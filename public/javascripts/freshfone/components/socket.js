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

        if (connectionAttempts++ >= MAX_RECONNECT_ATTEMPTS) {
          connectionAttempts = 1;
          reconnectTimeout = setTimeout(function () { self.freshfone_socket_channel.socket.reconnect(); }, reconnectFailureDelay);
        }
      });
    },
    $freshfoneAvailableAgentsListSearch: $('.ffone_available_agents .search'),
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
    },
    connect: function () {
      this.freshfone_socket_channel = io.connect(this.freshfone_nodejs_url(), 
                                        {'sync disconnect on unload': false,
                                        'max reconnection attempts': MAX_RECONNECT_ATTEMPTS});
    },
    freshfone_nodejs_url: function(){
      var query = freshfone.current_user+'&|&'+freshfone.current_account+'&|&'+$.cookie('helpdesk_node_session');
      return freshfone.freshfone_nodejs_url + "?s=" + encodeURIComponent(Base64.encode(query));
    },
    registerCallbacks: function () {
      var self = this;
      this.freshfone_socket_channel.emit('get_create_timeout');
      this.freshfone_socket_channel.on('timeout_value', function(timeout_values) {
        if (timeout_values.SLEEP_TIMEOUT >= 0 && timeout_values.IDLE_TIMEOUT >= 0) {
          this.idleDetector = new IdleDetector({
              SLEEP_TIMEOUT : timeout_values.SLEEP_TIMEOUT,
              IDLE_TIMEOUT : timeout_values.IDLE_TIMEOUT
          });
        };
      });

      freshfoneuser.get_presence(function(err, status) {
        if(!err && self.idleDetector) {
          switch(status) {
            // case 0: //offline
            case 2: // busy
              self.idleDetector.disable();
              break;
            case 0: //offline
            case 1: //online
              self.idleDetector.enable();
              break;
            default: //control never reaches here!
              break;
          }
        }
      });

			this.freshfone_socket_channel.on('agent_available', function (data) {
				data = JSON.parse(data) || {};
				if(data.user.id == freshfone.current_user) {
          self.toggleUserStatus(userStatus.ONLINE);
          if(self.idleDetector) self.idleDetector.enable();
          return;
        }
				if (data.user) { self.addToAvailableAgents(data.user); }
			});

      this.freshfone_socket_channel.on('agent_unavailable', function (data) {
        data = JSON.parse(data) || {};

        if (data.user && data.user.id) { self.removeFromAvailableAgents(data.user.id); }
        if(data.user.id == freshfone.current_user) {
          self.toggleUserStatus(userStatus.OFFLINE);
          if(self.idleDetector) self.idleDetector.disable();
        }
      });
                
      this.freshfone_socket_channel.on('agent_busy', function (data) {
        if(self.idleDetector) self.idleDetector.disable();
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
			$.ajax({
				dataType: "script",
				url: '/freshfone/dashboard_stats'
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
			freshfonesocket.totalAgents = this.onloadUserarray.length;
			freshfonesocket.tryUpdateDashboard();

			if (!this.agentList) {
				list = $.grep(this.onloadUserarray, function (user) { return user.id !== freshfone.current_user; });
				if (list.length) {
					this.agentList = new List('online-agents-list', options, list);
				} else {
					this.agentList = new List('online-agents-list', options);
				}
				this.$freshfoneAvailableAgentsListSearch.toggle(this.agentList.items.length > 7);
				this.noAvailableAgentsToggle();
				if(freshfonecalls.tConn) { this.bindTransfer();	}
			}
			// else {
				// this.agentList.add(this.onloadUserarray); // temporary
			// }
		},

		addToAvailableAgents: function (user) {
			if (user.id === freshfone.current_user || this.agentList === undefined) { return false; }
			if (!this.agentList.get("id", user.id)) {
				this.agentList.add(user);
				this.$freshfoneAvailableAgentsListSearch.toggle(this.agentList.items.length > 7);
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
			if (status === userStatus.BUSY) {
				this.freshfoneuser.setStatus(status); 
			}
			else {
				freshfoneuser.setStatus(status); 
				freshfoneuser.online = freshfoneuser.isOnline();
				freshfoneuser.userPresenceDomChanges();
			}
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
				self.freshfonecalls.transferCall($(this).find('.id').html());
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
		}
	};
}(jQuery));
