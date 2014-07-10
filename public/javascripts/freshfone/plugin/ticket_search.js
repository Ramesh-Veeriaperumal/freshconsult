(function ($) {
	"use strict";

	var TICKET_SEARCH_TYPES = { REQUESTER : 'requester', SUBJECT : 'subject', ID : 'display_id' },
		FreshTicketSearch = function (element, options) {
		var self = this, defaults;
		this.$element = $(element);
		
		defaults = {
			template : new Template(
				'<li><div class="searchresult">' +
					'<span class="item_info" title="#{subject}">##{display_id} #{subject}</span>' +
					'<button class="save_to_ticket hide btn btn-primary tooltip"' +
					'data-id="#{display_id}" title="Save to this ticket">Save</button>' +
					'<div class="info-data hideForList">' +
					'<span class="ticket-info">#{ticket_info}</span><span>#{agent}</span>' +
					'</div></div></li>'
			),
			className: this.$element.attr('class') || 'search_container',
			aftershow: function (resultsPane) {
				var $resultsPane = $(resultsPane);
				$resultsPane.find('li').removeClass('selected');
			},
			lookup : function (searchString, callback) {

				var search_type = self.$element.find('.search-type option:selected').val(),
					list =  self.$element.find('.' + search_type + '_results').find('ul'),
					ajax_request;
				list.empty();

				self.$element.find('.' + search_type + '_results')
					.addClass("loading-small sloading");
			
				ajax_request = new Ajax.Request('/search/tickets/filter/'+search_type,
					{ parameters: { term: searchString },
						dataType: 'json',
						onSuccess: function (response) {
							self.$element.find('.ticket_search_results')
								.removeClass("loading-small sloading");
							callback(response.responseJSON.results);
						}
						});
			}
		};
		this.options = $.extend({}, defaults, options);
		this.search_container_class = this.options.className;
		this.results = {};
		this.init();

	};
	
	FreshTicketSearch.prototype = {
		init: function () {
			this.bindAutocompleter();
			this.bindChanges();
		},

		bindAutocompleter: function () {
			var idcachedBackend, requestercachedBackend, subjectcachedBackend,
				idcachedLookup, requestercachedLookup, subjectcachedLookup, autocompleter_hash,
				self = this;

			autocompleter_hash = {
				id :  {
					cache : idcachedLookup,
					backend : idcachedBackend,
					searchBox : '.' + this.search_container_class + ' .select-id',
					searchResults : '.' + this.search_container_class + ' .display_id_results',
					minChars : 1
				},
				requester :  {
					cache : requestercachedLookup,
					backend : requestercachedBackend,
					searchBox : '.' + this.search_container_class + ' .select-requester',
					searchResults : '.' + this.search_container_class + ' .requester_results',
					minChars : 2
				},
				subject :  {
					cache : subjectcachedLookup,
					backend : subjectcachedBackend,
					searchBox : '.' + this.search_container_class + ' .select-subject',
					searchResults : '.' + this.search_container_class + ' .subject_results',
					minChars : 2
				}
			};
			
			$.each(autocompleter_hash, function () {

				this.backend = new Autocompleter.Cache(self.options.lookup, {choices: 15});
				this.cache = this.backend.lookup.bind(this.backend);
				var options = { frequency: 0.1,
												acceptNewValues: true,
												afterPaneShow: self.options.aftershow || function () { },
												minChars: this.minChars,
												separatorRegEx: /;|,/
											},
					autocompleter = new Autocompleter.PanedSearch(this.searchBox,
						this.cache, self.options.template, this.searchResults, [], options);
				self.results[this.searchBox] = autocompleter;
			});
		},

		bindKeyUp: function () {
			var $container = this.$element;
			this.$element.find('.search_input').bind('keyup', function () {
				var search_type = $container.find('.search-type option:selected').val(),
					minChars = (search_type === TICKET_SEARCH_TYPES.ID) ? 1 : 2,
					is_blank;
				// Hide all search results
				$container.find('.ticket_search_results').hide();
				is_blank = $(this).val().blank();
				// Show or Hide search results container of particular type
				if (!is_blank && ($(this).val().length >= minChars)) {
					$container.find('.' + search_type + '_results').show();
				} else {
					$container.find('.' + search_type + '_results').hide();
				}
				$(this).closest('.searchicon').toggleClass('typed', is_blank);
			});
		},

		bindChange: function () {
			var $container = this.$element;
			$container.find('.search-type').change(function () {
				$container.find('.searchticket').hide();
				$container.find('.ticket_search_results').hide();

				var search_type = $container.find('.search-type option:selected').val();
				$container.find('.searchticket').each(function () {
					$(this).toggle($(this).hasClass(search_type));
				});
				if (!$container.find('.' + search_type).find('.search_input').val().blank()) {
					$container.find('.' + search_type + '_results').show();
				}
			});
		},

		bindChanges: function () {
			this.bindKeyUp();
			this.bindChange();
		},

		initializeRequester: function (requester_name) {
			var $container = this.$element;
			$container.find('#select-requester').val(requester_name).keyup();
			$container.find('.search-type').val(TICKET_SEARCH_TYPES.REQUESTER).trigger('change');
			this.results[ '.' + this.search_container_class + ' .select-requester']
				.onSearchFieldKeyDown(42);
		}
	};
	
	$.fn.freshTicketSearch = function (options) {
		return this.each(function () {
			var $this = $(this),
				data = $this.data('freshTicketSearch');
			if (!data) {
				$this.data('freshTicketSearch', (data = new FreshTicketSearch(this, options)));
			}
		});
	};
	$.fn.initializeRequester = function (requester_name) {
		if (!$(this).data('freshTicketSearch')) { return false; }
		return $(this).data('freshTicketSearch').initializeRequester(requester_name);
	};
}(jQuery));