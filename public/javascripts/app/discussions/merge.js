/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Discussions = window.App.Discussions || {};
(function ($) {
	"use strict";

	App.Discussions.Merge = {
		autocompleteObjects: {},
		TEMPLATE: new Template(
		    '<li><div class="contactdiv" data-id="#{id}">'+
		    '<span id="resp-icon" class="resp-icon"></span>'+
		    '<div class="merge_element merge-topic ellipsis" data-id="#{id}" data-created="#{created_at}">'+
		    '<span class="item_info" title="#{searchKey}">#{searchKey}</span>'+
		    '<div class="info-data hideForList">'+
		    '<span class="merge-topic-info">'+
		    'in <span class="muted">#{forum_name} (#{category_name})</span><br />by <span class="muted">#{user_name}</span>, <span class="emphasize">#{info}</span>'+
		    '</span></div></div></div></li>'
		  ),
		start: function () {
			this.setPrimary();
			this.mergeTopicsInitializer();
			this.enableContinue();
  		this.bindAutocompleter();
  		this.triggerSearch();
		},

		setPrimary: function() {
			$('#merge-content').find('.merge-topic').addClass('merge_element');
			var primary_topic = this.findOldestTopic();
  		primary_topic.parent().prepend(primary_topic);
  		primary_topic.addClass('cont-primary');
  		primary_topic.find('.primary-marker').attr('title', I18n.translate('common_js_translations.primary_topic'));
		},

		bindMergeEvent: function (topic_id) {
			$("body").on('click.merge_topics',"a[data-merge='topic']", function(ev){
				ev.preventDefault();

				$.ajax({
					type: 'POST',
					url: '/discussions/merge_topic/select',
					data: { source_topics : [topic_id], redirect_back : true, id : topic_id },
					success: function (data) {
						$('#merge_topicdialog-content').html(data);
					}
	    		});
	    	});
		},

		enableContinue: function () {
			var to_enable = $('.merge-cont').hasClass('cont-primary') && $('.merge-cont').length > 1;
			$("#merge_topic").attr("disabled", !to_enable);
		},

		markPrimaryMarker: function () {
			var _this = this;
			$('body').on('click.merge_topics', '.primary-marker', function(){
				_this.markPrimary($(this).parents('.merge-cont'));
				$('.twipsy').hide();
				$('.primary-marker').attr('data-original-title', I18n.translate('common_js_translations.mark_as_primary'));
				$(this).attr('data-original-title', I18n.translate('common_js_translations.primary_topic')).trigger('mouseover')
				_this.enableContinue();
			});
		},

		initialiseMergeTopicList: function () {
			$('body').on('click.merge_topics', '#merge_topic', function(){
				var source_topics = [], 
						target = $('#merge_topics_form');
				$('#merge_topic').button("loading");
				$('#cancel').attr("disabled", true).addClass("disabled");
				$("#target_topic").val($('.cont-primary .merge-topic').data("id"));
				$(".merge-cont:not('.cont-primary')").each(function(){ 
					target.append($('<input />').attr({
					  name: "source_topics[]",
					  type: 'hidden',
					  value: $(this).find(".merge-topic").data("id"),
						'class': 'src'
					}));
				});
			});
		},

		mergeTopicsInitializer: function () {
			this.mergeInitializer();

			$('body').on('click.merge_topics', '.typed', function(){
				clearSearchField($(this));
				var type = 'title';
				$('#'+type+'_results').hide();
			});

			this.initialiseSearch();
			this.markPrimaryMarker();
			this.initialiseMergeTopicList();
			this.searchResultShow();
			this.removeTopicFromMergedList();
			this.mergeActions();
		  
		},

		initialiseSearch: function () {
			$('body').on('keyup.merge_topics', '.search_merge', function(){
				var search_type = "title",
						minChars = 2;
				$('.merge_results').hide();
				$('#'+search_type+'_results , .visible-merge-note').toggle(($(this).val() != "") && ($(this).val().length >= minChars));
			});
		},

		searchResultShow: function () {
			$('body').on('change.merge_topics', function(){
				$('.searchtopic').hide();
				$('.merge_results').hide();
				var type = "title";
				$('.searchtopic').each(function(){
				  $(this).toggle($(this).hasClass(type));
				});
				if($('.'+type).find('.search_merge').val() != "")
					$('#'+type+'_results').show() 
			});
		},

		removeTopicFromMergedList: function () {
			var _this = this;
			$('body').on('click.merge_topics', '.merge-cont:not(".cont-primary") #resp-icon', function(){
				var id = $(this).closest("#contact-area").find(".merge-topic").data("id");
				var element = $('.contactdiv').find("[data-id = '"+id+"']").parent();
				element.find("#resp-icon").removeClass("clicked").parents('li').removeClass("clicked");
				$(this).closest(".merge-cont").remove();
				_this.enableContinue();
			});
		},

		mergeActions: function () {
			var _this = this;
			$('body').on('click.merge_topics', '.contactdiv', function(){
			if(!$(this).find('#resp-icon').hasClass("clicked"))
			{
					$(this).parent().addClass("clicked");
					var element = $(".cont-primary").clone();
					_this.appendToMergeList(element, $(this));
					element.find('.primary-marker').attr('title', I18n.translate('common_js_translations.mark_as_primary')).addClass('tooltip');
					var replace_element = element.find('.item_info');
					var title =  replace_element.attr('title');
					var topic_id = element.find(".merge-topic").data("id")
					var replace_html = jQuery('<a>', { class: 'item_info', target: '_blank', href: '/discussions/topics/'+ topic_id, title: title, html: replace_element.html() });

					replace_element.replaceWith(replace_html);
					_this.enableContinue();
				}
			});
		},

		triggerSearch: function () {
			var search_title = $('.item_info').attr('title');
			var title_search_box = $('#select-title');
			title_search_box.data('filter', 'title');
			title_search_box.val(search_title).keyup();
			this.autocompleteObjects['select-title'].onSearchFieldKeyDown(42);
			setTimeout(function() { title_search_box.data('filter', 'title'); }, 200 )
		},

		findOldestTopic: function () {
			var oldestTopic = null, earliestCreatedDate = null;
			$('.merge-cont .merge_element').each(function(index, ele){
				var ele = $(ele),
					createdDate = ele.data('created');
				if(earliestCreatedDate == null || earliestCreatedDate > createdDate){
					earliestCreatedDate = createdDate;
					oldestTopic = ele.parents('.merge-cont');
				}
			});
			return oldestTopic;
		},

		aftershow: function () {
			$('.contactdiv').each(function(){
				var y = $(this);
				$('.merge-cont .merge-topic').each( function(){
					if($(this).data('id') == y.data('id'))
					{
						y.children('#resp-icon').addClass('clicked');
						y.addClass('clicked').parents('li').addClass('clicked');
					}
				});
			});
		},

		bindAutocompleter: function () {
			var _this = this;
			var titlecachedBackend, titlecachedLookup;
			var autocompleter_hash = {  title : {  cache : titlecachedLookup, backend : titlecachedBackend, 
																	searchBox : 'select-title', searchResults : 'title_results',
																	minChars : 2 } };
			$.each(autocompleter_hash, function(){
				this.backend = new Autocompleter.Cache(_this.lookup, {choices: 15});
				this.cache = this.backend.lookup.bind(this.backend);
				_this.autocompleteObjects[this.searchBox] = new Autocompleter.PanedSearch( this.searchBox, this.cache, _this.TEMPLATE,
				this.searchResults, $A([]), {frequency: 0.1, acceptNewValues: true,
				afterPaneShow: _this.aftershow, minChars: this.minChars, separatorRegEx:/;|,/});
			})
		},

		lookup: function(searchString, callback) {
			var visibility = $('#select-title').data('visibility');
			$('#title_results').addClass("sloading");
			$.ajax({
					url: '/search/merge_topic',
					data: { term: searchString, forum_visibility: visibility },
					dataType: 'json',
					type: 'POST',
					success: function(response) {
						$('.merge_results:visible').removeClass("sloading");
						callback(response.results);
				}
			});
		},

		mergeInitializer: function () {

			$('body').on('keyup.merge_helpdesk', '.search_merge', function(){
					$(this).closest('.searchicon').toggleClass('typed', $(this).val()!="");
			});

			$('body').on('click.merge_helpdesk', '#cancel_new_merge, #cancel-user-merge', function(){
				if (active_dialog){
					active_dialog.dialog('close');
				}
				$('#merge_topicdialog').modal('hide');
				$('#merge_topicdialog-content').html('<span class="loading-block sloading loading-small">');
			});

		},

		activateRedactor: function (addNote) {
			invokeRedactor('source-note-body');
			$('body').on('click.discussions.merge',"#merge_completion", function(){
				$(this).button('loading');
				$("#cancel-user-merge, #back-user-merge").attr("disabled", true).addClass("disabled");
			});

			$('body').on('click.discussions.merge', '#edit-source', function (){
				$('.target-topic-merge-note').hide();
				$('.merge-info-text').addClass("note-height-adjust");
				$('.arrow-left').addClass("expand-note");

				var parent_object = $(this).parents('.source-target-note');
				parent_object.find('.default-note-text').html(addNote);
				parent_object.find('#target-note-content').slideDown();
				parent_object.find('.ok-cancel').show();
				$(this).hide();
			});

		},

		clearSearchField: function(entity) {
			$('.search_merge').val("");
			entity.removeClass('typed');
		},

		markPrimary: function(entity) {
			$('.merge-cont').removeClass('cont-primary');
			entity.addClass('cont-primary');
		},

		createdDate: function(element) {
			return element.find('.merge_element').data('created');
		},

		appendToMergeList: function(element, entity) {
			var _this = this;
			element.removeClass('cont-primary present-contact');
			element.find('.merge_element').replaceWith(entity.children('.merge_element').clone());
			element.appendTo($('.merge_entity'));
			_this.markPrimary(_this.findOldestTopic());
			entity.children('#resp-icon').addClass('clicked');
		},

		leave: function () {
			$('body').off('.discussions.merge');
		}
	};
}(window.jQuery));