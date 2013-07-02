!function( $ ) {

  $(function () {

    "use strict"

    var $spin_default = {
      lines: 8, // The number of lines to draw
      length: 3, // The length of each line
      width: 2, // The line thickness
      radius: 8, // The radius of the inner circle
      color: '#000', // #rbg or #rrggbb
      corners: 1,
      speed: 1.6, // Rounds per second
      trail: 44, // Afterglow percentage
      shadow: false, // Whether to render a shadow      
      top: 'auto',          // center vertically
      left: 'auto',         // center horizontally
    }, $spin_small = {
        lines: 8, length: 3, width: 2, radius: 4
    }, $spin_left = {
        left:0,
    }, $spin_right = {
        left:'right',
    }, $spin_redactor = {
        color: '#000',
    };

    $(".sloading").livequery(function(){     
      var opts = $spin_default;
      if ($($(this).parent()).is(':hidden')) {
        $(this).addClass("loading-align");
      }
      
        if($(this).hasClass("loading-small")){
        $.extend(opts, $spin_small);}
        if($(this).hasClass("loading-with-text")){
          if(!$(this).hasClass("loading-align"))
            $(this).addClass('loading-align')
          var textWidth = -($(this).find('span').width() / 4) - 10;
          $.extend(opts, {left: textWidth});  
        }

        if($(this).hasClass("loading-left")){
          $.extend(opts, $spin_left);}
        else if($(this).hasClass("loading-right")){
          $.extend(opts, $spin_right);}
        else if($(this).hasClass("redactor-loading")){
          $.extend(opts, $spin_redactor);}
        

        $(this).spin(opts);
      
    }, function(){
      $(this).spin(false); 
    });


  })

}(window.jQuery);
