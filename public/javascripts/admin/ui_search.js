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
	        		keyword = suggestion.value.toLowerCase(),
	        		meta = suggestion.data[2],
	        		matchCount = 0;

	        	$.each(query, function(index, val) {
	        		if (keyword.indexOf(val) > -1) {
        				matchCount++;
        				return;
        			}

        			if (meta && typeof meta === 'object') {
	        			$.each(meta, function(index, meta) {
	        				if (meta.toLowerCase().indexOf(val) > -1) {
		        				matchCount++;
		        			}
	        			});
	        		}
	        	});

	        	return matchCount === query.length;
	    	},
	        formatResult : function (suggestion, currentValue) {
	            var patn = new RegExp(suggestion.value, 'gi'),
	            	curAdminItem = $('.' + suggestion.data[1]).parentsUntil('.admin_icons', 'li');
	            
	            if (patn.test(currentValue)) {
	                curAdminItem.addClass('exact-match');
	                return suggestion.value;
	            }

	            curAdminItem.addClass('related-match');
	            return suggestion.value;
	        },
	        onHint: function (hint) {
	        	$('#admin_search_hint').val(hint);
	        },
	        onSearchStart: function () {
	        	var that = this;
	        	
	        	if (that.el.val().trim().length >= that.options.minChars) {
	        		if(!$('.admin_icons').children('li').hasClass('blur')) {
	        			$('.admin_icons').children('li').addClass('blur');
	        		}
	        	} else {
	        		$('.admin_icons').children('li').removeClass('blur');
	        	}
	    	},
	        onSearchComplete: function () {
	        	var that = this,
	        		outOfFrame = false;

	        	if(that.visible){
	        		$(that.suggestionsContainer).children().each(function(){
		        		var curentAdminItem = $(this).data('currentItem').split(',')[1];

		        		if($('.' + curentAdminItem).offset().top > $(document).scrollTop() + $(window).height() - 20) {
		        			if(!$('.as-more').is(':visible')) {
		        				$('.as-more')
			        				.css({
					        			'right'		:	'90px',
					        			'top'		:	$(window).height() - 35 + 'px',
					        			'display'	:	'inline-block'
				        			})
				        			.unbind('click')
				        			.bind('click', function(ev){ ev.preventDefault(); $.scrollTo('.'+curentAdminItem) });
		        			}
		        			outOfFrame = true;
		        			return false;
		        		}
		        	});

		        	if(!outOfFrame) {
		        		$('.as-more').hide();
		        	}

	        	} else {
	        		$('.as-more').hide();
        		}
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
								.addClass('exact-match');
						}
					}, suggestionSelector
				);

				// Events for Search input
				searchInpt.on('keydown.autocomplete', function (ev) {
					var that = this,
						up = 38,	// pressed up key
						down = 40,	// pressed down key
						splKeys = /8|9|13|16|17|18|20|27|32|33|34|35|36|37|38|39|40|45|46|91|93|224/; // special keys

					if (ev.which == up && obj.selectedIndex === -1) {
						$('.exact-match').removeClass('exact-match');
					} else if ((container.children('.' + selected).length > 0) && (ev.which == up || ev.which == down)) {
						$('.exact-match').removeClass('exact-match');
						setTimeout(function(){
							$('.' + container.children('.' + selected).data('currentItem').split(',')[1])
							.parentsUntil('.admin_icons', 'li')
							.addClass('exact-match');
						}, 5);
					} else {
						$('.related-match, .exact-match').removeClass('related-match exact-match');
					}

					if (obj.el.val().trim().length < obj.options.minChars) {
						$('.as-clear').hide();
					}

					// Clear search field
					if(!$('.as-clear').is(':visible') && !splKeys.test(ev.which)) {
						$('.as-clear')
							.css({ 'display' : 'inline-block' })
							.bind('click', function (ev) {
								ev.preventDefault();
								$('.blur, .related-match, .exact-match').removeClass('blur related-match exact-match');
								$('.as-more').hide();
								$(that).val('').trigger('focus');
								$(this).hide();
							});
					}
				});
			}
	    });

}(jQuery));