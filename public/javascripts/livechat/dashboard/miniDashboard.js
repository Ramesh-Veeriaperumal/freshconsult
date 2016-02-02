(function(){
  
  window.liveChat = window.liveChat || {};
  
  window.liveChat.miniDashboardView = function(){
    var miniDashboard =  Backbone.View.extend({
      initialize: function(){
        this.setElement('#chat-dashboard');
        this.render();
        this.listenToCollection();
        this.listenToEvents();
      },
  
      listenToCollection: function(){
        this.listenTo(visitorCollection, 'change_count', this.setVisitorsCount);
        this.listenTo(userCollection, 'change_count', this.setAgentsCount);
      },
  
      listenToEvents: function(){
        var that = this;
        document.addEventListener('chat disConnect', function(disconnect){
            if(disconnect){
              that.reduceOpacity();
            }
        }, false);
        document.addEventListener('chat onConnect', function(){
          that.normalOpacity();
        }, false);
        jQuery('#chat-dashboard .icon-refresh')
          .off('click')
          .on('click',function(){
            jQuery(document).trigger("chatReconnect");
          });
      },
  
      render: function(){
        if(CURRENT_ACCOUNT.chat_enabled){
          if(userCollection.availabilityAgentsCount >= 0){
            jQuery('#livechat_online_agent_count').html(userCollection.availabilityAgentsCount);
          }
          if(!CURRENT_USER.isAdmin){
            jQuery("#livechat_online_agent_count").unwrap();
            jQuery("#livechat_online_agent_count").parent("li").removeClass();
          }
  
          visitorCollection.fetchCount();
          if(window.chat_socket && !window.chat_socket.connected){
            this.reduceOpacity();
          }
        }else{
          this.$el.attr("style","display :none");
        }
      },
  
      reduceOpacity: function(){
        this.$el.find('#chat-dashboard .widget-title')
          .addClass('chat_aside_widget')
          .end()
          .find('h3')
          .addClass('fc_widget_refresh_on')
          .removeClass('fc_widget_refresh_off');
      },
  
      normalOpacity: function(){
        this.$el.find('#chat-dashboard .widget-title')
          .removeClass('chat_aside_widget')
          .end()
          .find('h3')
          .addClass('fc_widget_refresh_off')
          .removeClass('fc_widget_refresh_on');      
      },
  
      setVisitorsCount: function(){
        jQuery("#inconversation_visitors_count").html(visitorCollection.count.inConversation);
        jQuery("#return_visitors_count").html(visitorCollection.count.returnVisitor);
      },
  
      setAgentsCount: function(){
        var agentCount = userCollection.availabilityAgentsCount;
        jQuery("#livechat_online_agent_count").html(agentCount);

        (agentCount == 0) ?  jQuery('#agent_status_chat').addClass('disabled') :  jQuery('#agent_status_chat').removeClass('disabled');
      }
    });
  
    return new miniDashboard();
  };

  if(window.visitorCollection){
    window.liveChat.miniDashboardView();
  }else{
    jQuery(document).on('chatLoaded',function(){
      window.liveChat.miniDashboardView();
      jQuery(document).off('chatLoaded');
    });
  }
})();