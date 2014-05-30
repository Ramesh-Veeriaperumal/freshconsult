(function($){
	"use strict";

	/* 
	 *	==== MenuSelector class definition ====
  	 */

  	var MenuSelector = function(element, options){
		this.element = element;
		this.options = $.extend({}, $.fn.menuSelector.defaults, options, $(element).data());
		this.selectElement = []; 
		this.upKeys = [ 38 ]; // default up arrow key
		this.downKeys = [ 40 ]; // default down arrow key
		this.keys = [ 13 ]; // all key combos. Default key "Enter : 13"

		this.init();
		this.reset();
    };

	MenuSelector.prototype = {
	    init: function() {	    	
			var selectEle = this.options.menuHoverIn,
			 	keybind   =  this.options.scrollInDocument ? document : this.element;

			this.upKeys = this.keycombos(this.upKeys, this.options.additionUpKeys);
			this.downKeys = this.keycombos(this.downKeys, this.options.additionDownKeys)
			this.keys = this.keys.concat(this.upKeys, this.downKeys); 	

			if(this.options.onHoverActive){
				$(this.element)
					.on("mouseenter.menuSelector", selectEle ,$.proxy(this.mouseenter, this))
			}
			if(this.options.onClickActive){
				$(this.element)
					.on("click.menuSelector", selectEle ,$.proxy(this.clickEvent, this))
			}
			
			$(keybind).on("keydown.menuSelector", $.proxy(this.keydown, this))	

			if(keybind != document) $(keybind).attr("tabindex", 1).focus();
	    },	
	    // Reset all values    
		reset: function(){ 
			this.selectElement 	= $(this.element).find(this.options.menuHoverIn); 
			var index =  $(this.selectElement).index($(this.selectElement).filter("."+this.options.activeClass))
			this.currentIndex 	= (index == -1) ? 0 : index;
			this.currentElement = $(this.selectElement).eq(this.currentIndex);
			this.totalItems 	= this.selectElement.length;
			if(this.currentIndex == 0) $(this.selectElement).eq(this.currentIndex).addClass(this.options.activeClass)
		},
		keydown: function(ev){		
	    	// Checking if pressed key in keycombo and check if the focused in input fields
   			if( $.inArray(this.keys, ev.keyCode) && !this.stopOnFocus() ){
   				var currentIndex = this.currentIndex,
				activeClass  = this.options.activeClass 

				//check if the enter : 13 key is pressed
				if(ev.keyCode == 13){
					this.triggerEvent();
				} 	

				$(this.selectElement).eq(currentIndex).removeClass(activeClass);

				if ($.inArray(ev.keyCode, this.upKeys) != -1 &&  currentIndex > 0 ) { 
					this.stopBubbling(ev);
					currentIndex-- ;
				} 
		  		else if ($.inArray(ev.keyCode, this.downKeys) != -1 && currentIndex < this.totalItems - 1 ) { 
		  			this.stopBubbling(ev);
		  			currentIndex++ ;
		  		}

		  		this.currentElement = $(this.selectElement).eq(currentIndex).addClass(activeClass);	  		
		 		this.scrollElement();
		 		this.currentIndex = currentIndex;

				//Checking callback function for last element 
				if (typeof this.options.afterLastItem == "function" && currentIndex == this.totalItems - 1) {
					this.options.afterLastItem.call(this); 
				} 
   			}
	    },
	    clickEvent: function(ev){
	    	var clickedItemIndex;
	    	// find the current triggered element index
	    	if($(ev.target).hasClass(this.options.activeClass)){
				clickedItemIndex = $(ev.target).index();
			}else{
				clickedItemIndex = $(ev.target).parents(this.options.menuHoverIn).index();
			}
			this.setCurrentElement(clickedItemIndex)   
			this.options.onClickCallback.call(this,this.currentElement); 
	    },
	    // set the selector to first element
	    setFirstSelector: function(){
	 	   this.setCurrentElement(0)   
	    },
	    mouseenter: function(ev){
	 	   this.setCurrentElement($(ev.currentTarget).index())
	    }, 
	    triggerEvent: function(){
	    	if(this.options.menuTrigger != "")
				this.currentElement.find(this.options.menuTrigger).trigger('click');
			//Callback function for triggered event
			this.options.menuCallback.call(this);
	    }, 
	    //prevents default and stop propagation for this event 
	    stopBubbling: function(ev){
	    	ev.preventDefault(); 
			ev.stopPropagation();
	    },
	    setCurrentElement: function(index){
	    	$("." + this.options.activeClass).removeClass(this.options.activeClass);
	 	    this.currentIndex = index;
	 	    this.currentElement = $(this.selectElement).eq(index).addClass(this.options.activeClass);
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
		keycombos:function(existingKeys, additionalKeys){
			var combo_keys = [];
			if( $.isArray(additionalKeys) ){
				combo_keys = existingKeys.concat(additionalKeys);
			} else if( $.isNumeric(additionalKeys) ){
				combo_keys = existingKeys.concat(additionalKeys);
			} else { 
				var key    = additionalKeys.split(",").map(function(x){return parseInt(x)});
				combo_keys = existingKeys.concat(key);	
			}
			return combo_keys;
		},
		stopOnFocus: function(){
			var element = document.activeElement;
			// stop for input, select, textarea and content editable
            return element.tagName == 'INPUT' || element.tagName == 'SELECT' || element.tagName == 'TEXTAREA' || element.isContentEditable;
		},
	    destroy: function(){
	    	$(this.element).find(this.options.menuHoverIn).removeClass(this.options.activeClass)
	    	$(this.element).off(".menuSelector").removeData("menuSelector");
	    	$(document).off("keydown.menuSelector");
	    },
	    unpause: function(){
	    	$(document).on("keydown.menuSelector", $.proxy(this.keydown, this));
	    },
	    pause: function(){
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
		// Will make the currently hovered element as the active menu element
		onClickActive: false,	
		// Callback function for click event with argument
		onClickCallback: function(element){},	
		// We can pass advanced class selectors such as "li:not(.divider)"
		menuHoverIn : "li",		
		// Callback function that will invoke when the last element in the menu is reached
		afterLastItem: "",
		//Will trigger click event for the current active element 
		menuTrigger:"",
		// Callback function for trigger event
		menuCallback: function(){},
		// Additional keys for up. param can pass as integer or string or Array
		additionUpKeys: [ ],
		// Additional keys for down. param can pass as integer or string or Array
		additionDownKeys: [ ],
		// To check which item to scroll when moving to a menu not available in the viewport
		scrollInDocument: false,
		scrollPercent: 50
	}

})(window.jQuery);