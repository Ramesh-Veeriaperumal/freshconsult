// var console, io, freshfone.current_account, freshfoneuser, freshfone.current_user;
var FreshfoneSocket;
(function ($) {
    "use strict";
  FreshfoneSocket = function (freshfonecalls) {
    this.className = "FreshfoneSocket";
    this.$dashboard = $('.freshfone_dashboard');
    this.$availableAgents = this.$dashboard.find('.live-available-agents');
    this.$liveCalls = this.$dashboard.find('.live-calls');
    this.$dashboardTable = this.$dashboard.find('.freshfone_dash');
    this.onlineAgents = 0;
    this.onloadUserarray = [];
    this.freshfonecalls = freshfonecalls;
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
    init: function () {
      var self = this;
      this.connect();
      this.freshfone_socket_channel.on('connect', function () {
        console.log("Connecting to Freshfone");
        // self.registerCallbacks();
      });
      self.registerCallbacks();
      this.freshfone_socket_channel.on('disconnect', function () {
        console.log("DisConnecting from Freshfone");
      });
    },
    $transferSearch: $('#transfer_call .search'),
    $transferNoAvailableAgent: $('#transfer_call .no_available_agents'),
    $transferAvailableAgentsList: $('#transfer_call #online-agents-list'),
    handleFailure: function () {
    },
    disconnect: function () {
      if (this.freshfone_socket_channel === undefined) { return; }
      this.freshfone_socket_channel.socket.disconnect();
      this.freshfone_socket_channel = false;
    },
    connect: function () {
      this.freshfone_socket_channel = io.connect(this.freshfone_nodejs_url(), 
                                            {'sync disconnect on unload': false});
    },
    freshfone_nodejs_url: function(){
      var query = freshfone.current_user+'&|&'+freshfone.current_account+'&|&'+$.cookie('helpdesk_node_session');
      return freshfone.freshfone_nodejs_url + "?s=" + encodeURIComponent(Base64.encode(query));
    },
    registerCallbacks: function () {
      var self = this;
      // if (!this.freshfone_socket_channel) { this.connect(); }
        this.freshfone_socket_channel.emit('init_freshfone_socket', {
        'user' : freshfone.current_user, 
        'account': freshfone.current_account,
        'account_url': freshfone.account_url });
      
        this.freshfone_socket_channel.on('turn_on_incoming_sound', function () {
          if (typeof Twilio !== "undefined" && Twilio.Device.sounds) {
            Twilio.Device.sounds.incoming(true);
          }
        });

        this.freshfone_socket_channel.on('turn_off_incoming_sound', function () {
          if (typeof Twilio !== "undefined" && Twilio.Device.sounds) {
            Twilio.Device.sounds.incoming(false);
          }
        });

        this.freshfone_socket_channel.on('agent_available', function (data) {
          data = JSON.parse(data) || {};
          if (data.user) { self.addToAvailableAgents(data.user); }
        });

        this.freshfone_socket_channel.on('agent_unavailable', function (data) {
          data = JSON.parse(data) || {};
    
          if (data.user && data.user.id) { self.removeFromAvailableAgents(data.user.id); }
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
        this.$transferSearch.toggle(this.agentList.items.length > 7);
        this.noAvailableAgentsToggle();
        this.bindTransfer();
      }
      // else {
        // this.agentList.add(this.onloadUserarray); // temporary
      // }
    },

    addToAvailableAgents: function (user) {
      if (user.id === freshfone.current_user || this.agentList === undefined) { return false; }
      if (!this.agentList.get("id", user.id)) {
        this.agentList.add(user);
        this.$transferSearch.toggle(this.agentList.items.length > 7);
        this.noAvailableAgentsToggle();
      }
    },

    removeFromAvailableAgents: function (id) {
      if (id === freshfone.current_user || this.agentList === undefined) { return false; }
      this.agentList.remove("id", id);
      this.noAvailableAgentsToggle();
    },
    
    noAvailableAgentsToggle: function () {
      var showAgentsList = (this.agentList && this.agentList.items.length) ? true : false;
      this.$transferNoAvailableAgent.toggle(!showAgentsList);
      this.$transferAvailableAgentsList.toggle(showAgentsList);
    },

    bindTransfer: function () {
      var self = this;
      $('.available_agents_list').on('click', 'li', function () {
        self.freshfonecalls.transferCall($(this).find('.id').html());
      });
    },
  };
}(jQuery));