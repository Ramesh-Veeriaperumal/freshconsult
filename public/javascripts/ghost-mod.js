(function( $ ){

  $.fn.ghostWriter = function( options ) {
    var settings = $.extend( {
       ghosttext: "",
       placeholder: "",
       infoclass: "ghostwriter_info",
       copyclass: "ghostwriter_hide",
       containerClass: "textfield"
    }, options);

    return this.each(function(index, item) {
      console.log(settings.containerClass);
       item.ghostplaceholder = $(item).data("placeholder") || settings.placeholder;
       item.ghosttext   = $(item).data("ghostText") || settings.ghosttext;
       item.ghosttextspan = $("<span />").text(item.ghostplaceholder);
       item.ghostCopy = $("<span />").addClass(settings.copyclass);
       item.ghostBox = $("<div />").addClass(settings.infoclass).append(item.ghostCopy).append(item.ghosttextspan);
       $(item).wrap("<div class='"+settings.containerClass+"' />");
       $(item).parent().addClass('ghostenabled');
       $(item).parent().prepend(item.ghostBox);
       $(item).bind("keyup keydown keypress change", 
                     function(ev){
                        item.ghostCopy.text($(item).val());
                        if($.trim($(item).val()) == "")
                           item.ghosttextspan.text(item.ghostplaceholder);
                        else
                           item.ghosttextspan.text(item.ghosttext);
                     })
               .focusin(function(){
                  $(item).parent().addClass("active");
               })
               .focusout(function(){
                  $(item).parent().removeClass("active");
               });        
    });   
  };
})( jQuery );
	jQuery(function() {
		jQuery("[rel=ghostwriter]").ghostWriter();
		jQuery('#configs_domain').change();
	});
