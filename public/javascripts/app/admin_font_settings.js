
window.App = window.App || {};
window.App.Admin = window.App.Admin || {};

(function ($) {
    "use strict";

    App.Admin.AdminFontSettings = {
    fontname_pairs : {
      'System'    : "-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif",
      'Helvetica'   : 'Helvetica Neue, Helvetica, Arial, sans-serif',
      'Sans Serif'  : 'arial, helvetica, sans-serif',
      'Serif'     : 'times new roman, serif',
      'Wide'      : 'arial black, sans-serif',
      'Narrow'    : 'arial narrow, sans-serif',
      'Courier New' : 'courier new, monospace',
      'Garamond'    : 'garamond, serif',
      'Georgia'   : 'georgia, serif',
      'Tahoma'    : 'tahoma, arial, sans-serif',
      'Trebuchet MS'  : 'trebuchet ms, arial, sans-serif',
      'Verdana'   : 'verdana, arial, sans-serif'
    },
    font_sizes : ['10px', '11px', '12px', '13px', '14px', '15px', '16px', '17px', '18px', '19px', '20px'],
      initialize: function () {
        this.bindFontChange();
        this.bindFontSave();
        this.bindFontCancel();
        this.bindRedactorDropdownList();
        this.bindFontSettingText();
        this.buildFontFamily();
        this.buildFontSize();
        this.bindDOM();
        this.changeFontName();
        this.changeFontSize();
      },
      onVisit: function () {
        this.initialize();
      },
      bindFontChange: function(){
        this.fontSectionDisplay("#font-family-change", "#font-family-edit");
        this.fontSectionDisplay("#font-size-change", "#font-size-edit");
      },
      fontSectionDisplay: function(fontStyleChangeSection, fontEditSection){
        $(document).on("click.fontsetting", fontStyleChangeSection, function(){
          $("#font-size-show").addClass('hide');
          $("#font-family-show").addClass('hide');
          $(fontEditSection).removeClass('hide');
        });
      },
      bindFontSave: function(){
        $(document).on('click.fontsetting', '#save-font', function(){
          $(".twipsy").remove();
          $("#font-btn").empty().addClass('sloading');
          $.ajax({
            type: "POST",
                  dataType: "script",
              data: { "_method" : "put",
                  "font-family" : $("#family-text").attr('rel'),
                  "font-size" : $("#size-text").attr('rel')
                },
            url: "/admin/account_additional_settings/update_font",
            success: function (response) {

            }
          });
        });
      },
      bindFontCancel: function(){
        this.fontStyleCancel("#font-family-cancel", "#font-family-edit");
        this.fontStyleCancel("#font-size-cancel", "#font-size-edit");
      },
      fontStyleCancel: function(fontCancelStyle, fontStyleEdit){
        $(document).on("click.fontsetting",fontCancelStyle, function(){
          $("#font-size-show").removeClass('hide');
          $("#font-family-show").removeClass('hide');
          $(fontStyleEdit).addClass('hide');
        });
      },
      bindRedactorDropdownList: function(){
        this.fontDropdownList("#font-family-dropdown a", "#family-text", "font-family");
        this.fontDropdownList("#font-size-dropdown a", "#size-text", "font-size");
      },
      fontDropdownList: function(fontDropdownStyle, fontTextStyle, fontCssProperty){
        $(document).on("click",fontDropdownStyle, function(){
          $(fontTextStyle).text($(this).text()).attr('rel',$(this)[0].rel).css(fontCssProperty,$(this)[0].rel);
          $(this).parent().removeClass('active');
        });
      },
      bindFontSettingText: function(){
        this.toggleFontStyleDropdown("#family-selected-text");
        this.toggleFontStyleDropdown("#size-selected-text");
      },
      toggleFontStyleDropdown: function(selectedTextStyle){
        $(document).on("click.fontsetting", selectedTextStyle, function (ev) {
          ev.stopPropagation();
          $(this).siblings('.redactor_dropdown').toggleClass('active');
        });
      },
      bindDOM: function(){
        $(document).on("click.fontsetting", function (ev) {
          $("#font-family-dropdown").removeClass("active");
          $("#font-size-dropdown").removeClass("active");
        });
      },
      buildFontFamily: function(){
        var fontnames = ['System', 'Helvetica','Sans Serif','Serif','Wide','Narrow','Courier New','Garamond','Georgia','Tahoma','Trebuchet MS','Verdana']

        var dropdown = $('<div class="redactor_dropdown" id="font-family-dropdown" >');
        var len = fontnames.length;
        for (var i = 0; i < len; ++i)
        {
          var fontname = fontnames[i];
          var swatch = $('<a rel="' + this.fontname_pairs[fontname] + '" href="javascript:void(null);" class="redactor_font_link">' + fontname + '</a>').css({ 'font-family': this.fontname_pairs[fontname] });

          $(dropdown).append(swatch);
        }
        $("#font-family-select .redactor_dropdown").remove();
        $("#font-family-select").append(dropdown);
      },
      buildFontSize: function(){
        var dropdown = $('<div class="redactor_dropdown" id="font-size-dropdown" >');
        for(var i = 0; i < this.font_sizes.length; ++i) {
          var swatch = $('<a rel="' + this.font_sizes[i] + '" href="javascript:void(null);" class="redactor_font_link">' + this.font_sizes[i] + '</a>').css({ 'font-size': this.font_sizes[i] });
          $(dropdown).append(swatch);
        }
        $("#font-size-select .redactor_dropdown").remove();
        $("#font-size-select").append(dropdown);
      },
      changeFontName: function(){
        var name = getKeyFromValue(this.fontname_pairs,$("#font-name").attr('rel'));
        $("#font-name").text(name);
        $("#family-text").text(name);
      },
      changeFontSize: function(){
        var name = $("#font-size").attr('rel');
        $("#font-size").text(name);
        $("#size-text").text(name);
      },
      onLeave: function () {
        $(document).off("click.fontsetting");
      }
    };

}(window.jQuery));
