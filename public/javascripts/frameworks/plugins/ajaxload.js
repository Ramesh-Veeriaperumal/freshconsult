(function($){
	"use strict";

	/* 
	 *	==== AjaxLoad class definition ====
  	 */

  	var AjaxLoad = function(element, options){
		this.element = element;
		this.options = $.extend({}, $.fn.ajaxLoad.defaults, options, $(element).data());
		this.init();
    };

	AjaxLoad.prototype = {
	    init: function() {	
		var $this = this;
		$.ajax({
			type: this.options.type,
			url: this.options.url, 
			dataType: 'html',
			success: function(html){
				$($this.element).html(html);
				$this.options.successCallback();
			}
		});
	   }
	}

  	/* 
  	 *  ==== AjaxLoad plugin definition ====
   	 */

	$.fn.ajaxLoad = function(option) {
		return this.each(function() {
			 new AjaxLoad(this, option);
		});
	}

	// Menu selection default values
	$.fn.ajaxLoad.defaults = {
		type: 'GET',
		url: '#',
		successCallback: function(){}

	}

})(window.jQuery);