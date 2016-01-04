/* ===========================================================
 * FDPopover.js v1.0.0
 * =========================================================== */


!function( $ ) {

 "use strict";

  var FDPopover = function ( element, options ) {
    this.$element = $(element);
    this.options = options;
    this.enabled = true;
  };

  /* NOTE: FDPopover EXTENDS BOOTSTRAP-TWIPSY.js
     ========================================= */

  FDPopover.prototype = $.extend({}, $.fn.twipsy.Twipsy.prototype, {

    show: function() {
      var pos, actualWidth, actualHeight, placement, $tip, tp, $arrow,arrow_pos, targetPos;

      if (this.hasContent() && this.enabled) {

        $tip = this.tip();
        $arrow = $($tip.find(".arrow")[0]);

        this.setContent();

        if (this.options.animate) {
          $tip.addClass('fade');
        }


        $tip.find('.fd-popover-close').on('click', function(){
          $tip.hide();
        });

        $tip
          .css({ top: 0, left: 0, display: 'block' })
          .prependTo(document.body);

        targetPos = this.$element.offset();
        pos = $.extend({}, this.$element.offset(), {
          width: this.$element[0].offsetWidth,
          height: this.$element[0].offsetHeight
        });

        actualWidth = $tip[0].offsetWidth;
        actualHeight = $tip[0].offsetHeight;
        placement = maybeCall(this.options.placement, this, [ $tip[0], this.$element[0] ]);

        switch (placement) {
          case 'below':
            tp = {top: 0 , left: pos.left + pos.width / 2 - actualWidth / 2};
            break;
          case 'above':
            tp = {top: 0 , left: pos.left + pos.width / 2 - actualWidth / 2};
            break;
          case 'left':
            tp = {top: pos.height + 90 , left: pos.left - actualWidth - this.options.offset};
            arrow_pos = {top: targetPos.top / 2 -  this.$element[0].offsetHeight};
            break;
          case 'topLeft':
            tp = {top: 0 , left: pos.left - actualWidth - this.options.offset};
            break;
          case 'right':
            tp = {top: pos.height + 90 , left: pos.left + pos.width + this.options.offset};
            arrow_pos = {top: targetPos.top / 2 -  this.$element[0].offsetHeight,left: -2};
            break;
          case 'topRight':
            tp = {top: 0 , left: pos.left + this.options.offset};
            break;
          case 'belowLeft':
            tp = {top: 0 , left: pos.left + pos.width - actualWidth  + this.options.offset};
            break;
          case 'belowRight':
            tp = {top: 0 , left: pos.left + pos.width/2  - actualWidth/5 + this.options.offset};
            break;
        }

        $arrow.css(arrow_pos);

        $tip
          .css(tp)
          .addClass(placement)
          .addClass('in');


      }
    },


    setContent: function () {
      if(this.options.reloadContent || !this.$element.attr("twipsy-content-set")){
         var $tip = this.tip();
         $tip.find('.content')[this.options.html ? 'html' : 'text'](this.getContent());
         $tip[0].className = 'fd-popover';
         this.$element.attr("twipsy-content-set", true);
      }
    },
    hasContent: function () {
      return this.getContent();
    },
    getContent: function () {
      var content, $e = this.$element, o = this.options;

      if (typeof this.options.content == 'string') {
        content = $e.attr(this.options.content);
      } else if (typeof this.options.content == 'function') {
        content = this.options.content.call(this.$element[0]);
      }

      return content;
    },

    tip: function() {
      if (!this.$tip) {
        this.$tip = $('<div class="fd-popover"  rel="sticky" data-collapsed="true" data-scroll-top="true" data-sticky-bottom="true" />')
          .html(this.options.template);
      }
      return this.$tip;
    }

  });

  /* FDPopover PRIVATE METHODS
   * ====================== */

    function maybeCall ( thing, ctx, args ) {
      return typeof thing == 'function' ? thing.apply(ctx, args) : thing;
    }

 /* FDPopover PLUGIN DEFINITION
  * ======================= */

  $.fn.fdpopover = function (options) {
    if (typeof options == 'object') {
      options = $.extend({}, $.fn.fdpopover.defaults, options);
    }
    $.fn.twipsy.initWith.call(this, options, FDPopover, 'fdpopover');
    return this;
  };
  var $placement = ($("html").attr("dir") == "rtl") ? 'left' :'right';
  $.fn.fdpopover.defaults = $.extend({} , $.fn.twipsy.defaults, {
    placement: $placement,
    content: 'data-content',
    reloadContent : true,
    template: '<div class="arrow"></div><div class="inner"><button type="button" class="fd-popover-close" data-dismiss=fd-popover">&times;</button><div class="content"></div></div>'
  });



  $.fn.twipsy.rejectAttrOptions.push( 'content' );

}(window.jQuery);
