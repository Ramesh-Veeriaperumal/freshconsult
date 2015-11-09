(function($){
"use strict";

/* 
 *  ==== CollapseButton class definition ====
 *
 * we have external classes
 * 1) [ .collapse_on_default ] is to add default elemant in dropdown list( More button ).
 * 2) [ .hide_on_collapse ] and [ .show_on_collapse ] is to show / hide the element in collapse list
 *
 */

var CollapseButton = function(element, options){
	this.element = element;
	this.options = $.extend({}, $.fn.collapseButton.defaults, options, $(element).data());
	this.collapseContainer = $(element).find('.collapse-content')
	this.buttonContent = "";

	this.template = '<div class="btn-group" id="more-btn">' +
						'<a class="btn dropdown-toggle" data-toggle="dropdown"> ' +  this.options.buttonText +
							'<span class="caret"></span>' +
						'</a>' + 
						'<ul class="dropdown-menu" id="collapse-list" role="menu" style="display:none"></ul>' +
					'</div>'

	this.init();
}

CollapseButton.prototype = {

	init: function() {  
		this.constructDefaultList();
		$(window).on('resize.collapseButton', $.proxy(this.resize, this)).trigger('resize');
	},

	resize: function(){
		var _element = (this.options.calcParentWidthOn) ? $(this.options.calcParentWidthOn) : $(this.element);

		//Extra buffer
		var width_elements_visible = this.options.extraBuffer,
			to_collapse = false;

		_element.children().each(function(){
			width_elements_visible += $(this).outerWidth(false);
		});

		if(_element.hasClass('collapsed')) {
			var hidden_elements_width = 0;

			_element.find('.hide_on_collapse').each(function() {
				hidden_elements_width += $(this).outerWidth(false);
			});

			if(_element.width() < (width_elements_visible + hidden_elements_width)) {
				to_collapse = true;
			}

		} else {
			to_collapse = _element.width() <= width_elements_visible;
		}

		this.constructOnResize(to_collapse);

		_element.toggleClass('collapsed', to_collapse);
	},

	constructOnResize: function(to_collapse){
		if(!this.options.showByDefault){
			var btn_group = $(this.collapseContainer).find('#more-btn')


			if(to_collapse && !btn_group.get(0)){
				$(this.collapseContainer).append(this.buttonContent)
			}

			if(btn_group.get(0)){
				btn_group.parent().toggleClass('hide', !to_collapse);
			}
		}
	},

	constructDefaultList: function(){
		var _self = this,
			defaultEle = $(this.collapseContainer).find('.collapse_on_default'),
			hiddenCollapseEle = $(this.collapseContainer).find('.hide_on_collapse');

		var	template = $("<div />").append(this.template).addClass(this.options.classForBtnWrapper),
			list = template.find('#collapse-list');

		if(defaultEle.get(0)){

			defaultEle.each(function(){
				var self_clone = $(this).clone(true).removeClass('collapse_on_default');

				list.append(self_clone);
			})
		}

		if(hiddenCollapseEle.get(0)){

			hiddenCollapseEle.each(function(){
				var self_clone = $(this).clone(true);

				if(self_clone.children().get(0)){
					var child_element = self_clone.find(_self.options.collapseElementClass),
					list_item = _self.createListItem(child_element);

					list.append(list_item);
				} else {
					var list_item = _self.createListItem(self_clone);

					list.append(list_item);
				}
			})
		}

		this.buttonContent = template;

		if(this.options.showByDefault){
			$(this.collapseContainer).append(this.buttonContent)
		}
	},

	createListItem: function(element){
		var attrObject = this.getAttributes(element),
			temp_list = $('<li />', { class: "show_on_collapse"});

		temp_list.append( $('<a />', attrObject) ) 
		return temp_list;
	},

	getAttributes: function(element){
		var attrObject = {};

		$.each(element.get(0).attributes, function(i, attr){
			attrObject[attr.name] = attr.value;
		})

		attrObject['class'] = "";
		attrObject['disabled'] = false;
		attrObject['text'] = (element.val()) ? element.val() : element.text();

		return attrObject;
	},

	destroy: function(){
		$(this.element).off(".collapseButton").removeData("collapseButton");
		$(window).off("resize.collapseButton");
	}
}

$.fn.collapseButton = function(option) {
	return this.each(function() {
		var $this = $(this),
		data    = $this.data("collapseButton"),
		options   = typeof option == "object" && option
		if (!data) $this.data("collapseButton", (data = new CollapseButton(this,options)))
		if (typeof option == "string") data[option]() 
	});
}

$.fn.collapseButton.defaults = {
	// Butten text
	buttonText: "More",
	// It will show the collapse button(Dropdown btn) by default
	showByDefault: true,
	// Can add class to collapse button(Dropdown btn)
	classForBtnWrapper: "btn-collapse-group",
	// Have to give the immediate parent id / class for the collapse buttons
	calcParentWidthOn: "",
	// If the button has parent element, should have add class to the buttons
	collapseElementClass: ".btn-collapse",
	// Adding extra pixels to calculate the collapse buttons
	extraBuffer: 25
}

})(window.jQuery);