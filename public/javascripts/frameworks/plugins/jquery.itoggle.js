/**
 * @author venom
 * Iphone style toggle button
 */

(function($){
  var methods = {
    init : function( options ) {
      return this.each(function(){
        if( $(this).data('itoggle') ) return;

        var opts = $.extend( {}, $.fn.itoggle.defaults, options ),
            _checkbox = $(this),
            opts = $.extend( {}, opts, _checkbox.data()),
            max_length = 6
            trimmedCheckedLabel = opts.checkedLabel.length > max_length ? opts.checkedLabel.substring(0, max_length - 2) + ".." : opts.checkedLabel
            trimmedUncheckedLabel = opts.uncheckedLabel.length > max_length ? opts.uncheckedLabel.substring(0, max_length - 2) + ".." : opts.uncheckedLabel
            _onLabel = $("<span />", { 'class': 'on-label'}).html("<span aria-label="+opts.checkedLabel+" title="+opts.checkedLabel+">"+trimmedCheckedLabel+"</span>"),
            _offLabel = $("<span />", { 'class': 'off-label'}).html("<span aria-label="+opts.uncheckedLabel+" title="+opts.uncheckedLabel+">"+trimmedUncheckedLabel+"</span>"),
            _container = $("<span />", { 'class': 'toggle-container' }),
            _handle = $("<span />", { 'class': 'toggle-handle' }).append("<span></span>"),
            _proxy = $("<p />").html((trimmedCheckedLabel.length > trimmedUncheckedLabel.length) ? trimmedCheckedLabel : trimmedUncheckedLabel),
            _invert = opts.inverted ? !_checkbox.prop('checked') : _checkbox.prop('checked'),
            _ibutton = $("<a />", {
              'href': "#",
              'class': opts.buttonClass + " " + (_invert ? "active" : "")
            }).append(_container)
              .append(_proxy)
              .bind("click", function(ev){
                ev.preventDefault();
                if(_checkbox.prop('disabled')){ return; }
                $(this).toggleClass('active');
                _checkbox
                  .prop("checked", opts.inverted ? !$(this).hasClass('active') : $(this).hasClass('active'))
                  .trigger("change");
              });

        if($(this).prop('disabled')){
          $(_ibutton).addClass(opts.buttonDisabledClass);
        }
        _container.append(_onLabel).append(_handle).append(_offLabel);

        _checkbox.data("button-dom", _ibutton);
        _checkbox.data("itoggle", true);

        $(_checkbox).hide().after(_ibutton);

        // Updating the button class when a change event is triggered for the checkbox
        $(_checkbox).bind("change", function(ev){
          var _ibutton = $(this).data("button-dom");
          $(_ibutton).toggleClass(opts.buttonDisabledClass, (opts.inverted ? !_checkbox.prop('disabled') : _checkbox.prop('disabled')));          
          $(_ibutton).toggleClass('active', (opts.inverted ? !_checkbox.prop('checked') : _checkbox.prop('checked')) );
        });

      });
    }
  };

  $.fn.itoggle = function( method ) {    
    if ( methods[method] ) {
      return methods[method].apply( this, Array.prototype.slice.call( arguments, 1 ));
    } else if ( typeof method === 'object' || ! method ) {
      return methods.init.apply( this, arguments );
    } else {
      $.error( 'Method ' +  method + ' does not exist on jQuery.itoggle' );
    }    
  };

  // publicly accessible defaults
  $.fn.itoggle.defaults = {
    buttonClass: "toggle-button",
    buttonDisabledClass: "toggle-disabled",
    checkedLabel: "on",
    uncheckedLabel: "off",
    activeClass: "",
    inactiveClass: "",
    inverted: false
  };

})( jQuery );