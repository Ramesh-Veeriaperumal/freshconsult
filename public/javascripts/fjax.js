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

    callBeforeSend: function() {

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

    callAfterReceive: function() {
    	this._removeLoading();
    	this._afterReceiveCleanup();
    	if(typeof(this._prevAfterNextPage) == 'function') this._prevAfterNextPage();
    	this.after = null;

    	var body = $(body);
    	if(this._prevBodyClass != this.bodyClass)
    		body.removeClass(this._prevBodyClass).addClass(this.bodyClass);
    	this._prevBodyClass = null;
    },

    callAtEnd: function() {
      $(window).unbind('.pageless');
      if(typeof(this.end) == 'function') this.end();
      this.end = null;

      $('body').addClass(this.bodyClass); //Failover
    },

    _setLoading: function() {
      $('.top-loading-wrapper').switchClass('fadeOutRight','fadeInLeft',100,'easeInBounce',function(){
        $('.top-loading-wrapper').removeClass('hide');
      });
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
    	console.log('about to hide the loading bar');
      $('.top-loading-wrapper').switchClass('fadeInLeft','fadeOutRight');
      $('.top-loading-wrapper').addClass('hide','slow');
      console.log('loading shd be hidden now');
    },

    _beforeSendCleanup: function() {
			$('#cf_cache').remove();
			$('#response_dialog').remove();
			$('.ui-dialog').remove();
			$('#bulkcontent').remove();
    },

    _afterReceiveCleanup: function() {
    	$('.popover').remove();
    	$('.twipsy').remove();
    }
}
}(window.jQuery);
Fjax = new FreshdeskPjax();