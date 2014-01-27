!function ($) {

  var fayeClient,
    CLIENT_DEFAULT_OPTIONS = {
      retry: 10,
      timeout: 120
    },
    FreshdeskNode = function(){
      console.log('Loading freshdesk node')
    },
    bindUnloadEvnts = function(){
      jQuery(document).unbind('disconnectNode');
      jQuery(document).bind('disconnectNode', function(ev){
        console.log('disconnecting...')
        fayeClient.disconnect();
      });
    };

  FreshdeskNode.prototype.loadClientJS = function(callback){
    var self = this;
    AsyncJSLoader(this.host+'/client.js',function(){
      try {
        console.log('initializing ticket refresh')
        self.initClient();
        if(self.opts.addAuthExtParams){
          self.addAuthExt(self.opts.addAuthExtParams)
        }
        callback();
      }
      catch(e){
        console.error('Freshdesk node script error');
      }
    });
  };

  FreshdeskNode.prototype.addAuthExt = function(params){
    fayeClient.addExtension({
      outgoing: function(message, callback) {
        message.ext = params;
        callback(message);
      }
    });
  };

  FreshdeskNode.prototype.initClient = function(){
    opts = $.extend({},CLIENT_DEFAULT_OPTIONS,this.opts.clientOpts)
    fayeClient = new Faye.Client(this.host,opts);
    bindUnloadEvnts();
  };

  FreshdeskNode.prototype.init = function(host,opts,callback){
    // if(this.initialized) {
    //   console.log('FreshdeskNode already initialized');
    //   callback();
    //   return
    // }
    this.host = host;
    this.opts = opts;
    this.loadClientJS(callback);
    this.initialized = true;
  };

  FreshdeskNode.prototype.subscribe = function(channel,callback){
    fayeClient.subscribe(channel, callback)
  };

  window.FreshdeskNode || (window.FreshdeskNode = new FreshdeskNode());

  var currentUserId,
    updated_tickets = [],
    new_ticket_ids = [],
    updated_ticket_ids = [],
    bindTktrefreshEvnts = function(){
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
        new_ticket_ids.push(ticket_id);
        update_counter("#new_ticket_message", new_ticket_ids.length);
      }

      if(type == "update"){
        if(updated_ticket_ids.indexOf(ticket_id) < 0) updated_ticket_ids.push(ticket_id);
        update_counter("#update_message", updated_ticket_ids.length);
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

}(window.jQuery);
