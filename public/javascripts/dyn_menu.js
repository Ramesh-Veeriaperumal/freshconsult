(function( $ ){
	$.fn.showAsDynamicMenu = function(){

		this.each(function(i, node){

			$(node).bind("click", function(ev){
				ev.preventDefault();
				ev.stopPropagation();
				var menuid;
				//Dynamic Menu count is just used to give an ID to the menus, so that they can be hidden properly.
				if ($(node).data('options-fetched') != true) {
					menuid = getNewMenuId();

					var menu_container = prepareEmptyMenu(menuid);
					menu_container.data('parent',$(node));
					menu_container.insertAfter($(node));

					$(node).data('menuid', menuid);
					if (typeof($(node).data('options-url')) != 'undefined' &&  $(node).data('options-fetched') != '' ) {
						loadFromAjax(node,menuid);
					} else {
						loadFromDOM(node,menuid);
					}
				} else {
					menuid = $(node).data('menuid');
				}

				var menu = $('#menu_' + menuid);
				console.log(menu);
				menu.show().css('visibility','visible');
				$(document).data({ "active-menu": true, "active-menu-element": menu, "active-menu-parent": node });

				$(node).addClass("selected");
				showAllOptions(menuid);
				console.log('Menu ID is ' + menuid);
				setFocusOnSearch(menuid);
				setFirstElementActive(menuid);
			});
		});

		var getNewMenuId = function() {
			if (typeof($(document).data('dynamic-menu-count')) == "undefined") {
				$(document).data('dynamic-menu-count',0);
			}
			var menuid = $(document).data('dynamic-menu-count') + 1;
			$(document).data('dynamic-menu-count',menuid);

			return menuid;
		}

		var prepareEmptyMenu = function(menuid) {
			return $('<div>').attr('id',"menu_" + menuid)
							.addClass('loading fd-ajaxmenu')
							.html('<div class="contents"></div>');
		}

		var loadFromAjax = function(node, menuid) {
			$.ajax({
				url: $(node).data('options-url'),
				success: function (data, textStatus, jqXHR) {
					var text_to_match = $(node).children('.result').first().text();
					loadContent(menuid, data, text_to_match);
					$(node).data('options-fetched',true);
				}
			});
		}

		var loadFromDOM = function(node,menuid) {
			var text_to_match = $(node).children('.result').first().text();
			loadContent(menuid, $($(node).data('options')).html(), text_to_match);
			$(node).data('options-fetched',true);
		}

		var loadContent = function(menuid, contents, text_to_match) {
			var content_element = $('#menu_' + menuid).find('.contents').first();
			$('#menu_' + menuid).removeClass('loading');
			content_element.html(contents);  
			setActiveElementStyle(menuid, text_to_match);

			initSearchBox(menuid);
			// setFirstElementActive(menuid);
			if (content_element.children().not('.seperator').length <= 5) {
				$('#menu_' + menuid + ' .menu_search').addClass('invisible');
			} else {
				$('#menu_' + menuid + ' .menu_search').removeClass('invisible');
			}

			initElementHover(menuid);
		}

		var setActiveElementStyle = function(menuid, text_to_match) {
			var match_found = false;
			$('#menu_' + menuid + ' .contents').children().each(function(i) {
				if (!match_found && $(this).data('text') == text_to_match || $(this).text() == text_to_match) {
					$(this).addClass('active').prepend('<span class="icon ticksymbol"></span>');
					match_found = true;
					setFirstElementActive(menuid);
				}
			});
		}

		var setFocusOnSearch = function(menuid) {
			// var setFocus = setInterval(function() {
		// 		console.log('trying to set the focus');
		// 		console.log( menuid);
				// if ($('#menu_' + menuid).css('display') == 'block') {
					$('#menu_' + menuid + ' .menu_search').val('').focus();
					console.log('setting the focus @ ' + menuid);
			// 		clearInterval(setFocus);
			// 	}
			// },100);
			
		}

		var initSearchBox = function(menuid) {

			var txt_box = $('<input>').attr('type','text').addClass('menu_search');

			$('#menu_' + menuid ).prepend(txt_box);
				txt_box.bind('keydown, keypress', function(e){
					if(e.keyCode == 13) 
						return false;
				})
				txt_box.bind('keyup',function(e) {
					switch (e.keyCode) {
						case 40:
						case 38:
						case 13:
							e.preventDefault();
							e.stopPropagation();
							executeAction(e.keyCode, menuid);
							return false;
						break;

						default:
							var search_txt = txt_box.val().trim();
							regex = new RegExp(search_txt,"i");
							var content_element = $('#menu_' + menuid + ' .contents');
							if (search_txt != '') {
								
								content_element.find('.seperator').addClass('hide');
								console.log(search_txt);
								$('#menu_' + menuid + ' .contents').children().not('.seperator').each(function(i) {
									if ($(this).text().search(regex) == -1){
										$(this).addClass('hide')
									} else {
										$(this).removeClass('hide');
									}
								});
							} else {
								content_element.children().removeClass('hide');
								content_element.find('.seperator').removeClass('hide');
								deselectActiveElement(menuid);
							}
						break;
					}
				});
			}
		}

		var initElementHover = function(menuid) {
			$('#menu_' + menuid + ' .contents a').live('mouseover',function(ev) {
				deselectActiveElement(menuid);
				var searchlist 	= $('#menu_' + menuid + ' .contents a').not('.hide');

				var currentactive = $(this).addClass('selected');
				var position = searchlist.index(currentactive);

				$('#menu_' + menuid ).data('currentactive',currentactive);
				$('#menu_' + menuid ).data('selection_position', position);

			});
		}

		var executeAction = function(keyCode, menuid) {
			switch (keyCode) {
				case 40:
					moveActiveElement(1, menuid); 
				break;

				case 38:
					moveActiveElement(-1, menuid); 
				break;

				case 13:
					var currentactive = $('#menu_' + menuid ).data('currentactive');
					currentactive.trigger("click");
				break; 
			}
		}

		var setFirstElementActive = function(menuid) {
			deselectActiveElement(menuid);
			var searchlist 	= $('#menu_' + menuid + ' .contents a').not('.hide');
			
			var currentactive = $(searchlist.get(0)).addClass("selected");

			$('#menu_' + menuid ).data('currentactive',currentactive);
			$('#menu_' + menuid ).data('selection_position', 0);
		}

		var showAllOptions = function(menuid) {
			$('#menu_' + menuid + ' .contents .hide').removeClass('hide');
		}

		var deselectActiveElement = function(menuid) {
			var currentactive = $('#menu_' + menuid ).data('currentactive');
			$(currentactive).removeClass("selected");
			$('#menu_' + menuid ).data('selection_position', 0);
			$('#menu_' + menuid ).data('currentactive',undefined);
		}

		var moveActiveElement = function(offset, menuid) {
			console.log('Moving');
			var searchlist 	= $('#menu_' + menuid + ' .contents a').not('.hide');
			var currentactive = $('#menu_' + menuid ).data('currentactive');
			var position = $('#menu_' + menuid ).data('selection_position');
			position = typeof(position) == 'undefined' ? -1 : position;

			$(currentactive).removeClass("selected");
			position = Math.min((searchlist.size()-1), Math.max(0, position + offset)); 
			currentactive = $(searchlist.get(position)).addClass("selected"); 

			console.log(currentactive);

			$('#menu_' + menuid ).data('currentactive',currentactive);
			$('#menu_' + menuid ).data('selection_position', position);
		}

})( jQuery );