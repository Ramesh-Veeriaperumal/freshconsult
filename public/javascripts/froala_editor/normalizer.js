/*jslint browser: true, devel: true */
/*global  Normalize */

window.Normalize = window.Normalize || {};

(function ($) {
  "use strict";

  Normalize = {

    removeStyleAttr : ["margin-top", "margin-right", "word-spacing", "float", "outline", "font-style",  "vertical-align", "text-rendering", "font-variant", "letter-spacing", "orphans", "text-transform", "white-space",  "widows", "-webkit-text-stroke-width", "display", "position", "overflow",  "text-overflow", "text-decoration",  "font-variant-ligatures", "font-variant-caps"],

  	tagProperties: {
      'TABLE': 'border-collapse:collapse; border:1px solid #afafaf;'
    },

    allowedStylesCallbacks: {
      'mso-highlight': function (container, value) {
        container.css('background-color', value);
      },
      'font-family': function (container, value, options) {
        if (value != 'inherit') {
          container.css('font-family', value);
        }
      },
      'font-size': function (container, value) {
        if (value != 'inherit') {
          container.css('font-size', value);
        }
      },
      'font-weight': function (container, value) {
        if (value != 'normal' && value != 'inherit') {
          container.css('font-weight', value);
        }
      },
      'background': function (container, value) {
        var _testCondition = ($.browser.msie || $.browser.mozilla);
        var _property = _testCondition ? 'background-color': 'background';
            
        container.css(_property, value);
      },
      'text-align': function (container, value) {
        if($.browser.mozilla) {
          container.attr('align', value);
          container.css('text-align', '');
        } else {
          container.css('text-align', value);
        }
      },
      'text-indent': function (container, value) {
        container.css('text-indent', Math.abs(parseInt(value)) + "px");
      },
      'margin-left': function (container, value) {
        if(parseInt(value) > 0) { 
          container.css('margin-left', parseInt(value) + "px");
        }
      },
      'background-color': function (container, value) {
        if (container.prop("tagName") == "SPAN") {
          container.css('background-color', value);
        }
      },
    },

    // Setting a jQuery wrapper for content parsing
    normalizeContent: function (editor, html) {
      var cleaner = $('<div></div>').html(html);
      var $this = this;
      
      cleaner.find('*').each(function(index, container){    
        var $container = $(container);      
        $this.normalizeAttributes(editor, $container);      
      });   
      
      cleaner.find('p span:only-child').each(function() {
        if (!jQuery.trim(jQuery(this).text()).length) {
          jQuery(this).html("&nbsp;");
        }
      });

      return cleaner.html();
    },
    
    normalizeAttributes: function (editor, container) {
      container.removeAttr('class');
          
      this.filterDomProperty(editor, container, 'style');
      this.filterDomProperty(editor, container, 'align');
      this.resetAttributes(editor, container);
      
      return container;
    },

    filterDomProperty: function (editor, container, prop){
      var propValue = container.attr(prop);
      var $this = this;
      if(propValue) {
        container.removeAttr(prop);
        switch(prop) {
          case 'align':
            container.css('text-align', propValue);
          break;
          case 'style':
            $this.normalizeStyleAttribute(editor, container, propValue);
          break;          
        }
      }
    },

    // Content Class names to render style in UI
    resetAttributes: function (editor, container) {
      var _styleProps = this.tagProperties[container.prop('tagName')];
      
      if(_styleProps){
        container.attr('inline-styles', _styleProps);
      }
    },
    
    // Cleaning up styles
    normalizeStyleAttribute: function (editor, container, styleAttributes) {   
      var parts = styleAttributes.split(/[;]/);
      var $self = this;
          
      $.each( parts, function(index, part){
        var subParts = part.split(':').map( $.trim );
        var styleProperty = subParts[0].toLowerCase();
        var stylePropertyValue = subParts[1];
        var applyStyle = $self.allowedStylesCallbacks[styleProperty];
        
        if($.inArray(styleProperty, $self.removeStyleAttr) == -1) {
          if (typeof applyStyle !== "undefined") {
            applyStyle(container, stylePropertyValue, editor.opts);
          } else {
            container.css(styleProperty, stylePropertyValue);
          }
        }
      });
    }

  }
}(window.jQuery));