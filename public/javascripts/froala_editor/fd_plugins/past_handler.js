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

  // Custum plugins options
  jQuery.FroalaEditor.DEFAULTS = jQuery.extend(jQuery.FroalaEditor.DEFAULTS, {
    formatePasteContent: true
  });

  // The editor parameter is the current instance.
  $.FroalaEditor.PLUGINS.pasteHandler = function (editor) {

    function solutionSanitize (html) {
      return Sanitizer.cleanMicrosoftContent(html);
    }

    function normalize (editor, html) {
      return Normalize.normalizeContent(editor, html);
    }

    function _init () {
      editor.$oel.on('froalaEditor.paste.beforeCleanup', function (e, editor, clipboard_html) {      
        if (editor.opts.formatePasteContent && typeof(clipboard_html) === 'string') {
          clipboard_html = solutionSanitize(clipboard_html);
          clipboard_html = normalize(editor, clipboard_html);
        }

        return clipboard_html;
      });

      editor.$oel.on('froalaEditor.paste.afterCleanup', function (e, editor, clipboard_html) {      
        
        if (typeof(clipboard_html) === 'string') {
         // To prevent the removing lines.
          clipboard_html = clipboard_html.replace(/\>\s+\</g,'><');

          // Will Remove the wrapped DIV content. For Title content
          clipboard_html = clipboard_html.replace(/<div(.*?)><p(.*?)>((?:[\w\W]*?))<\/p><\/div>/g,'<p $1>$3</p>');
        }

        return clipboard_html;
      });
    }

    return {
      _init: _init
    }
  }

}));