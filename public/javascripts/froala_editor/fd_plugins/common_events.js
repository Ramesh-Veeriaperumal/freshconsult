(function ($) {
  $.FroalaEditor.DEFAULTS = $.extend($.FroalaEditor.DEFAULTS, {
    SANDBOX_BLACKLIST: ["allow-pointer-lock", "allow-popups", "allow-modals", "allow-top-navigation"]
  });

  // The editor parameter is the current instance.
  $.FroalaEditor.PLUGINS.commonEvents = function (editor) {

    function _init () {

      // Register shortcut event for fullscreen Escape
      editor.events.on('keydown', function (ev) {
        var key_code = ev.which;
        if (editor.fullscreen.isActive() && key_code == $.FE.KEYCODE.ESC) {
          ev.preventDefault();
          editor.fullscreen.toggle();
          $(editor.opts.toolbarContainer).removeClass('fr-fullscreen');
        }
      })

      editor.$oel.on('froalaEditor.commands.after', function (e, editor, cmd, param1, param2) {
      // Do something here.
        if (cmd == "fullscreen") {
          $(editor.opts.toolbarContainer).toggleClass('fr-fullscreen');
        } else if (cmd == "html") {

          if (!editor.$oel.froalaEditor('codeView.isActive') && $('.fr-element').get(0)) {
            var opts = editor.opts.SANDBOX_BLACKLIST;
            var iframe = $('.fr-element').find('iframe');

            _checkIframeSandbox(iframe, opts);
          }
        }

      });

      editor.$oel.on('froalaEditor.commands.before', function (e, editor, cmd, param1, param2) {

        // For insert Quore triggered from the paragraph format list
        if (cmd == "paragraphFormat" && param1 == "BLOCKQUOTE") {
          e.preventDefault();
          var $block = jQuery(editor.selection.blocks());

          if ($block.get(0).tagName == "BLOCKQUOTE" || $block.parent().get(0).tagName == "BLOCKQUOTE") {
            editor.$oel.froalaEditor('quote.apply', 'decrease');
          } else {
            editor.$oel.froalaEditor('quote.apply', 'increase');
          }

          return false;
        } 

      });

      var form = editor.$oel.get(0).form;
      $(form).on('submit', function () {
        var textarea = jQuery(this).find('#solution_article_description'),
            temp_ele = $("<div />").append(textarea.val()),
            iframe = temp_ele.find('iframe'),
            opts = textarea.data('froala.editor').opts.SANDBOX_BLACKLIST;

        _checkIframeSandbox(iframe, opts);

        jQuery(this).find('#solution_article_description').val(temp_ele.html())
      })
    }

    function _checkIframeSandbox (iframe, opts) {
      iframe.each(function() {
        var sandbox = $(this).attr('sandbox') ? $(this).attr('sandbox').split(" ") : ["allow-scripts", "allow-forms", "allow-same-origin", "allow-presentation"];
        var filter = sandbox.filter(function(x) { return (opts.indexOf(x) < 0 ) });

        $(this).attr('sandbox', filter.join(" "))
      })
    }

    return {
      _init: _init
    }
  }
})(jQuery);