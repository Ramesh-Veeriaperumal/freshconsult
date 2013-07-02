!function( $ ) {

  $(function () {

    "use strict"

    var $spin_default = {
      lines: 11, // The number of lines to draw
      length: 6, // The length of each line
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
    };

    $(".sloading").livequery(function(){     
      var opts = $spin_default;
      if ($($(this).parent()).is(':hidden')) {
        $(this).addClass("loading-align");
      }
      
        if($(this).hasClass("loading-small")){
        $.extend(opts, $spin_small);}

        if($(this).hasClass("loading-left")){
          $.extend(opts, $spin_left);}
        else if($(this).hasClass("loading-right")){
          $.extend(opts, $spin_right);}
        

        $(this).spin(opts);
      
    }, function(){
      $(this).spin(false); 
    });


  })

}(window.jQuery);
