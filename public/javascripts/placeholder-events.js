var active_email_body = null;

(function($){
	$.fn.groupPlaceholders = function(options) {
		var defaults = {
			groupingParent : '.placeholder-category',
			maxHeight : 75,
			toggleClass : '.ph-more-less',
			showMoreClass : '.ph-more',
			showLessClass : '.ph-less',
			btnPrefix : 'placeholder-btn-',
			ignorePhs : "",
			truncateItems : true,
			onShowMore : function() { onShowMore.call(this) },
			onShowLess : function() { onShowLess.call(this) }
		};
		var settings = $.extend({},defaults, options);
		var formatPlaceholders = function(options) {
			options = $.extend({}, settings, options);
			groupedElements = options.groupingParent;
			if(options.selectedGroup) groupedElements = options.selectedGroup;
			$.each($(groupedElements), function() {
				var self = this,
					height = $(self).outerHeight();

				if(options.truncateItems && height > options.maxHeight) {
					$(self).find(options.toggleClass).hide();
					height = $(self).outerHeight();
					if(height > options.maxHeight) {
						$(self).find(options.toggleClass).show();
						$.each($(this).find('li:not('+options.toggleClass+'):visible').get().reverse(), function() {
							height = $(self).outerHeight();
							if(height > options.maxHeight) {
								$(this).hide();
							}
						});
						$(self).find(options.showMoreClass).parent().show();
					}
					$(self).find(options.showLessClass).parent().hide();
				}
				else if($(self).find(options.showMoreClass).is(':visible') && $(self).find(options.showLessClass).is(':not(:visible)')) {
					// Do nothing
				}
				else {
					$(self).find(options.toggleClass).hide();
				}
			});
		};
		var ignorePlaceholders = function(options) {
			options = $.extend({}, settings, options);
			groupedElements = options.groupingParent;
			if(options.selectedGroup) groupedElements = options.selectedGroup;

			$(groupedElements).show();
			$(groupedElements).find('li').show();	
		 	options.ignorePhs.split(",").each(function(item){
		 		var element = "#"+ options.btnPrefix + item;
		 		$(element).hide();
		 		if($(element).parent().children(':not('+ options.toggleClass +'):visible').length == 0) {
		 			var parent = $(element).parents(options.groupingParent);
		 			$(parent).hide();
		 		}
		 	});
		};

		var onShowMore = function() {
			var ph_more_parent = $(this).parent();
			$(ph_more_parent).parent().find('li:not(:visible)').show();		// Shows the Extra icons & Show Less Icon
			ignorePlaceholders({
				'selectedGroup' : $(this).parents(settings.groupingParent).get(0),
				'ignorePhs' : jQuery(active_email_body).data('ignorePlaceholders') || ""
			});
			$(ph_more_parent).hide();
		};

		var onShowLess = function() {
			var element = $(this).parents(settings.groupingParent);
			formatPlaceholders({'selectedGroup': $(this).parents(settings.groupingParent).get(0)});
			$(this).parents(settings.groupingParent).find(settings.showMoreClass).parent().show();
		};

		this.init = function() {
			ignorePlaceholders({
				'ignorePhs' : jQuery(active_email_body).data('ignorePlaceholders') || ""
			});
			formatPlaceholders();
			$(settings.showMoreClass).on('click', settings.onShowMore);
			$(settings.showLessClass).on('click', settings.onShowLess);
			return this;
		}
		return this.init();
	};

}(jQuery));


jQuery(document).ready(function(){
	jQuery('body').on('focus',".insert-placeholder-target", function(){
		active_email_body = jQuery(this);
		jQuery('#place-dialog').groupPlaceholders({'truncateItems': false});
	});

	jQuery('.redactor_editor').live('click', function(){
		active_email_body = jQuery(this).siblings('textarea');	
		jQuery('#place-dialog').groupPlaceholders({'truncateItems': false});
    });
	
	jQuery(".placeholder-list button, .placeholder-list a.ph-btn").click(function(ev){  
		preventDefault(ev);
		if(jQuery(this).parent().hasClass('ph-more-less')) {
			return false;
		}
      	if(active_email_body){
	        var placeHolderText = jQuery(this).data("placeholder"); 
	        if(active_email_body.hasClass("desc_info") || active_email_body.hasClass("ca_content_body")){
	        	active_email_body.data('redactor').insertOnCursorPosition('inserthtml',placeHolderText);
	        } else if(active_email_body.hasClass("paragraph-redactor")){
		        active_email_body.data('redactor').insertOnCursorPosition('inserthtml',placeHolderText);
	        }
	        else{
	          insertTextAtCursor(active_email_body.get(0), placeHolderText);
	        }
	        var editor = active_email_body.data("CodeMirrorInstance");
	        if (editor){
		    	editor.replaceRange(placeHolderText, editor.getCursor());   
		    }
		}
	});
	
	jQuery('#placeholder_close').click(function(){
		jQuery('#place-dialog').hide();	
	});

	jQuery('#place-dialog').draggable({
		cancel : '.placeholder-list'
	});

});