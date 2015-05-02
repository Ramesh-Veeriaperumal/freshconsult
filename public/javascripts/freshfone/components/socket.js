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
    this.onloadexternalNumbersarr= [];
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
      this.bindTransfer();
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
    $freshfoneAvailableAgentsListSearch: $('.ffone_available_agents #online-agents-list .search'),
    $freshfoneAvailableAgentsListSearchSpan: $('.ffone_available_agents #search-agents'),
    $noAvailableAgent: $('.ffone_available_agents .no_available_agents'),
    $noAvailableNumbers: $('.ffone_available_agents .no_available_numbers'),
    $availableAgentsList: $('.ffone_available_agents #online-agents-list .list-component'),
    $externalNumbersList: $('.ffone_available_agents #external-numbers-list .list-component'),
    selectedElement: null,
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
          if(!self.$externalNumbersList.is(':visible')){
            self.noAvailableAgentsToggle();
          }
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
        this.updateAvailableGroups();

        if(!this.$externalNumbersList.is(':visible')){
			    this.noAvailableAgentsToggle();
        }
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
        group.agents_count = agent_ids.length+" agents";
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
        if(number.length == 13){
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
    validateSearchInput: function(){
      var self = this;
       $(document).on('keypress.freshfonetransfer','.ffone_available_agents #search-external',function(event){
        var keyVal = String.fromCharCode(event.which);
        var typedVal = $(this).val();
        if(typedVal.length < 12){
          if ((event.which > 47 &&  event.which < 58) || (event.which == 8 || event.which == 46 || event.which == 37 || event.which == 39)
            || (event.ctrlKey && event.which == 86)){
           return true;
          }
        } 
        else if(typedVal.length == 12 && (event.which == 8 || event.which == 46 || event.which == 37 || event.which == 39)){
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

      this.bindKeyTraversal('online-agents-list','available_agents_list','transfer-active');
      this.bindKeyTraversal('external-numbers-list','available_numbers_list','transfer-external-selected transfer-active');
      this.bindMouseEvents();
		},
    bindMouseEvents: function(){
      var self = this;

      $('#freshfone_available_agents').on('hover',' #online-agents-list ul >li', function(event) {
        self.selectedElement == null;
        $('#freshfone_available_agents #online-agents-list li.transfer-active').removeClass('transfer-active');
        if(event.type == 'mouseenter'){
          $(this).addClass('transfer-active');
        }
      });

      $('#freshfone_available_agents').on('hover','.available_numbers_list li',function(event) {
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
      $('#freshfone_available_agents').on('click.freshfonetransfer','.available_agents_list li', function () {
        var group_id = $(this).find('.group_id').html();
        self.freshfonecalls.transferCall($(this).find('.id').html(), group_id);
      });


      $('#freshfone_available_agents').on('click.freshfonetransfer', '.available_numbers_list li', function () {
          var external_number = $(this).find('.external_number').html();
          self.freshfonecalls.transferCall($(this).find('.id').html(), null, external_number);
      });

      $('#freshfone_available_agents').on('click.freshfonetransfer','#new_external_number',function(){
        var external_number = jQuery('#external_number_label').html();
        if(external_number.length == 13){
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
    formatNumberItem: function (number) {
      return {"id":number, "external_number" : number}
    },
		formatListItem: function (user) {
      return {"id":user.id, "available_agents_name" : user.name, "sortname" : "A_"+user.name, "available_agents_avatar": user.avatar }
		}
	};
}(jQuery));
