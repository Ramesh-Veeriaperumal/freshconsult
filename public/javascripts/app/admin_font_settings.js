
window.App = window.App || {};

(function ($) {
    "use strict";

    App.AdminFontSettings = {
		fontname_pairs : {	
			'Helvetica'		: 'Helvetica Neue, Helvetica, Arial, sans-serif',
			'Sans Serif'	: 'arial, helvetica, sans-serif',
			'Serif'			: 'times new roman, serif',
			'Wide'			: 'arial black, sans-serif',
			'Narrow'		: 'arial narrow, sans-serif',
			'Courier New'	: 'courier new, monospace',
			'Garamond'		: 'garamond, serif',
			'Georgia'		: 'georgia, serif',
			'Tahoma'		: 'tahoma, arial, sans-serif',
			'Trebuchet MS'	: 'trebuchet ms, arial, sans-serif',
			'Verdana'		: 'verdana, arial, sans-serif'
		},
    	initialize: function () {
			this.bindFontChange();
			this.bindFontSave();
			this.bindFontCancel();
			this.bindRedactorDropdownList();
			this.bindFontSettingText();
			this.buildFontFamily();
			this.bindDOM();
			this.changeFontName();
    	},
    	bindFontChange: function(){
			$(document).on("click.fontsetting","#font-change", function(){
				$("#font-show").addClass('hide');
				$("#font-edit").removeClass('hide');
			}) 
    	},
    	bindFontSave: function(){
			$(document).on('click.fontsetting', '#save-font', function(){
				$(".twipsy").remove();
				$("#font-btn").empty().addClass('sloading');
				$.ajax({
					type: "POST",
				    data: { "_method" : "put",  
				    		"font-family" : $("#family-text").attr('rel')
				    	},
					url: "/admin/account_additional_settings/update_font",
					success: function (response) {

					}
				});
			}); 
    	},
    	bindFontCancel: function(){
			$(document).on("click.fontsetting","#font-cancel", function(){
				$("#font-show").removeClass('hide');
				$("#font-edit").addClass('hide');
			})
    	},
    	bindRedactorDropdownList: function(){
			$(document).on("click","#font-family-dropdown a", function(){
				$("#family-text").text($(this).text()).attr('rel',$(this)[0].rel).css('font-family',$(this)[0].rel);
				$(this).parent().removeClass('active');
			}) 
    	},
    	bindFontSettingText: function(){
			$(document).on("click.fontsetting", "#family-selected-text", function (ev) {
				ev.stopPropagation();
				$(this).siblings('.redactor_dropdown').toggleClass('active');
			}) 
    	},
    	bindDOM: function(){
			$(document).on("click.fontsetting", function (ev) {
			    $("#font-family-dropdown").removeClass("active");
			});
    	},
    	buildFontFamily: function(){
			var fontnames = ['Helvetica','Sans Serif','Serif','Wide','Narrow','Courier New','Garamond','Georgia','Tahoma','Trebuchet MS','Verdana']

			var dropdown = $('<div class="redactor_dropdown" id="font-family-dropdown" >');
			var len = fontnames.length;
			for (var i = 0; i < len; ++i)
			{
				var fontname = fontnames[i];
				var swatch = $('<a rel="' + this.fontname_pairs[fontname] + '" href="javascript:void(null);" class="redactor_font_link">' + fontname + '</a>').css({ 'font-family': this.fontname_pairs[fontname] });

				$(dropdown).append(swatch);
			}
			$("#font-size-select .redactor_dropdown").remove();
			$("#font-family-select").append(dropdown);
    	},
   		changeFontName: function(){
			var name = getKeyFromValue(this.fontname_pairs,$("#font-name").attr('rel'));
			$("#font-name").text(name);
			$("#family-text").text(name);
   		},
    	destroy: function(){
			$(document).off("click.fontsetting");
    	}
    };

}(window.jQuery));
