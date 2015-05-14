var FreshfoneNetworkError;
(function($){
  "use strict"
  FreshfoneNetworkError = function(){
    this.init();
  };
  FreshfoneNetworkError.prototype = {
    init: function(){
      this.$freshfoneNetworkErrorWidget = $('#freshfone-error-widget');
      this.foneConnectionInfoClass = 'freshfone_error_info';
      this.foneConnectionErrorClass = 'freshfone_connection_error';
      this.foneConnectionSuccessClass = 'freshfone_connection_success';
      this.logs = {};
    },
    loadDependencies: function(freshfonewidget,freshfonecalls,freshfoneuser){
      this.freshfonewidget = freshfonewidget;
      this.freshfonecalls = freshfonecalls;
      this.freshfoneuser = freshfoneuser;
    },
    applyConnectionErrorClass:function(){
      this.$freshfoneNetworkErrorWidget
          .removeClass(this.foneConnectionInfoClass+' '+this.foneConnectionSuccessClass)
          .addClass(this.foneConnectionErrorClass);
    },
    applyErrorInfoClass:function(){
      setTimeout(function(){
        freshfoneNetworkError.$freshfoneNetworkErrorWidget
        .removeClass(freshfoneNetworkError.foneConnectionErrorClass+' '+freshfoneNetworkError.foneConnectionSuccessClass)
        .addClass(freshfoneNetworkError.foneConnectionInfoClass);
      },2000);
    },
    applyConnectionSuccessClass:function(){
      this.$freshfoneNetworkErrorWidget
          .removeClass(this.foneConnectionErrorClass+' '+this.foneConnectionInfoClass)
          .addClass(this.foneConnectionSuccessClass);
    },
    endCallDueToNetworkError:function(){
      if(this.freshfonecalls.isCallActive()){
      	this.addToLogBuffer(this.freshfonecalls.error.info);
        this.freshfonecalls.hangup();
        this.freshfoneuser.resetStatusAfterCall();
        this.freshfonewidget.handleWidgets();
        freshfone.networkErrorSound.play();
      }
      if(!this.isNetworkErrorWidgetVisible()){
        this.freshfonewidget.hideAllWidgets();
        this.applyConnectionErrorClass();
        this.toggleNetworkErrorWidget(true);
        this.applyErrorInfoClass();
      }
    },
    toggleNetworkErrorWidget: function(toShow){
      this.$freshfoneNetworkErrorWidget.toggle(toShow);
    },
    isNetworkErrorWidgetVisible: function(){
      return this.$freshfoneNetworkErrorWidget.is(":visible");
    },
    hideNetworkErrorWidget: function(){
      if(this.isNetworkErrorWidgetVisible()){
      	this.pushsavedLogsAsIssue();
        this.applyConnectionSuccessClass();
        setTimeout(function(){
          freshfoneNetworkError.toggleNetworkErrorWidget(false);
          freshfonewidget.showOutgoing();
        },2000);
        if(this.freshfoneuser.isOnline()){
          this.freshfoneuser.makeOffline();
          setTimeout(freshfoneuser.toggleUserPresence(),10000);
        }
        setTimeout(freshfonesocket.getAvailableAgents(),10000); //Calling this after 10 seconds for Resque Job to do the work
      }
    },
    addToLogBuffer: function(loghash){
      this.logs[Date().toString()] = loghash;
    },
    pushsavedLogsAsIssue:function(){
      if(!jQuery.isEmptyObject(this.logs)) 
      {
        ffLogger.logIssue("Freshfone Network Error",this.logs,'error');
        this.logs = {};
      }
    }  
  };
})(jQuery);