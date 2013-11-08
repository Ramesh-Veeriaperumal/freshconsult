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
            _onLabel = $("<span />", { 'class': 'on-label'}).html("<span>"+opts.checkedLabel+"</span>"),
            _offLabel = $("<span />", { 'class': 'off-label'}).html("<span>"+opts.uncheckedLabel+"</span>"),
            _container = $("<span />", { 'class': 'toggle-container' }),
            _handle = $("<span />", { 'class': 'toggle-handle' }).append("<span></span>"),
            _proxy = $("<p />").html((opts.checkedLabel.length > opts.uncheckedLabel.length) ? opts.checkedLabel : opts.uncheckedLabel)
            _invert = opts.inverted ? !_checkbox.prop('checked') : _checkbox.prop('checked'),
            _ibutton = $("<a />", {
              'href': "#",
              'class': opts.buttonClass + " " + (_invert ? "active" : "")
            }).append(_container)
              .append(_proxy)
              .bind("click", function(ev){
                ev.preventDefault();
                $(this).toggleClass('active');
                _checkbox
                  .prop("checked", opts.inverted ? !$(this).hasClass('active') : $(this).hasClass('active'))
                  .trigger("change");
              });

        _container.append(_onLabel).append(_handle).append(_offLabel);

        _checkbox.data("button-dom", _ibutton);
        _checkbox.data("itoggle", true);

        $(_checkbox).hide().after(_ibutton);

        // Updating the button class when a change event is triggered for the checkbox
        $(_checkbox).bind("change", function(ev){
          var _ibutton = $(this).data("button-dom");
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
    checkedLabel: "on",
    uncheckedLabel: "off",
    activeClass: "",
    inactiveClass: "",
    inverted: false
  };

})( jQuery );