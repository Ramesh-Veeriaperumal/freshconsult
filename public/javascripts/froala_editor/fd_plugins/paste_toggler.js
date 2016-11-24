/*!
 * FD Plugin for froala_editor
 */

(function (factory) {
    if (typeof define === 'function' && define.amd) {
        // AMD. Register as an anonymous module.
        define(['jquery'], factory);
    } else if (typeof module === 'object' && module.exports) {
        // Node/CommonJS
        module.exports = function( root, jQuery ) {
            if ( jQuery === undefined ) {
                // require('jQuery') returns a factory that requires window to
                // build a jQuery instance, we normalize how we use modules
                // that require this pattern but the window provided is a noop
                // if it's defined (how jquery works)
                if ( typeof window !== 'undefined' ) {
                    jQuery = require('jquery');
                }
                else {
                    jQuery = require('jquery')(root);
                }
            }
            factory(jQuery);
            return jQuery;
        };
    } else {
        // Browser globals
        factory(jQuery);
    }
}(function ($) {

  'use strict';

  // The editor parameter is the current instance.
  $.FroalaEditor.PLUGINS.pasteToggler = function (editor) {
    var clipboard_data = "",
        clipboard_html_local = "",
        content_type = "",
        skipWrapper = false, // To check the clearformat button click.
        showButtonFlag = true,
        in_span = false,
        is_div = false;

    function _init () {
      var def_type = _getFromLocal('editor_paste_type')

      if( def_type == null) {
        // Store the default paste format type in local storiage.
        _storeInLocal('editor_paste_type', 'defaultFormatting');
      }

      _addDefaultClass();

      // Have to store the original clipboard data before paste
      editor.$oel.on('froalaEditor.paste.before', function (e, editor, original_event) { 
        
        // clipboard_data = original_event;
        // if ($.isEmptyObject(clipboard_data) && clipboard_html_local == "") {
          // clipboard_data = $.extend({}, clipboard_data , original_event);
        if (content_type === "" && clipboard_html_local === "") {
          clipboard_data = original_event;

          if(!jQuery.browser.msie && !jQuery.browser.msedge) {
            content_type = _clipboardType(clipboard_data)
          }

          _setPasteFormatType();
        }
      })

      // The clipboard data is not persisting in manual paste trigger event. 
      // So clipboard_html has saved in local.
      editor.$oel.on('froalaEditor.paste.beforeCleanup', function (e, editor, clipboard_html) { 

        if (typeof(clipboard_html) === 'string') {
          clipboard_html_local = clipboard_html;
        }
      })

      // After cleanup the paste content should wrap the content to save the range.
      editor.$oel.on('froalaEditor.paste.afterCleanup', function (e, editor, clipboard_html) {
        var type, check_span, check_div;
        //&& (!check_span && !check_div)
        if (typeof(clipboard_html) === 'string' && !skipWrapper) {

          var anchorNodeTag = jQuery(window.getSelection().anchorNode).prop("tagName")
          var selectionEle = $(editor.selection.element());

          // if(jQuery.browser.msedge) {
          //   // type = true
          //   check_span =  in_span || ( ( anchorNodeTag == undefined || anchorNodeTag == 'SPAN')
          //         && $(editor.selection.element()).find('[rel="clipboard_data"]').prop("tagName") != 'DIV')

          //   check_div = (!in_span) ? true : false;
          // } else 
          if(jQuery.browser.msie || jQuery.browser.msedge) {

            check_span =  in_span || ( ( anchorNodeTag == undefined || anchorNodeTag == 'SPAN')
                  && $(editor.selection.element()).find('[rel="clipboard_data"]').prop("tagName") != 'DIV')

            check_div = (!$(editor.selection.element()).find('[rel="clipboard_data"]').get(0) && !$(editor.selection.element()).parents('[rel="clipboard_data"]').get(0) && $(editor.selection.element()).attr('rel') != 'clipboard_data')
          } else if(jQuery.browser.mozilla) {

            type = /text\/html/.test(content_type);
            check_span = ( type && 
                  (anchorNodeTag == undefined || $(editor.selection.element()).prop("tagName") == 'SPAN' || jQuery(editor.selection.element()).find('[rel="clipboard_data"]').prop('tagName') == 'SPAN') 
                  && window.getSelection().anchorNode.textContent != '\xa0'
                  && $(editor.selection.element()).prop("tagName") != 'DIV' )

            check_div = (type && !$(editor.selection.element()).find('[rel="clipboard_data"]').get(0) && $(editor.selection.element()).attr('rel') != 'clipboard_data')

          }  else if(jQuery.browser.safari) {

              type = /text\/rtf/.test(content_type) 
              check_span = is_div ? false : (  anchorNodeTag == undefined) 
                  // && $(editor.selection.element()).prop("tagName") != 'DIV' )
            
              check_div = is_div ? false : (!$(editor.selection.element()).find('[rel="clipboard_data"]').get(0) && $(editor.selection.element()).attr('rel') != 'clipboard_data')
          } else {

            type = /text\/html/.test(content_type);
            // &&  $(editor.selection.element()).prop("tagName") != 'P'
            check_span = ( type && (anchorNodeTag == undefined) && window.getSelection().anchorNode.textContent != '\xa0'
                  && $(editor.selection.element()).prop("tagName") != 'DIV' )
          
            check_div = (type && !$(editor.selection.element()).find('[rel="clipboard_data"]').get(0) && $(editor.selection.element()).attr('rel') != 'clipboard_data')
          }

          // For inline content or normal text will wrap SPAN
          if (check_span) {
            in_span = true;

            clipboard_html.replace(/<div(.*?)>([\w\W]*?)<\/div>/gi, '<span$1>$2</span>');
            clipboard_html.replace(/<p(.*?)>([\w\W]*?)<\/p>/gi, '<span$1>$2</span>');

            var temp_div = $("<div />")
            var span = $("<span rel='clipboard_data'/>").append(clipboard_html)
              temp_div.append(span);

            return temp_div.html();
          }

          // For Block contant will wrap DIV
          // if (type && !$(editor.selection.element()).find('[rel="clipboard_data"]').get(0) && $(editor.selection.element()).attr('rel') != 'clipboard_data') {
          // if (type && !$(editor.selection.element()).find('[rel="clipboard_data"]').get(0) && !$(editor.selection.element()).parents('[rel="clipboard_data"]').get(0) && $(editor.selection.element()).attr('rel') != 'clipboard_data') {
          if(check_div) {
            is_div = true
            var temp_div = $("<div />");
            var div = $("<div rel='clipboard_data'/>").append(clipboard_html);
            temp_div.append(div);

            return temp_div.html();
          }
        } else {
          skipWrapper = false
        }

        if(!jQuery.browser.msie && !jQuery.browser.msedge && !jQuery.browser.safari) {
          // When pasting the text content, the toggle buttons will not show
          showButtonFlag = false;
        }
      })
  
      editor.$oel.on('froalaEditor.paste.after', function (e, editor, original_event) {
        
        if (showButtonFlag) { _showButton(); }

        // On first time in editor default contant has <P> tag. When we past the content, clipboard wrapper will replace the P. 
        // So, on toggle the formatting button it gets strucked because of the defaul P tag has replace with clipboard wrapper DIV.
        // So manually insertting the P tag
        var element = editor.$el.find('div[rel="clipboard_data"]');
        if(!editor.$el.children('p').get(0) && element.get(0)) {
          element.after("<p><br /></p>");
        }
      })

      editor.$oel.on('froalaEditor.commands.after', function (e, editor, cmd, param1, param2) {     
        if (cmd != "originalFormatting" && cmd != "defaultFormatting" && cmd != "plainText") _clear();
      });

      editor.events.on('keydown', function (e) {
        _clear(e);
      })

      editor.events.on('click', function () {
        _clear();
      })
    }

    function pasteFormat (type) {
      var elemToSelect = $("[rel='clipboard_data']").get(0);

      if (elemToSelect && $('.fr-fromat-btn').is(':visible')) {
//// =========== jQuery.browser.msie || jQuery.browser.msedge ||
        // if( jQuery.browser.safari) {
        //   if (window.getSelection) {
        //     var selection = window.getSelection();
        //     selection.selectAllChildren(elemToSelect);
        //   } 
        // } else {
          if (document.createRange) {
            var rangeObj = document.createRange();
                rangeObj.selectNode(elemToSelect);
                var sel = window.getSelection();
                sel.removeAllRanges();
                sel.addRange(rangeObj);
          }
        // }

        _storeInLocal('editor_paste_type', type);
        _setPasteFormatType(type);
        _setActiveBtn(type);
        showButtonFlag = false;
      } else {

        skipWrapper = true;
        showButtonFlag = false;
        clipboard_html_local = _getSelectedHtml();
        _setPasteFormatType("plainText");
      }

      _triggerPasteEvent();
    }

    function _setPasteFormatType (type) {
      var type = type || _getFromLocal('editor_paste_type'),
          style_index = editor.opts.pasteDeniedAttrs.indexOf('style');

      // To reset the pastePlain value for changing plain text to other formert.
      editor.opts.pastePlain = false;
      //Enable the PasteHangler Plugin
      editor.opts.formatePasteContent = true;

      if (type == "defaultFormatting") {
        if (style_index == -1 ) editor.opts.pasteDeniedAttrs.push('style');
        //Disable the PasteHangler Plugin
        editor.opts.formatePasteContent = false;

      } else if ( type == "originalFormatting") {
        if (style_index != -1 ) editor.opts.pasteDeniedAttrs.splice(2);

      } else {
        // Plain text
        editor.opts.pastePlain = true;
        //Disable the PasteHangler Plugin
        editor.opts.formatePasteContent = false;

      }
    }

    function _clipboardType (data) {
      var types = '';

      // if (!$.isEmptyObject(clipboard_data)) {
      if (clipboard_data != "") {
        var clipboard_types = data.clipboardData.types;

        if (editor.helpers.isArray(clipboard_types)) {
          for (var i = 0 ; i < clipboard_types.length; i++) {
            types += clipboard_types[i] + ';';
          }
        } else {
          types = clipboard_types;
        }
      }

      return types;
    }

    function _getSelectedHtml () {
      var html = '';
      if (window.getSelection) {
        var sel = window.getSelection();

        if (sel.rangeCount) {
          var container = document.createElement("div");

          for (var i = 0, len = sel.rangeCount; i < len; ++i) {
            container.appendChild(sel.getRangeAt(i).cloneContents());
          }
          
          html = container.innerHTML;
        }
      }
      else if (document.selection) {
        if (document.selection.type === "Text") {
          html = document.selection.createRange().htmlText;
        }
      }

      return html;
    }

    function _triggerPasteEvent () {
      var events = jQuery.Event( "paste" );

      events.clipboardData = { 
        dataHTML: clipboard_html_local,
        type: "manual"
      };

      editor.$el.trigger(events);
    }

    function _clear (e) {
      var $element = $("[rel='clipboard_data']");
      // Unwrape the range content
      if($element.get(0)) {

        if ($element.length > 1) {
          // On click ENTER, the clipboard data class has cloned with empty element for list.
          // so remove the last cloned element
          if(e != undefined && e.which == jQuery.FroalaEditor.KEYCODE.ENTER) {
            $element.last().remove()
          }
        }

        editor.selection.save()
        var child = $element.html();
        $element.replaceWith( child  );
        editor.selection.restore();
      }

      // Reset the local values
      clipboard_data = '';
      clipboard_html_local = "";
      content_type = "";
      in_span=false;
      is_div=false;

      _hideButton();
      showButtonFlag = true;
    }

    function _addDefaultClass () {
      $("[data-cmd='plainText']").addClass('fr-paste-formatting');
      $("[data-cmd='defaultFormatting']").addClass('fr-paste-formatting fr-fromat-btn');
      $("[data-cmd='originalFormatting']").addClass('fr-paste-formatting fr-fromat-btn');
    }

    function _setActiveBtn (active_class) {
      var local_value = active_class || "defaultFormatting";

      $(".fr-paste-formatting").removeClass('active');
      $("[data-cmd='" + local_value +"']").addClass('active');
    }

    function _showButton () {
      _setActiveBtn(_getFromLocal('editor_paste_type'));

      setTimeout(function () { 
        $(".fr-fromat-btn").show(300);

        setTimeout(function () { $('.fr-paste-formatting').addClass('fr-flash');}, 500)
        setTimeout(function () { $('.fr-paste-formatting').removeClass('fr-flash'); }, 1000);
      }, 100)
    }

    function _hideButton () {
      $(".fr-fromat-btn").hide(200);
      $(".fr-paste-formatting").removeClass('active');
    }

    function _storeInLocal (key, value) {
      localStorage.setItem(key, JSON.stringify(value));
    }

    function _getFromLocal (key_name) {
      return JSON.parse(localStorage.getItem(key_name))
    }

    return {
      _init: _init,
      pasteFormat: pasteFormat
    }
  }

  $.FE.DefineIcon('plainText', { NAME: 'plain-text' });
  $.FE.RegisterCommand('plainText', {
    title: 'Convert to Plain Text',
    callback: function (type) {
      this.pasteToggler.pasteFormat(type);
    },
    plugin: 'pasteToggler'
  })

  $.FE.DefineIcon('defaultFormatting', { NAME: 'default-format' });
  $.FE.RegisterCommand('defaultFormatting', {
    title: 'Convert to Default Formatting',
    callback: function (type) {
      this.pasteToggler.pasteFormat(type);
    },
    plugin: 'pasteToggler'
  })

  $.FE.DefineIcon('originalFormatting', { NAME: 'preserve-format' });
  $.FE.RegisterCommand('originalFormatting', {
    title: 'Preserve Original Formatting',
    callback: function (type) {
      this.pasteToggler.pasteFormat(type);
    },
    plugin: 'pasteToggler'
  })

}));