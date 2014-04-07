(function($){
	"use strict";

	/* 
	 *	==== MenuSelector class definition ====
  	 */

  	var MenuSelector = function(element, options){
		this.element = element;
		this.options = $.extend({}, $.fn.menuSelector.defaults, options, $(element).data());
		this.selectElement = []; 

		this.init();
		this.reset();
		$(element).attr("tabindex", -1).focus();
		$(this.selectElement).first().addClass(this.options.activeClass);	
    };

	MenuSelector.prototype = {
	    init: function() {	    	
			var selectEle = this.options.menuHoverIn,
			 	keybind   =  this.options.scrollInDocument ? document : this.element;

			if(this.options.onHoverActive){
				$(this.element)
					.on("mouseenter.menuSelector", selectEle ,$.proxy(this.mouseenter, this))
			}
			
			$(keybind).on("keydown.menuSelector", $.proxy(this.keydown, this))	
	    },	    
		reset: function(){ 
			this.selectElement 	= $(this.element).find(this.options.menuHoverIn); 
			var index =  $(this.selectElement).index($(this.selectElement).filter("."+this.options.activeClass))
			this.currentIndex 	= (index == -1) ? 0 : index;
			this.currentElement = $(this.selectElement).eq(this.currentIndex);
			this.totalItems 	= this.selectElement.length;
		},
		keydown: function(ev){			
	    	// Checking if the up : 38 / down : 40 key is pressed
	   		if (!/(38|40)/.test(ev.keyCode)) return

	   		ev.preventDefault()
			ev.stopPropagation()	

			var currentIndex = this.currentIndex,
				activeClass  = this.options.activeClass 

			$(this.selectElement).eq(currentIndex).removeClass(activeClass);

			if (ev.keyCode == 38 && currentIndex > 0) currentIndex--
	  		if (ev.keyCode == 40 && currentIndex < this.totalItems - 1) currentIndex++

	  		this.currentElement = $(this.selectElement).eq(currentIndex).addClass(activeClass);	  		
	 		this.scrollElement();
	 		this.currentIndex = currentIndex;

			//Checking callback function for last element 
			if (typeof this.options.afterLastItem == "function" && currentIndex == this.totalItems - 1) {
				this.options.afterLastItem.call(this); 
			} 

	    },
	    mouseenter: function(ev){
	    	$(this.element).find(this.options.menuHoverIn).removeClass(this.options.activeClass)
	 	    $(ev.currentTarget).addClass(this.options.activeClass);
	 	    this.currentIndex = $(ev.currentTarget).index();
	    },    
	    scrollElement: function(){
			var ele 		 = this.options.scrollInDocument ? document : this.element,
				current_el	 = this.currentElement,
				docTop 	     = $(ele).scrollTop(),
				frameEle 	 = (ele == document) ? window : this.element,			    
			    itemSltrTop  = (ele == document) ? current_el.offset().top : current_el[0].offsetTop,
			    itemSltrBotm = itemSltrTop + current_el.height(),
			    frame 		 = $(frameEle).height() + docTop,
			    percent 	 = this.options.scrollPercent, 
			    scrollTo 	 = Math.floor($(frameEle).height() * percent / 100);

		    if (itemSltrBotm <= docTop || itemSltrTop >= frame) {
		        $(ele).scrollTop(current_el.offset().top);
		    } else if (itemSltrBotm >= frame) {
		        $(ele).scrollTop((docTop + scrollTo));
		    } else if (itemSltrTop <= docTop) {
		        $(ele).scrollTop((docTop - scrollTo));
		    }   
		},
	    destroy: function(){
	    	$(this.element).find(this.options.menuHoverIn).removeClass(this.options.activeClass)
	    	$(this.element).off(".menuSelector").removeData("menuSelector");
	    	$(document).off("keydown.menuSelector");
	    }
	}

  	/* 
  	 *  ==== MenuSelector plugin definition ====
   	 */

	$.fn.menuSelector = function(option) {
		return this.each(function() {
			var $this = $(this),
			data 	  = $this.data("menuSelector"),
			options   = typeof option == "object" && option
			if (!data) $this.data("menuSelector", (data = new MenuSelector(this,options)))
			if (typeof option == "string") data[option]()	
		});
	}

	// Menu selection default values
	$.fn.menuSelector.defaults = {
		activeClass: "active",

		// Will make the currently hovered element as the active menu element
		onHoverActive: true,		
		// We can pass advanced class selectors such as "li:not(.divider)"
		menuHoverIn : "li",		
		// Callback function that will invoke when the last element in the menu is reached
		afterLastItem: "",
		// To check which item to scroll when moving to a menu not available in the viewport
		scrollInDocument: false,
		scrollPercent: 50
	}

})(window.jQuery);