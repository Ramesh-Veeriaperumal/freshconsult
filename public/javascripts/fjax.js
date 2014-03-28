!function ($) {

"use strict";

window.FreshdeskPjax = function() {
	this.beforeNextPage = null,
	this.afterNextPage = null,
	this.unload = null,
	this._prevAfterNextPage = null,
	this.bodyClass = null,
	this._prevBodyClass = null;
}

FreshdeskPjax.prototype = {

    constructor: FreshdeskPjax,

    callBeforeSend: function(evnt,xhr,settings,options) {

      $.xhrPool_Abort();
      this._beforeSendExtras(evnt,xhr,settings,options);

    	if(this._triggerUnload() === false) return false;
    	this._beforeSendCleanup();

	    if(typeof(this.beforeNextPage) == 'function') {
	    	if(this.beforeNextPage() === false) return false;
	    }
	    this.beforeNextPage = null;

	    if(typeof(this.afterNextPage) == 'function') this._prevAfterNextPage = this.afterNextPage;
	    this.afterNextPage = null;

	    if(this.bodyClass) this._prevBodyClass = this.bodyClass;
	    this.bodyClass = null;

    	this._setLoading();
    	return true;
    },

    callBeforeReplace: function(settings) {
      $(settings.target).data('twipsy','');
    	if(typeof(this._prevAfterNextPage) == 'function') this._prevAfterNextPage();
    	this._prevAfterNextPage = null;
      Fjax.current_page = '';
      $('[data-keybinding]').expire();
      if (typeof soundManager != "undefined"){
        soundManager.stopAll();
      }
    },

    callAfterReceive: function() {
    	this._removeLoading();
    	this._afterReceiveCleanup();

    	var body = $(body);
    	if(this._prevBodyClass != this.bodyClass)
    		body.removeClass(this._prevBodyClass).addClass(this.bodyClass);
    	this._prevBodyClass = null;
    	$('body').trigger('pjaxDone');
    },

    callAtEnd: function() {
      $(window).unbind('.pageless');
      if(typeof(this.end) == 'function') this.end();
      this.end = null;

    },

    _setLoading: function() {
      NProgress.set(0);
      NProgress.set(0.4);
      NProgress.set(0.5);
      NProgress.set(0.6);
      NProgress.set(0.7);
      NProgress.set(0.8);
    },

    _triggerUnload: function() {
    	if(typeof(this.unload) == 'function') {
	    	var unload = this.unload();
	    	this.unload = null;
	    	if(typeof(unload) == 'string'){
	    		unload += "\n\n Are you sure you want to leave this page?";
	    		return confirm(unload);
	    	}
	    }
    },

    _removeLoading: function() {
      NProgress.done();
      setTimeout(NProgress.remove, 500);
    },

    _beforeSendExtras: function(evnt,xhr,settings,options) {
      var start_time = new Date();
      var bHeight = $('#body-container').height(),
          clkdLI = $(evnt.relatedTarget).parent();
      $('ul.header-tabs li.active').removeClass('active');
      clkdLI.addClass('active');
      this._initParallelRequest($(evnt.relatedTarget),options.data)
    },

    callAfterRecieve: function(evnt,xhr,settings) {
      Fjax.callAfterReceive();
      window.destroyScroll();
      if(typeof(window.pjaxPrevUnload) == 'function') window.pjaxPrevUnload();
      window.pjaxPrevUnload = null;
      Fjax.callAtEnd();
      var options = jQuery(document).data();
      jQuery(document).data("requestDone",true);
      if(options.parallelData && $(evnt.relatedTarget).data()){
        $($(evnt.relatedTarget).data().parallelPlaceholder).html(options.parallelData) 
      }
      else if(options.parallelData && settings.data)
      {
        $(settings.data.parallelPlaceholder).html(options.parallelData);
      }
      setupScroll();
    },

    _beforeSendCleanup: function() {
      this._FayeCleanUp();
			$('#cf_cache').remove();
			$('#response_dialog').remove();
			$('.ui-dialog').remove();
			$('#bulkcontent').remove();

      this._disconnectNode();

    },

    _afterReceiveCleanup: function() {
			$('.popover').remove();
			$('.modal:not(.persistent_modal), .modal-backdrop').remove();
			$('.twipsy').remove();
    },

    _FayeCleanUp: function()
    {
      if(window.faye_realtime.fayeClient)
      {
        for(var i=0;i < window.faye_realtime.faye_subscriptions.length;i++)
        { 
          window.faye_realtime.faye_subscriptions[i].cancel();
        }
        window.faye_realtime.faye_subscriptions = [];
        window.faye_realtime.fayeClient.disconnect();
        window.faye_realtime.fayeClient = null;
      }
    },


    _disconnectNode: function() {
      try {
        jQuery(document).trigger('disconnectNode');
      } catch(err) {
        console.log('Unable to disconnect the socket connection');
        console.log('Error:');
        console.log(err);
      }
    },
    success : function()
    {
      window.history.state.body_class = $('body').attr('class');
      window.history.replaceState(window.history.state,'for_pjax');
    },

    _initParallelRequest: function(target,data){

      jQuery(document).data("requestDone",false);
      jQuery(document).data("parallelData",undefined);
      
      if((!target.data('parallelUrl')) && (!data)){
        return;
      }
      var options ;
      if(target.data('parallelUrl')) {
        options = target.data();  
      } else {
        options = data;
      }
      console.log('the parallelUrl is '+options.parallelUrl);
      if(options.parallelUrl !== undefined)
      {
        jQuery.get(options.parallelUrl, function(data){
          if(jQuery(document).data("requestDone")){ 
            jQuery(options.parallelPlaceholder).html(data);
          }
          else{
            jQuery(document).data("parallelData",data);
          }
        })
      }
    }
}


//Not using pjax for IE10- Temporary fix for IE pjax load issue
//in dashboard and tickets filter. Remove the condition once we get permanent fix
if (!$.browser.msie) {
  $(document).pjax('a[data-pjax]',{
      timeout: -1,
      push : true,
      maxCacheLength: 0,
      replace: false
    }).bind('pjax:beforeSend',function(evnt,xhr,settings,options){
      // BeforeSend
      return Fjax.callBeforeSend(evnt,xhr,settings,options);
  }).bind('pjax:beforeReplace',function(evnt,xhr,settings){
    Fjax.callBeforeReplace(settings);
  }).bind('pjax:end',function(evnt,xhr,settings){
    //AfterReceive
    Fjax.callAfterRecieve(evnt,xhr,settings);
    return true;
  }).bind('pjax:success',function(evnt,xhr,settings){
     Fjax.success();
   });
}

var PJAX_DEFAULTS = {timeout: -1,
                  push : true,
                  maxCacheLength: 0,
                  replace: false,
                  container: '#body-container'}

window.pjaxify = function(url) {
  $.pjax($.extend({}, PJAX_DEFAULTS, {url : url} ));
}

}(window.jQuery);
Fjax = new FreshdeskPjax();