/*jslint browser: true */
/*global AddClear:true */

(function ($) {
    "use strict";
	
	/* ADD CLEAR PUBLIC CLASS DEFINITION
	* ========================================= */
	
    var AddClear = function (element, options) {
        this.element = $(element);
        this.options = options;
        this.initialize();
    };
    
    AddClear.prototype = {
        constructor: AddClear,
		
		initialize: function () {
			this.appendElements();
			this.bindAddAllClear();
			this.bindDisableLinks();
		},
		
        namespace: function () {
            return '.addclear';
        },

        appendElements: function () {
            var add_link = "<a href='' class='add-all' data-target='#" + this.element.attr('id') + "'>" + this.options.add_text + "</a>",
				clear_link = "<a href='' class='clear-all' data-target='#" + this.element.attr('id') + "'>" + this.options.clear_text + "</a>";
            this.element.after("<span class='add-clear'></span>");
            $(this.element).parent().find('.add-clear').append([add_link, clear_link]);
        },

        bindAddAllClear: function () {
            var $this = this;
            $('[data-target=#' + this.element.attr('id') + ']').on('click' + $this.namespace(), function (ev) {
                ev.preventDefault();
                var target_select = $(this).data('target'), vals = ($(this).attr('class') === 'clear-all') ? [''] :
                                    $(target_select + ' option').map(function () { return $(this).val(); });
                $(target_select).select2('val', vals, true);
                setTimeout(function(){
                    $(target_select).select2('close');
                }, 10);
            });
        },

        bindDisableLinks: function () {
            var $this = this;
            $this.element.on("change" + $this.namespace(), function () {
                var vals = $(this).find('option').map(function () { return $(this).val(); });
                $(this).parent().find('.add-all').toggleClass('disabled', ($(this).val() || []).length === vals.length);
                $(this).parent().find('.clear-all').toggleClass('disabled', ($(this).val() || []).length === 0);
            }).trigger('change' + $this.namespace());
        },
        
        destroy: function () {
            $('body').off(this.namespace());
        }
    };
	
	/* ADD CLEAR PLUGIN DEFINITION
	* =================================== */
	
	$.fn.add_clear = function (options) {
        var opts = $.extend({}, $.fn.add_clear.defaults, options);
		$(this).data("add_clear", new AddClear(this, opts));
	};
	
	$.fn.add_clear.defaults = {
		add_text: "Add all",
		clear_text: "Clear"
	};
	
	$.fn.add_clear.Constructor = AddClear;
	
}(window.jQuery));