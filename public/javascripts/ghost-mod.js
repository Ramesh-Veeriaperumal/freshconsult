(function( $ ){

  $.fn.ghostWriter = function( options ) {
    var settings = $.extend( {
       ghosttext: "",
       placeholder: "",
       infoclass: "ghostwriter_info",
       copyclass: "ghostwriter_hide"
    }, options);

    return this.each(function(index, item) {        
       item.ghostplaceholder = $(item).attr("data-placeholder") || settings.placeholder;
       item.ghosttext   = $(item).attr("data_ghost_text") || settings.ghosttext;
       item.ghosttextspan = $("<span />").text(item.ghostplaceholder);
       item.ghostCopy = $("<span />").addClass(settings.copyclass);
       item.ghostBox = $("<div />").addClass(settings.infoclass).append(item.ghostCopy).append(item.ghosttextspan);
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
