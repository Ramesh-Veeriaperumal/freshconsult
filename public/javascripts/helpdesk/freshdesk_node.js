!function ($) {

 window.faye_realtime = {
  faye_subscriptions : [],
  fayeClient : null,
  faye_channels : [],
  new_ticket_ids : [],
  updated_ticket_ids : [],
  addChannel : null,
  extension_set : false
 }

 window.faye_realtime.addChannel = function(channel)
 {
    if(window.faye_realtime.faye_channels.indexOf(channel) == -1)
    {
      window.faye_realtime.faye_channels.push(channel);
    }
 }
  var CLIENT_DEFAULT_OPTIONS = {
      retry: 1,
      timeout: 120
    },
    FreshdeskNode = function(){
    },
    bindUnloadEvnts = function(){
      jQuery(document).unbind('disconnectNode');
      jQuery(document).bind('disconnectNode', function(ev){
       window.faye_realtime.fayeClient.disconnect();
      });
    };

  FreshdeskNode.prototype.addAuthExt = function(params,channel){
    window.faye_realtime.addChannel(channel);
    window.faye_realtime.extension_set = true;
    window.faye_realtime.fayeClient.addExtension({
      outgoing: function(message, callback) {
        message.ext = params;
        message.ext.channel = window.faye_realtime.faye_channels;
        callback(message);
      }
    });
  };

  FreshdeskNode.prototype.initClient = function(callback){
    opts = $.extend({},CLIENT_DEFAULT_OPTIONS,this.opts.clientOpts)
    if(!window.faye_realtime.fayeClient){
      window.faye_realtime.fayeClient = new Faye.Client(this.host,opts);
    }
    if(this.opts.addAuthExtParams){
      this.addAuthExt(this.opts.addAuthExtParams,this.opts.channel)
    }
    bindUnloadEvnts();
    callback()
  };

  FreshdeskNode.prototype.init = function(host,opts,callback){
    this.host = host;
    this.opts = opts;
    this.initClient(callback);
    this.initialized = true;
  };

  FreshdeskNode.prototype.subscribe = function(channel,callback){
   var subscription =  window.faye_realtime.fayeClient.subscribe(channel, callback);
   return subscription;
  };

  window.FreshdeskNode || (window.FreshdeskNode = new FreshdeskNode());

  var currentUserId,
    updated_tickets = [];
  var bindTktrefreshEvnts = function(){
      $("#index_refresh_alert").bind("click", function(ev){
        $("#index_refresh_alert").slideUp(100);
        $("#FilterOptions").trigger("change");
        getFilterData();
      });

      $(".filter_item").bind("change", function(){
        $("#index_refresh_alert").slideUp(100);
      });

      $("#SortMenu, .prev_page, .next_page, .toolbar_pagination_full").live("click", function(){
        $("#index_refresh_alert").slideUp(100);
      });
    },
    get_due_by_value = function(time){
      switch(true){
        case time<0:
          return '1';
        case time<8 && time>0:
          return '4';
        case time<24 && time>8:
          return '2';
        case time<48 && time>48:
          return '3';
      }   
    },
    show_refresh_alert = function(ticket_id, type){
      if(type == "new"){
        window.faye_realtime.new_ticket_ids.push(ticket_id);
        update_counter("#new_ticket_message", window.faye_realtime.new_ticket_ids.length);
      }

      if(type == "update"){
        if(window.faye_realtime.updated_ticket_ids.indexOf(ticket_id) < 0) window.faye_realtime.updated_ticket_ids.push(ticket_id);
        update_counter("#update_message", window.faye_realtime.updated_ticket_ids.length);
      }

      $("#index_refresh_alert").slideDown(100);
      flash_ticket(ticket_id);
    },
    update_counter = function(id, count){
      $this = $(id);
      $this.text((count > 1) ? $this.data("textOther") : $this.data("textOne"))
          .attr("data-count", count)
          .show();
    },
    flash_ticket = function(ticket_id){   
      if(jQuery("[data-ticket="+ticket_id+"]")){
        jQuery("[data-ticket="+ticket_id+"] .status-source").addClass('source-detailed-auto-refresh');
        jQuery("[data-ticket="+ticket_id+"] .status-source").attr("title",ticketUpdateTitle);
        updated_tickets.push("[data-ticket="+ticket_id+"] td");
      }
    },
    refreshCallBack = function(message){
        var filter_options = JSON.parse(jQuery("input[name=data_hash]").val());
        var count = 0;

        if (jQuery("[data-ticket="+message.ticket_id+"]").length != 0){
          show_refresh_alert(message.ticket_id, message.type);
        } 
        else if (filter_options.length != 0)
        {
          for (var i=0; i<filter_options.length; i++) {

            if ((filter_options[i].condition != "due_by") && 
                  (filter_options[i].condition != "created_at") && 
                              (filter_options[i].ff_name == "default")) {
              if (filter_options[i].condition == "responder_id"){
                if ((filter_options[i].value.split(',')).indexOf('0') >= 0) {
                  filter_options[i].value += ","+currentUserId;
                } 
              }
              if ((filter_options[i].value.split(',')).indexOf(message[filter_options[i].condition]+'') >= 0) {
                count++;
              }
            } 
            else if ((filter_options[i].ff_name != "default"))
            {
              if ((filter_options[i].value.split(',')).indexOf(message[filter_options[i].ff_name]+'') >= 0) {
                count++;
              }
            }
            else 
            {
              switch(filter_options[i].condition) {
                case "due_by":
                  var time = message[filter_options[i].condition];
                  if((filter_options[i].value.split(',')).indexOf(get_due_by_value(time)) >= 0) {
                    count++;
                  }
                  break;
                case "created_at":
                  var created_at = Date.parse(message[filter_options[i].condition]);
                  var created_at_filter = filter_options[i].value;
                  if(!isNaN(created_at_filter)){
                    if(((Date.now()-created_at)/60000) < ((filter_options[i].value)-'')){
                      count++;
                    }
                  } else {
                    if(created_at_filter == "yesterday"){
                      if((created_at < Date.today()) && ( created_at > Date.today().add({days : -1}) )){
                        count++;
                      }
                    } else {
                      if( created_at > ticketFilterDateoptions[created_at_filter]){
                        count++;
                      }
                    }
                  }
                  break;
              }
            }
          };

          if(count == filter_options.length) {
            show_refresh_alert(message.ticket_id, message.type);
          }
        } else {
          show_refresh_alert(message.ticket_id, message.type);
        }
      },
      TicketRefresh = function(){
        
      };

    TicketRefresh.prototype.init = function(host,opts){
      currentUserId = opts.current_user_id;
      window.FreshdeskNode.init(host,opts,function(){
        window.FreshdeskNode.subscribe(opts.channel,refreshCallBack);
        bindTktrefreshEvnts();
      });
    };
    window.TicketRefresh || (window.TicketRefresh = new TicketRefresh());

    //******************************* Agent Collision Node *************************** 


    function extendFunction(methods)
    {
      for(var key in methods)
      {
        if(methods.hasOwnProperty(key)){
          this.constructor.prototype[key] = methods[key];
        }
      }
    }


    var Freshdesk_Collision_Node_Methods = {
      init : function(host,opts)
      {
        this.host = host;
        this.opts = this.extend.call(this.opts,opts);
        if(!window.faye_realtime.fayeClient)
        {
          window.faye_realtime.fayeClient = new Faye.Client(this.host,this.opts);
        }
        this.client  = window.faye_realtime.fayeClient;
      },
      subscribe : function(channel,callback)
      {
        var subscription = this.client.subscribe(channel,callback);
        window.faye_realtime.faye_subscriptions.push(subscription);
        return subscription;
      },
      then : function(subscription,success_callback,err_callback)
      {
        if(err_callback)
        {
          subscription.then(success_callback,err_callback); 
        }
        else
        {
          subscription.then(success_callback);
        }
      },
      addExtension : function(extension)
      {
        this.client.addExtension(extension);      
      },
      extend : function(methods)
      {
        for(var key in methods)
        {
          if(methods.hasOwnProperty(key)){
            this[key] = methods[key];
          }
        }
        return this;
      }
    };

    var Freshdesk_Collision_Node = function()
    {
      this.client = null;
      this.opts = {
        retry: 10,
        timeout: 120
      };
      this.host = '';
      this.methodDefinitions = Freshdesk_Collision_Node_Methods;
      extendFunction.call(this,this.methodDefinitions);
    }

    

   var collision_node = new Freshdesk_Collision_Node();

   window.FayeClient || (window.FayeClient = collision_node);


   var UtilMethodDefinitions  = {
      checkUniq : function(myArray,obj,type,otherOption)
      {
          var found = false;
          var otherArrayFound = false;
        if((obj.name.toString() === this.current_user) && (obj.userId.toString() === this.current_user_id.toString()))
        {
          return false;
        }
        for(var i=0;i < myArray.length;i++)
        {
          if((obj.name.toString() === myArray[i].name.toString()) && (obj.userId.toString() === myArray[i].userId.toString()))
          {
            found = true;
          }
        }
        if(otherOption && (!found) )
        {
          if(obj)
          { 
            for(var i=0;i < otherOption.length;i++)
            {
              if((obj.name.toString() === otherOption[i].name.toString())  && (obj.userId.toString() === otherOption[i].userId.toString()))
              {
                found = true;
                if(type == 'replying')
                {
                  myArray = otherOption;
                }
              }
            }
          }
        }
        if(!found)
        {
          myArray.push(obj);
        }
      },
      messageHandler : function(message)
      {
          var ticketId_array = message.channel.toString().split('/');
          var ticketId = ticketId_array[ticketId_array.length-1];
          message = this.utils.removeUnwantedData.call(this,message);
          if(!this.tickets[ticketId])
          {
            this.tickets[ticketId] = {agents : { viewing:[], replying:[] }};
          }
          this.tickets[ticketId].agents.viewing = [];
          this.tickets[ticketId].agents.replying = [];
          for(var i=0;i < message.data.length;i++)
          {
            if((message.data[i].reply) && (message.data[i].reply == 'true'))
            {
              this.utils.checkUniq.call(this,this.tickets[ticketId].agents.replying,message.data[i],'viewing',this.tickets[ticketId].agents.viewing);
            }
            else if( (message.data[i].view) && (message.data[i].view == 'true'))
            {
              this.utils.checkUniq.call(this,this.tickets[ticketId].agents.viewing,message.data[i],'replying',this.tickets[ticketId].agents.replying);
            }         
          }
          if(message.data.length == 0)
          {
            if(!this.tickets[ticketId])
            {
              this.tickets[ticketId] = {agents : { viewing:[], replying:[] }};
            }
            this.tickets[ticketId].agents.viewing = [];
            this.tickets[ticketId].agents.replying = [];
          }
          this.utils.update_viewing_notification_ui.call(this,ticketId,this.tickets[ticketId].agents.viewing);
          this.utils.update_replying_notification_ui.call(this,ticketId,this.tickets[ticketId].agents.replying);
      },
      update_viewing_notification_ui : function(key,viewing){
        if(viewing.length == 0)
        {
          jQuery('[data-ticket-id="'+key+'"]').removeClass('view_collision').find("span[rel=viewing_agents_tip]").html("");
          jQuery('[data-ticket-id="'+key+'"]').find("span[rel=viewing_count]").html('');
        }
        else
        {
        jQuery('[data-ticket-id="'+key+'"]').addClass('view_collision').find("span[rel=viewing_agents_tip]").html(this.utils.humanize_name_list.call(this,viewing,'viewing'));
          jQuery('[data-ticket-id="'+key+'"]').addClass('view_collision').find("span[rel=viewing_count]").html(viewing.length);
        }
        this.utils.updateToolTipIndex.call(this,key,'viewing',this.utils.humanize_name_list.call(this,viewing,'viewing'));
      },
      update_replying_notification_ui : function(key,replying){
        if(replying.length == 0)
        {
          jQuery('[data-ticket-id="'+key+'"]').removeClass('reply_collision').find("span[rel=replying_agents_tip]").html("");
           jQuery('[data-ticket-id="'+key+'"]').find("span[rel=replying_count]").html("");
        }
        else
        {
          jQuery('[data-ticket-id="'+key+'"]').addClass('reply_collision').find("span[rel=replying_agents_tip]").html(this.utils.humanize_name_list.call(this,replying,'replying'));
          jQuery('[data-ticket-id="'+key+'"]').addClass('reply_collision').find("span[rel=replying_count]").html(replying.length);
        }
        this.utils.updateToolTipIndex.call(this,key,'replying',this.utils.humanize_name_list.call(this,replying,'replying'));
      },
      updateToolTipIndex : function(ticket_id,type,value){
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
        var collision_dom  = jQuery('[data-ticket-id="'+ticket_id+'"]') 
        if(type == "viewing") {
          viewing_agents = jQuery(working_agents).find("[rel=viewing_agents]");
          if (collision_dom.find("[rel=viewing_agents_tip]").html() != ''){
            jQuery('#ui-tooltip-' + ticket_id).addClass('hasViewers');
            viewing_agents.removeClass('hide');
            jQuery('#working_agents_' + ticket_id).show();
          } else {
            jQuery('#ui-tooltip-' + ticket_id).removeClass('hasViewers');
            viewing_agents.addClass('hide');
          }
          viewing_agents.html(collision_dom.find("[rel=viewing_agents_tip]").html());

        } else if(type == "replying") {
          replying_agents = jQuery(working_agents).find("[rel=replying_agents]");
          if (collision_dom.find("[rel=replying_agents_tip]").html() != ''){
            jQuery('#ui-tooltip-' + ticket_id).addClass('hasReplying');
            replying_agents.removeClass('hide');
            jQuery('#working_agents_' + ticket_id).show();
          } else {
            jQuery('#ui-tooltip-' + ticket_id).removeClass('hasReplying');
            replying_agents.addClass('hide');
          }
          replying_agents.html(collision_dom.find("[rel=replying_agents_tip]").html());

        }   

      },
      humanize_name_list : function(data, action) {
        var text = '';
        if (data.length == 1) {
          text = '<strong>' + data[0].name + '</strong> is currently ' + action + '.';
        } else if (data.length == 2) {
          text = '<strong>' + data[0].name + '</strong> and <strong>' + data[1].name + '</strong>  are currently ' + action + '.';
        } else if (data.length > 2)  {
          text = '<strong>' + data[0].name + '</strong> and <strong>' + (data.length - 1) + ' more </strong>  are currently ' + action + '.';
        }

        return text;
      },
      removeUnwantedData : function(message)
      {
        for(var i=0;i<message.data.length;i++)
        {
          var element = message.data[i];
          for(var j=i+1;j<message.data.length;j++)
          {
            if(j != i)
            {
              if(element.userId.toString() === message.data[j].userId.toString() )
              {
                if((element.reply) && (element.reply === 'true'))
                {
                  message.data.splice(j,1);
                }
                else if((message.data[j].reply) && (message.data[j].reply === 'true'))
                {
                  message.data.splice(i,1);
                  i=i-1;
                }
              }
            }
          }
        }
        return message;
      },
      ticketMessageHandler : function(message,agents)
      {
        agents.replying = [];
        agents.viewing = [];
        var client_list = message.data;
        
        client_list = this.utils.removeUnwantedData.call(this,message).data;
        for(var i=0;i < client_list.length;i++)
        {       
          if((client_list[i].reply) && (client_list[i].reply == 'true'))
            {
              this.utils.checkUniq.call(this,agents.replying,client_list[i],'viewing',agents.viewing);
            }
            else if( (client_list[i].view) && (client_list[i].view == 'true'))
            {
              this.utils.checkUniq.call(this,agents.viewing,client_list[i],'replying',agents.replying);
            }    
                    
        }
        this.utils.update_notification_ui_ticket.call(this,agents);
      },
      update_notification_ui_ticket : function(agent){  
        jQuery("#agents_viewing").toggleClass("active", (agents.viewing.length != 0) ).effect("highlight", { color: "#fffff3" }, 400);
        jQuery("#agents_viewing .flip-back").html(agents.viewing.length);
        jQuery("#agents_replying").toggleClass("active", (agents.replying.length != 0) ).effect("highlight", { color: "#fffff3"  }, 400);      
        jQuery("#agents_replying .flip-back").html(agents.replying.length);
        jQuery(".list_agents_replying").toggleClass("hide", (agents.replying.size() == 0) ).html(this.utils.humanize_name_list.call(this,agents.replying, 'replying')); 
      }
  }

  var Utils = function()
  {
    this.methodDefinitions = UtilMethodDefinitions;
    extendFunction.call(this,this.methodDefinitions);
  };



   var AgentCollision_Methods = {
      init : function(opts)
      {
        this.current_user_id = opts.current_user_id;
        this.current_user = opts.current_user;
        this.agent_names = opts.agent_names;
        this.addExtensions(this.extensions,function()
          {
            this.subscriptions(this.channels,this.channelCallbacks);
          });
      },
      setChannels : function(channels)
      {
        this.channels = channels; 
        return this;
      },
      setExtensions : function(extensions)
      {
        this.extensions = extensions;
        return this;
      },
      setEvents : function(events)
      {
        this.events = events;
        return this;
      },
      setChannelCallbacks : function(callbacks)
      {
        this.channelCallbacks = callbacks;
        return this;
      },
      addExtensions : function(extensions,callback)
      {
        var self = this;
        for(var i=0;i<extensions.length;i++)
        {
          this.faye_client.addExtension(extensions[i])
        }
        callback.call(this);
      },
      subscriptions : function(channels,channelCallbacks)
      {
        var self = this;
        for(var channel in channels)
        {
          if(channels.hasOwnProperty(channel))
          {
             var subscription = this.faye_client.subscribe(channels[channel],(channelCallbacks[channel]).bind(self));
          }
        }
        if(this.events)
        {
          this.addEvents();
        } 
      },
      addEvents : function()
      {
        for(event in this.events)
        {
          if(this.events.hasOwnProperty(event))
          {
            (this.events[event]).bind(this)();
          }
        }
      },
      extend : function(methods)
      {
        for(var key in methods)
        {
          if(methods.hasOwnProperty(key)){
            this[key] = methods[key];
          }
        }
        return this;
      },
    };


   var AgentCollision = function()
   {
      this.faye_client = window.FayeClient;
      this.extensions = null;
      this.channels = null;
      this.channelCallbacks = null;
      this.tickets = {};
      this.current_user = '';
      this.current_user_id = '';
      this.events = null;
      this.utils = new Utils();
      this.agent_names = null;
      this.methodDefinitions = AgentCollision_Methods;
      extendFunction.call(this,this.methodDefinitions);
   } 

  window.AgentCollision || (window.AgentCollision = new AgentCollision());

  
  


  

}(window.jQuery);
