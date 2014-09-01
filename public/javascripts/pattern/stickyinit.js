(function($){
  window['SetupSticky'] = function(){
    var $self = this;

    $("[rel=sticky]").each(function(){
      var prev_ele = $(this).data( "stickyPrevious" );
      var scroll_top = $(this).data( "scrollTop" );
      var scroll_bottom = $(this).data( "stickyBottom" );
      var parent_selector = $(this).data( "parentSelector" ) || void(0);

      if($(this).data("collapsed"))
        $self.collapsed($(this));

      if(prev_ele != null){
        var prev_ele_height = $('#'+prev_ele).outerHeight(true);
        $(this).stick_in_parent({
          "offset_top" :  prev_ele_height,
          "parent_selector": parent_selector,
          "elm_bottom": scroll_bottom
        });
        $(this).addClass('sticky-child');
      }else{
        $(this).stick_in_parent({
            "parent_selector": parent_selector,
            "elm_bottom": scroll_bottom
          })
          .on("sticky_kit:stick", function(e){
            if(scroll_top){
              if(!$('#scroll-to-top').length){
                $(this).append("<i id='scroll-to-top'></i>")
              }
              $('#scroll-to-top').addClass('visible');
            }
          })
          .on("sticky_kit:unstick", function(e){
            if(scroll_top){$('#scroll-to-top').removeClass('visible');}
          });
      }
    });
  }

  SetupSticky.prototype = {
    constructor: SetupSticky,

    collapsed: function(ele){
      if (!ele.length) return;

      $(window).on('resize.freshdesk', function() {
        //Extra buffer 20px
        var width_elements_visible = 20,
            to_collapse = false;

        ele.each(function(){
          ele.children().each(function(){
            width_elements_visible += $(this).outerWidth(false);
          });
        });

        if(ele.hasClass('collapsed')) {
          var hidden_elements_width = 0;
          ele.find('.hide_on_collapse').each(function() {
            hidden_elements_width += $(this).outerWidth(false);
          });
          if(ele.width() < (width_elements_visible + hidden_elements_width)) {
            to_collapse = true;
          }
        } else {
          to_collapse = ele.width() < width_elements_visible;
        }
        ele.toggleClass('collapsed', to_collapse);
      }).trigger('resize');
    },

    destroy: function(){
      $(window).off('resize.freshdesk');
      $("[rel=sticky]").each(function(){
        $(this).trigger("sticky_kit:detach");
        $(this).off("sticky_kit:stick").off("sticky_kit:unstick")
      })
    }
  }
}(jQuery));
