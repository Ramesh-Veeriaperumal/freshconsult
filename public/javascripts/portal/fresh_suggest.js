/*jslint browser: true */
/*global FreshSuggestions:true, delay */

(function ($) {
    "use strict";
	
	/* FRESH SUGGESTION PUBLIC CLASS DEFINITION
	* ========================================= */
	
    var FreshSuggestions = function (element, options) {
        this.element = $(element);
        this.options = options;
        this.currentString = "";
        this.initialize();
    };
    
    FreshSuggestions.prototype = {
        constructor: FreshSuggestions,
        
        SLIDE_RIGHT: '0',
        SLIDE_LEFT: '100%',
        DELAY_TIME: 1000,
		
		initialize: function () {
            this.appendElements();
            this.initializePopover();
            this.bindHandlers();
        },
        namespace: function () {
            return '.suggestions';
        },
        appendElements: function () {
            this.buildElements();
			this.element.after([this.results_list, this.mobile_list]);
        },
        buildElements: function () {
            this.mobile_list = $("<div class='hide-desktop'><a href='' class='hide show_results'>" + this.options.text + "</a></div>");
            this.results_list = $("<div class='hide'></div>");
            this.close_btns = "<div class='pull-right close-popover-mobile'></div><div class='pull-right close-popover'></div>";
        },
        initializePopover: function () {
            var $this = this;
            this.element.popover({
                html: true,
                content: function () { return $this.close_btns + $this.results_list.html(); },
                trigger: 'manual'
            });
            this.popover = this.element.data("popover");
        },
        bindHandlers: function () {
            this.bindKeyup();
            this.bindClosebtn();
            this.slideMobileresults();
        },
        bindKeyup: function () {
            var $this = this;
            $this.element.on('keyup' + $this.namespace(), function (ev) {
                var searchString = this.value.replace(/^\s+|\s+$/g, "");
                if ($this.isNextsearch(searchString)) {
					$this.mobile_list.find('a').hide();
					$this.element.addClass('loading-right');
                    $this.refreshPopover(searchString);
                }
            });
        },
        isNextsearch: function (searchString) {
            return (searchString !== '' && searchString.length > 1 && this.currentString !== searchString);
        },
        refreshPopover: function (searchString) {
            var $this = this;
            delay(function () {
                $this.currentString = searchString;
                $this.refreshResults();
            }, $this.DELAY_TIME);
        },
        bindClosebtn: function () {
            var $this = this;
            $('body').on('click' + $this.namespace(), '.close-popover', function (ev) {
                ev.preventDefault();
                $this.hidePopover();
            });
            $('body').on('click' + $this.namespace(), '.close-popover-mobile', function (ev) {
                ev.preventDefault();
                $this.animateMobile($this.SLIDE_LEFT, 'scroll');
            });
        },
        refreshResults: function () {
            var $this = this;
            $.ajax({
                url: $this.options.suggestions,
                type: "get",
                data: {
                    term: $this.currentString,
                    max_matches: $this.options.maxMatches
                },
                success: function (data) {
                    $this.results_list.html(data);
                    if ($.trim(data) !== "") {
                        $this.showPopover();
                    } else {
                        $this.hidePopover();
                    }
                    $this.setMobiletext();
                }
            });
        },
        showPopover: function () {
            this.element.popover('show');
            var popoverPosition = { top: this.options.topPosition, left: this.options.leftPosition};
            this.popover.$tip.css(popoverPosition);
        },
        hidePopover: function () {
            if (this.popover && this.popover.$tip) {
                this.popover.$tip.hide();
            }
        },
        animateMobile: function (width, overflow) {
            if (this.popover) {
                $('body').css('overflow', overflow);
                this.popover.$tip.animate({marginLeft: width}, this.options.slideSpeed);
            }
        },
        setMobiletext: function () {
			this.element.removeClass('loading-right');
            if (this.results_list.html() !== "") {
				this.mobile_list.find('a').show();
            }
        },
        slideMobileresults: function () {
            var $this = this;
            $('body').on('click' + $this.namespace(), '.show_results', function (ev) {
                ev.preventDefault();
                $this.animateMobile($this.SLIDE_RIGHT, 'hidden');
            });
        },
        destroy: function () {
            $('body').off(this.namespace());
        }
    };
	
	/* FRESH SUGGESTION PLUGIN DEFINITION
	* =================================== */
	
	$.fn.fresh_suggestion = function () {
        var opts = $.extend({}, $.fn.fresh_suggestion.defaults, $(this).data());
		if (!$(this).data('fresh_suggestion') && $(this).data('suggestions')) {
			$(this).data("fresh_suggestion", new FreshSuggestions(this, opts));
		}
	};
	
	$.fn.fresh_suggestion.defaults = {
		maxMatches: 5,
		slideSpeed: 500,
		text: 'Matching results found',
		leftPosition: null,
		topPosition: null
	};
	
	$.fn.fresh_suggestion.Constructor = FreshSuggestions;
	
}(window.jQuery));