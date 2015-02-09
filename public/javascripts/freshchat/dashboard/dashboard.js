(function(){

window.freshChat = window.freshChat || {};

window.freshChat.mini_dashboardView = function(){
  var mini_dashboard =  Backbone.View.extend({
            initialize : function(){
                this.setElement('#chat-dashboard');
                this.dashboardTemplate = window.JST['dashboard/dashboard_template'];
                this.render();
                this.listenToCollection();
                this.listenToEvents();
            },
            listenToCollection : function(){
                this.listenTo(visitorCollection, 'change_count', this.setVisitorsCount);
            },
            listenToEvents : function(){
                var that = this;
                document.addEventListener('chat disConnect', function(options){
                    if(options.reason === 'forced close'){
                        that.reduceOpacity();
                    }
                }, false);
                 document.addEventListener('chat onConnect', function(){
                    that.normalOpacity();
                }, false);
                jQuery('#chat-dashboard .icon-refresh').off('click').on('click',function(){
                    jQuery(document).trigger("chatReconnect");
                });
            },
            render : function(){
                this.$el.html(this.dashboardTemplate).show();
                if(CURRENT_ACCOUNT.chat_enabled){
                    if(userCollection.availabilityAgentsCount >= 0){
                        jQuery('#online_agent_count').html(userCollection.availabilityAgentsCount);
                    }
                    visitorCollection.fetchCount();
                    if(window.chat_socket && !window.chat_socket.connected){
                        this.reduceOpacity();
                    }
                }else{
                    this.$el.attr("style","display :none");
                }
            },
            reduceOpacity:function(){
                this.$el.find('.panel-list').addClass('chat_aside_widget').end()
                    .find('h3').addClass('fc_widget_refresh_on').removeClass('fc_widget_refresh_off');
            },
            normalOpacity:function(){
                this.$el.find('.panel-list').removeClass('chat_aside_widget').end()
                    .find('h3').addClass('fc_widget_refresh_off').removeClass('fc_widget_refresh_on');      
            },
            setVisitorsCount : function(){
                this.$el.find("#inconversation_visitors_count").html(visitorCollection.count.inConversation);
                this.$el.find("#new_visitors_count").html(visitorCollection.count.newVisitor);
                this.$el.find("#return_visitors_count").html(visitorCollection.count.returnVisitor);
            }
        });

    return new mini_dashboard();
};

if(window.visitorCollection){
    window.freshChat.mini_dashboardView();
}else{
    jQuery(document).on('chatLoaded',function(){
       window.freshChat.mini_dashboardView();
       jQuery(document).off('chatLoaded');
    });
}
})();