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
      this.isPageUnloading = false;
      this.isChromiumBrowser = this.isChromium();
      this.bindNetworkErrorEvents();
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
        if(freshfonecalls.error)
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
      if(!$.isEmptyObject(this.logs)) 
      {
        ffLogger.logIssue("Freshfone Network Error",this.logs,'error');
        this.logs = {};
      }
    },
    isOperaBrowser: function(){
      return (!!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0);
    },
    isChromeBrowser: function(){
      return (!!window.chrome && !this.isOperaBrowser());
    },
    isSafariBrowser: function(){
      return (Object.prototype.toString.call(window.HTMLElement).indexOf('Constructor') > 0);
    },
    isChromium: function(){
      return (this.isOperaBrowser() || this.isChromeBrowser() || this.isSafariBrowser());
    },
    bindChromiumEvents: function() {
      $(window).on('online', function(){ freshfoneNetworkError.hideNetworkErrorWidget() });
      $(window).on('offline', function(){ freshfonecalls.errorcode = 31003; freshfoneNetworkError.endCallDueToNetworkError() });
    },
    bindNonChromiumEvents: function(){
      $(window).on('ffone.networkUp',function(){ freshfoneNetworkError.networkUp() });
      $(window).on('ffone.networkDown',function(){ freshfoneNetworkError.networkDown() });
    },
    bindCommonEvents: function(){
      $(window).on('beforeunload unload', function(){ 
        freshfoneNetworkError.isPageUnloading = true; //for detecting refresh & normal navigation
      });
    },
    bindNetworkErrorEvents: function(){
      if(this.isChromiumBrowser){
         this.bindChromiumEvents();
      }
      else{ 
        this.bindNonChromiumEvents(); 
      }
      this.bindCommonEvents();
    },
    networkDown: function(){
      if (!freshfoneNetworkError.isPageUnloading) {
        freshfonecalls.errorcode = 31003; //For ICE Liveness Checking
        freshfoneNetworkError.endCallDueToNetworkError();
      }
    },
    networkUp: function(){
      freshfoneNetworkError.hideNetworkErrorWidget();
    }
  };
})(jQuery);