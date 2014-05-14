(function ($) {
    'use strict';

    	var keywords = $.map(adminSearchKeywords, function (value, key) { return { value: key, data: value }; });
	    
	    $('#admin_search').autocomplete({
	        lookup : keywords,
	        triggerSelectOnValidInput : false,
	        appendTo : '#suggestions-container',
	        minChars : 2,
	        emptyResult : 'No matching results',
	        onSelect : function (suggestion) {
	            $('<a></a>')
	                .attr('href', suggestion.data[0])
	                .appendTo('body')
	                .get(0)
	                .click();
	        },
	        lookupFilter : function (suggestion, query, queryLowerCase) {
	        	var query = queryLowerCase.split(' '),
	        		keyword = suggestion.value.toLowerCase().trim(),
	        		meta = suggestion.data[2],
	        		matchCount = 0;

	        	query.forEach(function (item) {

	        		// checks match occurence in Keyword
	        		if (keyword.indexOf(item) > -1) {
        				matchCount++;
        				return;
        			}

        			// checks match occurence Keyword metas
        			if (meta && typeof meta === 'object') {
	        			meta.forEach(function (kwMeta) {
	        				if (kwMeta.toLowerCase().trim().indexOf(item) > -1) {
		        				matchCount++;
		        				return false;
		        			}
	        			});
	        		}
	        	});

	        	return matchCount >= query.length;
	    	},
	        formatResult : function (suggestion, currentValue) {
	            var patn = new RegExp(suggestion.value, 'gi'),
	            	curAdminItem = $('.' + suggestion.data[1]).parentsUntil('.admin_icons', 'li');
	            
	            if (patn.test(currentValue)) {
	                curAdminItem
	                	.removeClass('hide')
	                	.addClass('exact-match');
	                return suggestion.value;
	            }

	            curAdminItem
	            	.removeClass('hide')
	            	.addClass('related-match');
	            return suggestion.value;
	        },
	        onHint: function (hint) {
	        	$('#admin_search_hint').val(hint);
	        },
	        onSearchStart: function () {
	        	var that = this;
	        	
	        	if (that.el.val().trim().length >= that.options.minChars) {
	        		$('.admin_icons').children('li').addClass('hide');
	        	} else {
	        		$('.admin_icons').children('li').removeClass('hide');
	        	}

	        	$('.related-match, .exact-match').removeClass('related-match exact-match');
	    	},
	    	onSearchComplete: function () {
	    		var that = this;

	    		// Hide/show the section, if section is empty
	    		$('.admin_icons').each(function () {
	    			var hideParent = false;
	    			
	    			$(this).children().each(function () {
	    				if($(this).is(':visible')) { 
	    					hideParent = true;
	    					return false;
	    				}
	    			});
	    			
	    			if (hideParent) {
	    				$(this).parent().removeClass('blur');
	    			} else {
	    				$(this).parent().addClass('blur');
	    			}
	    		});
	    	},
			addEvents: function (container, suggestionSelector, selected) {
				var obj = this,
					searchInpt = obj.el;

				// Events for suggestion container
				container.on(
					{
						'mouseout.autocomplete' : function () {
							if (container.children('.' + selected).length > 0) {
								$('.' + container.children('.' + selected).data('currentItem').split(',')[1])
									.parentsUntil('.admin_icons', 'li')
									.removeClass('exact-match');
							}
						},
						'mouseover.autocomplete' : function () {
							$('.' + container.children('.' + selected).data('currentItem').split(',')[1])
								.parentsUntil('.admin_icons', 'li')
								.removeClass('hide')
								.addClass('exact-match');
						}
					}, suggestionSelector
				);

				// Events for Search input
				searchInpt.on({
					'keydown.autocomplete' : function (ev) {
						var	up = 38,	// pressed up key
							down = 40;	// pressed down key
	
						if (ev.which == up && obj.selectedIndex === -1) {
							$('.exact-match').removeClass('exact-match');
						} else if ((container.children('.' + selected).length > 0) && (ev.which == up || ev.which == down)) {
							$('.exact-match').removeClass('exact-match');
							$('.' + container.children('.' + selected).data('currentItem').split(',')[1])
								.parentsUntil('.admin_icons', 'li')
								.removeClass('hide')
								.addClass('exact-match');
						}
					},
					'keyup.autocomplete' : function (ev) {
						var that = this;

						if ($(this).val().trim().length < 1) {
							$('.as-clear')
								.unbind('click')
								.hide();

							return false;
						}

						// Clear search field
						if(!$('.as-clear').is(':visible')) {
							$('.as-clear')
								.css({ 'display' : 'inline-block' })
								.bind('click', function (ev) {
									ev.preventDefault();
									$('.admin_icons li, .related-match, .exact-match, .blur').removeClass('hide related-match exact-match blur');
									$(that).val('').trigger('focus');
									$(this).hide();
								});
						}
					}
				});
			}
	    });

}(jQuery));