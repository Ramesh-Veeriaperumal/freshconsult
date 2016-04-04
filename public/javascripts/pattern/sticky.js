(function($){
  "use strict";

  /* 
   *  ==== Sticky class definition ====
     */
    var Sticky = function(element, options){
      this.element = $(element);
      this.options = $.extend({}, $.fn.sticky.defaults, options, $(element).data());

      this.parentEle = this.element.parent();
      if (this.options.parent_selector != null) {
        this.parentEle = this.parentEle.closest(this.options.parent_selector);
      }

      if (!this.parentEle.length) {
        throw "failed to find stick parent";
      }

      this.fixed = false;
      this.bottomed = false;
      this.doRefresh = false;
      this.spacer = $("<div />");
      this.spacer.css('position', this.element.css('position'));
      this.last_pos = void 0;
      this.top = 0;
      this.height = 0;
      this.el_float = 'none';
      this.offset = "";

      this.init();
    };


  Sticky.prototype = {
      init: function() {    
        $(window).on("touchmove.sticky", $.proxy(this.tick, this));
        $(window).on("scroll.sticky", $.proxy(this.tick, this));
        $(window).on("resize.sticky", $.proxy(this.recalc_and_tick, this));

        $(document).on("recalc.sticky", $.proxy(this.recalc_and_tick, this));

        this.recalc_and_tick();
      },
      recalc: function(){
        var border_top, padding_top, restore , parentElement = this.parentEle;
        var ele = this.element;
          border_top = parseInt(parentElement.css("border-top-width"), 10);
          padding_top = parseInt(parentElement.css("padding-top"), 10);

          this.padding_bottom = parseInt(parentElement.css("padding-bottom"), 10);
          this.parent_top = parentElement.offset().top + border_top + padding_top;
          this.parent_height = parentElement.height();

          restore = this.fixed ? (this.fixed = false, this.bottomed = false, ele.insertAfter(this.spacer).css({
            position: "",
            top: "",
            width: "",
            bottom: ""
          }), this.spacer.detach(), true) : void 0;

          this.top = ele.offset().top - parseInt(ele.css("margin-top"), 10) - this.options.offset_top;

          this.height = ele.outerHeight(true);

          this.el_float = ele.css("float");

          this.spacer.css({
            width: ele.outerWidth(true),
            height: this.height,
            display: ele.css("display"),
            "vertical-align": ele.css("vertical-align"),
            "float": this.el_float
          });

          if (restore) {
            return this.tick();
          }
      },
      tick: function(){
      var css, delta, scroll, will_bottom, win_height;
      var ele = this.element;

      scroll = $(window).scrollTop();

      if (this.last_pos != null) {
        delta = scroll - this.last_pos;
      }

      this.last_pos = scroll;

      if (this.fixed) {

        will_bottom = scroll + this.height + this.options.offset_top > this.parent_height + this.parent_top;

        if (this.bottomed && !will_bottom) {
          this.bottomed = false;

          ele.css({
            position: "fixed",
            bottom: "",
            top: this.options.offset_top
          }).trigger("sticky_kit:unbottom");
        }

        if (scroll < this.top) {
          this.fixed = false;
          
          this.offset = this.options.offset_top;

          if (this.el_float === "left" || this.el_float === "right") {
            ele.insertAfter(this.spacer);
          }

          this.spacer.detach();

          css = {
            position: "",
            width: "",
            top: ""
          };

          ele.css(css).removeClass(this.options.sticky_class).trigger("sticky_kit:unstick");
        }

        if (this.options.inner_scrolling) {
          win_height = $(window).height();

          if (this.height > win_height) {
            if (!this.bottomed) {
              this.offset -= delta;
              this.offset = Math.max(win_height - this.height, this.offset);
              this.offset = Math.min(this.options.offset_top, this.offset);

              if (this.fixed) {
                ele.css({
                  top: this.offset + "px"
                });
              }
            }
          }
        }
      } else {
        if (scroll > this.top) {
          this.fixed = true;
          css = {
            position: "fixed",
            top: this.options.offset_top
          };
          css.width = ele.css("box-sizing") === "border-box" ? ele.outerWidth() + "px" : ele.width() + "px";
          ele.css(css).addClass(this.options.sticky_class).after(this.spacer);

          if (this.el_float === "left" || this.el_float === "right") {
            this.spacer.append(ele);
          }
          ele.trigger("sticky_kit:stick");
        }
      }

      if (this.fixed) {
        if (will_bottom == null) {
          will_bottom = scroll + this.height + this.offset > this.parent_height + this.parent_top;
        }
        if (!this.bottomed && will_bottom && !this.options.elm_bottom) {

          // Just before sticking the element to the bottom of the parent, do a force recalculation [recalc()] of values
          // to check the changes in height of the parent and make necessary changes [tick()].
          if(!this.doRefresh) {
            this.doRefresh = true;
            this.recalc();
            return this.tick();
          }
          else {
            this.doRefresh = false;
          }

          this.bottomed = true;

          return ele.css({
            position: "absolute",
            bottom: this.padding_bottom,
            top: "auto"
          }).trigger("sticky_kit:bottom");
        }
      }
      },
      recalc_and_tick: function(ev){
        this.recalc();
        return this.tick();
      },
      detach: function(){

        if (this.fixed) {
          this.element.insertAfter(this.spacer).removeClass(this.options.sticky_class);
          return this.spacer.remove();
        }

        $(window).off(".sticky");
        this.element.off("sticky_kit:stick").off("sticky_kit:unstick")
        this.element.removeData("sticky");

        delete this.element;
        delete this.parentEle;
        delete $(this.parentEle).prevObject;
      }
  }

    /* 
     *  ==== Sticky plugin definition ====
     */

  $.fn.sticky = function(option) {
    return this.each(function() {
      var $this = $(this),
      data    = $this.data("sticky"),
      options   = typeof option == "object" && option
      if (!data) $this.data("sticky", (data = new Sticky(this,options)))
      if (typeof option == "string") data[option]() 
    });
  }

  // Sticky default values
  $.fn.sticky.defaults = {

    sticky_class: "is_stuck",

    offset_top: 0,

    parent_selector: void 0,

    inner_scrolling: true,

    elm_bottom: false

  }

})(window.jQuery);