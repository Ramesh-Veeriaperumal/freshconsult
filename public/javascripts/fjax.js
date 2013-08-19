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

    callBeforeReplace: function() {
    	if(typeof(this._prevAfterNextPage) == 'function') this._prevAfterNextPage();
    	this._prevAfterNextPage = null;
    },

    callAfterReceive: function() {
    	this._removeLoading();
    	this._afterReceiveCleanup();
    },

    callAtEnd: function() {
      $(window).unbind('.pageless');
      if(typeof(this.end) == 'function') this.end();
      this.end = null;

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
      $('.top-loading-wrapper').switchClass('fadeInLeft','fadeOutRight');
      $('.top-loading-wrapper').addClass('hide','slow');
    },

    _beforeSendCleanup: function() {
			$('#cf_cache').remove();
			$('#response_dialog').remove();
			$('.ui-dialog').remove();
			$('#bulkcontent').remove();

      this._disconnectNode();

    },

    _afterReceiveCleanup: function() {
			$('.popover').remove();
			$('.modal').remove();
			$('.twipsy').remove();
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
      window.history.replaceState(window.history.state);
    }
}


// Sticky Header
var the_window = $(window),
    hasScrolled = false;
the_window.on('scroll.freshdesk', function() { hasScrolled = true; });
var handleScroll = function() {
  if (the_window.scrollTop() > REAL_TOP) {
    if (!fixedStrap.hasClass('at_the_top')) {

      at_the_top.addClass('at_the_top');
      forFixed.show();
      at_the_top.css({top: -outerHeight}).animate({ top: 0}, 300, 'easeOutExpo');
      firstchild.addClass('firstchild');
    }

  } else {
    at_the_top.removeClass('at_the_top').css({top: ''});
    forFixed.hide();
    firstchild.removeClass('firstchild');
  }

  hasScrolled = false;
};


var setupScroll = function() {
  if(!$('#sticky_header').length) return;

  var the_window = $(window),
      sticky_header = $('#sticky_header');

  var hasScrolled = false,
      REAL_TOP = sticky_header.offset().top;


  var handleScroll = function() {
    if(the_window.scrollTop() > REAL_TOP) {
      if(!sticky_header.hasClass('stuck')) {
        sticky_header.addClass('stuck');
        sticky_header.wrap('<div id="sticky_wrap" />');
        $('#sticky_wrap').height(sticky_header.outerHeight());
        
        $('#scroll-to-top').addClass('visible');
      }

    } else {
      if(sticky_header.hasClass('stuck')) {
        sticky_header.removeClass('stuck');
        sticky_header.unwrap();
        
        $('#scroll-to-top').removeClass('visible');
      }
    }

    hasScrolled = false;
  }
  the_window.on('scroll.freshdesk', handleScroll);

  $(window).on('resize.freshdesk', function() {

    sticky_header.width($('#Pagearea').width());
    var to_collapse = false, extra_buffer = 20;

    var width_elements_visible = $('.sticky_right').outerWidth() + $('.sticky_left').outerWidth() + extra_buffer;

    if(sticky_header.hasClass('collapsed')) {
      var hidden_elements_width = 0;
      sticky_header.find('.hide_on_collapse').each(function() {
        hidden_elements_width += $(this).outerWidth();
      });
      if(sticky_header.width() < (width_elements_visible + hidden_elements_width)) {
        to_collapse = true;
      }
    } else {
      to_collapse = sticky_header.width() < width_elements_visible;
    }
    sticky_header.toggleClass('collapsed', to_collapse);
    
  }).trigger('resize');

};


var destroyScroll = function() {
  $(window).off('scroll.freshdesk');
  $(window).off('resize.freshdesk');
}


setupScroll();

//Not using pjax for IE10- Temporary fix for IE pjax load issue
//in dashboard and tickets filter. Remove the condition once we get permanent fix
if (!$.browser.msie) {
  $(document).pjax('a[data-pjax]',{
      timeout: -1,
      push : true,
      maxCacheLength: 0,
      replace: false
    }).bind('pjax:beforeSend',function(evnt,xhr,settings){
      $.xhrPool_Abort(); 
      jQuery(document).data("requestDone",false);
      jQuery(document).data("parallelData",undefined);
      var start_time = new Date();
      var bHeight = $('#body-container').height(),
          clkdLI = $(evnt.relatedTarget).parent();
      $('ul.header-tabs li.active').removeClass('active');
      clkdLI.addClass('active');
      initParallelRequest($(evnt.relatedTarget))

      // BeforeSend
      return Fjax.callBeforeSend();
  }).bind('pjax:beforeReplace',function(evnt,xhr,settings){
    Fjax.callBeforeReplace();
  }).bind('pjax:end',function(evnt,xhr,settings){
    //AfterReceive
    Fjax.callAfterReceive();

    destroyScroll();
    if(typeof(window.pjaxPrevUnload) == 'function') window.pjaxPrevUnload();
    window.pjaxPrevUnload = null;
    
    /*var end_time = new Date();
    setTimeout(function() {
      $('#benchmarkresult').html('Finally This page took ::: <b>'+(end_time-start_time)/1000+' s</b> to load.') 
    },10);*/
    Fjax.callAtEnd();
    var options = jQuery(document).data();
    jQuery(document).data("requestDone",true);
    if(options.parallelData && $(evnt.relatedTarget).data()){
      $($(evnt.relatedTarget).data().parallelPlaceholder).html(options.parallelData) 
    }
    setupScroll();
    return true;
  }).bind('pjax:success',function(evnt,xhr,settings){
     window.history.state.body_class = $('body').attr('class');
     window.history.replaceState(window.history.state,'title');
   });

}
}(window.jQuery);
Fjax = new FreshdeskPjax();