/**
 * @Srihari Surabhi
 * Plugin for Q&A module
 * Events :
 * Below events are fired. Listen to those events and act on them if needed.
 * After entire question is framed => 'question-complete' with data => JSON Array
 *
 * Version : 1.0
 */

HelpdeskReports.Qna_util = (function($){

  var SEARCHABLE_OPTIONS_LENGTH = 5;
    var constants = {
			api : '/',
			filter_widgets : {
				"1" : "autocomplete_es", // include endpoint in json
				"2" : "autocomplete" // include key of object in json
			},
			question_prefixs : QLANG[I18n.locale],
			events_namespace : '.qna',
			debug_mode : 0, // 0 for off, 1 for on,
			question_colors : ["rgba(229,78,66,0.2)","rgba(231,174,31,0.2)","rgba(123,182,46,0.2)","rgba(69,147,226,0.2)"]
	};

    var _q = {
			current_level : 0,
			question_prefix_count : 0,
			in_progress : true,
			request_param : {},
			filtering : false,
			populateSearchBox : function(selected_item) {
				var bg_color = '#fff'; //constants.question_colors[this.question_prefix_count];
				var mkup = '<div class="value-block" data-level="' + this.current_level +'" style="background:' + bg_color + '">' + (selected_item.attr('data-prefix') || '') + selected_item.html() + (this.current_level == -1 ? '?': '') + '</div>';
				$(".selected-queries").append(mkup);
				this.question_prefix_count += 1;
			},
			populateQuestionPrefixes : function(current_level,selected_breadcrumb){
				var source = {},options = [];
				var $popover = $(".question-popover");
				var $input = $("#search-query");
				var _this = this;
				if(current_level == -1) {
					//End of question
				  	_this.in_progress = false;
					//reset the questions populated count
					_this.question_prefix_count = 0;
					//cloes the question dropdown
				  	$popover.velocity('fadeOut');

					//Collect the text in the question box;
					_this.request_param['text'] = $("#search-query").attr('data-text') + '?';
					_this.request_param['markup'] = $(".selected-queries").html();
					if(constants.debug_mode == 1) {
						//console.log('firing query',_this.request_param);
					}
					trigger_event('question-complete' + constants.events_namespace ,_this.request_param);
				} else {
					if( current_level == 0){
						selected_breadcrumb = 'start';
						_this.request_param['markup'] = '';
						_this.request_param['text'] = '';
						$input.attr('data-text','');
					} 
					//Happens when user focuses the input box while the search is in progress
					if(selected_breadcrumb == undefined) {
						selected_breadcrumb = _this.last_used_breadcrumb;
					} else {
						_this.last_used_breadcrumb = selected_breadcrumb;
					}
					
					source = constants.question_prefixs[current_level][selected_breadcrumb] || {};
					if(!jQuery.isEmptyObject(source)){
						options = source['options'];
					}
							
					//clean the dropdown
					$(".questions").html('');
					if(options.length != 0) {
						if(source.searchable == "true" && options.length > SEARCHABLE_OPTIONS_LENGTH) {
							var li = _.template('<li class="search-header clearfix"><input type="text" placeholder="<%=placeholder%>" rel="filter_content"  /></li>');
							var $li = $(li({
								placeholder : source.placeholder
							}));
							$(".questions").append($li);
						}

						jQuery.each(options,function(i,el) {
						
						if(source.hasOwnProperty('filter')) {
							var $li = $('<li>' +  el.label +'<i class="ficon-arrow-right icon-next"></i></li>');
							$li.attr({
								'data-action' : 'filter',
								'data-value' : el.value,
								'data-widget' : el.widget_type,
								'data-url' : el.url,
								'data-src' : el.src,
								'data-options_key' : el.options,
								'data-prev-breadcrumb' : source.back_breadcrumb,
								'data-prev-breadcrumb-level' : source.back_breadcrumb_in,
								'data-breadcrumb' : el.breadcrumb,
								'data-search-breadcrumb-in' : el.search_breadcrumb_in,
								'data-req-key' : source.req_key,
                'data-prefix': el.prefix
							});
              if(el.feature_check != undefined){
								if(HelpdeskReports.features[el.feature_check] == true) {
									$(".questions").append($li);
								}
							 }else {
								$(".questions").append($li);
							}
						} else {
							var $li = $('<li>' +  el.label + '</li>');
							$li.attr({
								'data-action' : 'selector',
								'data-value' : el.value,
								'data-breadcrumb' : el.breadcrumb,
								'data-search-breadcrumb-in' : el.search_breadcrumb_in,
								'data-req-key' : source.req_key
							})

							if(el.feature_check != undefined){
								if(HelpdeskReports.features[el.feature_check] == true) {
									$(".questions").append($li);
								}
							 }else {
								$(".questions").append($li);
							}
						}
					});
					
						if( current_level != 0){
							_this.moveQuestionsPopover();
						}
					}
				}
			},
			populateFilters : function(source) {
				var $el = jQuery(source);
				var widget = $el.attr('data-widget');
				var condition = $el.attr('data-value');
				var url = $el.attr('data-url');
				var self_breadcrumb = $el.attr('data-prev-breadcrumb');
				var self_breadcrumb_level = $el.attr('data-prev-breadcrumb-level');
				var next_breadcrumb = $el.attr('data-breadcrumb');
				var next_breadcrumb_found_in = $el.attr('data-search-breadcrumb-in');
				var req_key = $el.attr('data-req-key');
				var prefix = $el.attr('data-prefix');
        
				if( constants.filter_widgets[widget] == 'autocomplete_es') {
					
					var url = $el.attr('data-url');
					
					$(".questions").html('');
					
					var search_head_mkup = _.template('<li class="search-header wide-width clearfix"><i class="back-nav ficon-left-arrow-thick" data-action="backnav" data-breadcrumb="<%= breadcrumb %>" data-search-breadcrumb-in="<%= search_in %>"> </i> <input type="text" id="<%=condition%>" data-url="<%=url%>" data-next-breadcrumb= "<%=next_breadcrumb%>" data-next-breadcrumb-in = "<%=next_breadcrumb_found_in %>" data-req-key="<%=req_key%>" data-prefix="<%=prefix%>" placeholder="Type 2 or more characters" rel="remote-search" class="filter_item" /></li>');
          
					$(".questions").html(search_head_mkup({
						condition : condition,
						url : url,
						breadcrumb : self_breadcrumb,
						search_in : self_breadcrumb_level,
						next_breadcrumb : next_breadcrumb,
						next_breadcrumb_found_in : next_breadcrumb_found_in,
						req_key : req_key,
            prefix: prefix
					}));

					//Construct options

				} else if(constants.filter_widgets[widget] == 'autocomplete'){
					var src = $el.attr('data-src');
					var options = HelpdeskReports.locals[src];
	
					$(".questions").html('');

					var search_head_mkup = _.template('<li class="search-header wide-width clearfix"><i class="back-nav ficon-left-arrow-thick" data-action="backnav" data-breadcrumb="<%= breadcrumb %>" data-search-breadcrumb-in="<%= search_in %>"> </i> <input type="text" rel="filter_content" class="filter_item" /></li>');
					$(".questions").html(search_head_mkup({
						breadcrumb : self_breadcrumb,
						search_in : self_breadcrumb_level
					})); 

					jQuery.each(options, function(index, item) {
						var $li = $('<li class="wide-width">' + item[1]  + '</li>');
						
						$li.attr({
							'data-action' : 'selector',
							'data-value' : item[0],
							'data-condition' : condition,
							'data-breadcrumb' : next_breadcrumb,
							'data-search-breadcrumb-in' : next_breadcrumb_found_in,
							'data-req-key' : req_key,
							'data-condition' : condition,
              'data-prefix': prefix
						});
						$(".questions").append($li);
					});

					if(options.length == 0){
						var $emptyli = $('<li class="wide-width">No Data</li>');
						$(".questions").append($emptyli);
					}
				}
			},
			moveQuestionsPopover : function(){
				var $selected_queries = $(".selected-queries");
				var $popover = $(".question-popover");

				var width = $selected_queries.width();
				var left_pos = $selected_queries.position().left;
				var current_position = $popover.position().left;

				var translate_by = width + left_pos - current_position;
				$popover.velocity({
					left: width + 35 +"px"
				});
				
			},
			reset : function() {
				var _this = this;
    			var $popover = $(".question-popover");

				_this.in_progress = true;
    			_this.current_level = 0;
				_this.question_prefix_count = 0;
				_this.request_param = {};
				
    			$popover.velocity('fadeOut');
    			$(".selected-queries").empty();
    			$popover.css({
    				left : "30px"
    			})
			},
			filterList : function() {
				
				var filter_text = $("[rel=filter_content]").val();
				
				if(!this.filtering) {
					this.filtering = true;
					if( filter_text != undefined && filter_text.length > 0) {
						filter_text = filter_text.toLowerCase();
						jQuery.each($(".questions li").not('.search-header'),function(i,el) {
							var innerHtml = $(el).html().trim().toLowerCase();
							if(innerHtml.indexOf(filter_text) > -1){
								$(el).show();
							} else {
								$(el).hide();
							}
						});
						this.filtering = false;
					} else {
						$(".questions li").not('.search-header').velocity('slideDown');
						this.filtering = false;
					}
				}
				
			},
			build_params : function($li) {
				var value =  $li.attr('data-value');
				var key = $li.attr('data-req-key') ;

				if(key == 'filter_value') {
					this.request_param['filter_key'] = $li.attr('data-condition');
				}
				
				//Search input
				var $input = $("#search-query");
				var text = $input.attr('data-text');
				if( text != undefined) {
					$input.attr('data-text',text + " " + ($li.attr('data-prefix') || '') +$li.html())
				} else {
					$input.attr('data-text',($li.attr('data-prefix') || '') + $li.html())
				}
				this.request_param[key] = value;
			},
			clear_params : function(){
				this.request_param = {};
				$("#search-query").removeAttr('data-text');
			},
	    	bindEvents : function() {
	    		
	    		var _this = this;

	    		var $doc = $(document),
				$results = $(".search-results"),
				$left_section = $(".left-section"),
				$base = $(".base-content"),
				$insights = $(".insights"),
	    		$popover = $(".question-popover"),
				$selcted_queries = $(".selected-queries"),
				$answer_section  = $(".answer-section");
	    		
				//flush existing events
				$doc.off(constants.events_namespace);

	    		$doc.on('focus' + constants.events_namespace,'#search-query',function(){
  					if(!$(this).hasClass('loading')){
              _this.reset();
    					
    					trigger_event("question-focus" + constants.events_namespace);

    	    			$('.search-field-holder').addClass('active');
    	    			//Remove placeholder
    	    			$('.search-field-holder input').prop('placeholder','');
    					//Show the clear icon
    					$('.clear-query,.close-search').removeClass('hide');
    	    			
    	    			if(_this.in_progress) {
    	    				_this.populateQuestionPrefixes(_this.current_level);
    	    				$popover.velocity('fadeIn')	
    	    			}
            }
	    		})

				$doc.on('click'+ constants.events_namespace,'[data-action="close-search"]',function(){
					
					trigger_event("question-close" + constants.events_namespace);
					
					$popover.hide();	
					$('.search-field-holder').removeClass('active');
	    			//Remove placeholder
	    			$('.search-field-holder input').val('').prop('placeholder','Ask me a question about your helpdesk');
					//Show the clear icon
					$('.clear-query').addClass('hide');
					$(this).addClass('hide');
					_this.clear_params();
					_this.reset();
				})

	    		$doc.on('click' + constants.events_namespace,'[data-action=clear-query]',function(){
	    			_this.reset();
					_this.clear_params();
					trigger_event("question-cleared" + constants.events_namespace);
	    			$("#search-query").trigger('click');
	    		});

	    		//breadcrumb query[selection]
	    		$doc.on('click' + constants.events_namespace,'[data-action=selector]',_.debounce(function(ev) {
						_this.current_level  = $(this).attr('data-search-breadcrumb-in') || "-1";
						  _this.populateSearchBox($(this));
	    				_this.build_params($(this));
						  _this.populateQuestionPrefixes(_this.current_level,$(this).attr('data-breadcrumb'));
	    		}, 250));
				//back nav query
				$doc.on('click' + constants.events_namespace,'[data-action=backnav]',function(ev) {
						_this.current_level  = $(this).attr('data-search-breadcrumb-in') || "-1";
	    				_this.populateQuestionPrefixes(_this.current_level,$(this).attr('data-breadcrumb'));
	    		});

				//Show filters
				$doc.on('click' + constants.events_namespace,'.questions li[data-action=filter]',function(ev) {
	    				_this.populateFilters(this);
	    		});

				//Remote Filter fetch
				$doc.on("keyup" + constants.events_namespace,'[rel="remote-search"]',function(ev){
						var $el = $(this);
						if(ev.keyCode != 40) {
							var url = $el.attr('data-url');
							var condition = $el.attr('id');
							var next_breadcrumb = $el.attr('data-next-breadcrumb');
							var next_breadcrumb_found_in = $el.attr('data-next-breadcrumb-in');
							var req_key = $el.attr('data-req-key');
							var condition = $el.attr('id');
              var prefix = $el.attr('data-prefix');
							_this.remoteSearch(condition,url,next_breadcrumb,next_breadcrumb_found_in,req_key,condition,prefix);
						}
						
				});

				//options filter
				$doc.on("keyup" + constants.events_namespace,'[rel=filter_content]',function(){
					_this.filterList(); 
				});

				//same behavior as close action
				$doc.keyup(function(e) {
					if (e.keyCode == 27) { 
						// escape key maps to keycode `27`
						trigger_event("question-close" + constants.events_namespace);
					
						$popover.velocity('fadeOut');	
						$('.search-field-holder').removeClass('active');
						//Remove placeholder
						$('.search-field-holder input').val('').prop('placeholder','A question about your helpdesk');
						//Show the clear icon
						$('.clear-query').addClass('hide');
            $('.close-search').addClass('hide');
            
						$(this).addClass('hide');
						_this.clear_params();
						_this.reset();
					}
				}); 
	    	},
			remoteSearch : function(condition,url,next_breadcrumb,next_breadcrumb_found_in,req_key,condition,prefix) {
				var _this = this;
				$(".questions li").not('.search-header').remove();

				var text = $('[rel=remote-search]').val();
				if( text != undefined && text != '' && text.length >= 2) {
					
					var $spinner = $('<li class="wide-width"><div class="sloading loading-small loading-block"></div></li>');
					$(".questions").append($spinner);

					var config = {
						url: "/search/autocomplete/" + url,
						type : "get",
						dataType: 'json',
						data: {
								q: text
						},
						success: function (data, params) {
								$(".questions li").not('.search-header').remove();

								$.each(data.results, function(index, item){
									var $li = $('<li class="wide-width">' + item.value  + '</li>');
									
									$li.attr({
										'data-action' : 'selector',
										'data-value' : condition == "agent" ? item.user_id : item.id,
										'data-breadcrumb' : next_breadcrumb,
										'data-search-breadcrumb-in' : next_breadcrumb_found_in,
										'data-req-key' : req_key,
										'data-condition' : condition,
                    'data-prefix': prefix
									});
									$(".questions").append($li);
								});

								if(data.results.length == 0){
									var $emptyli = $('<li class="wide-width">No results found</li>');
									$(".questions").append($emptyli);
								}
						},
						cache: true
					};
					this.makeAjaxRequest(config);
				} else {
					$(".questions li").not('.search-header').remove();
				}
				
    		},
			makeAjaxRequest: function (args) {
		        args.url = args.url;
		        args.type = args.type ? args.type : "POST";
		        args.dataType = args.dataType ? args.dataType : "json";
		        args.data = args.data;
		        args.success = args.success ? args.success : function () {};
		        args.error = args.error ? args.error : function () {};
		        var _request = $.ajax(args);
	    	},
	    	showLoader : function(container) {
	    		$(container).append('<div class="sloading loading-small loading-block"></div>');
	    	},
	    	hideLoader : function(container){
	    		$(container).remove();
	    	},
			init : function() {
				this.bindEvents();
				this.reset();
				if(constants.debug_mode == 1){
					Qna_test(I18n.locale);
				}
			}
    };

    return _q;
})(jQuery);
