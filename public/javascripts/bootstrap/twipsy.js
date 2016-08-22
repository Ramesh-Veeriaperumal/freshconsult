/* ==========================================================
 * bootstrap-twipsy.js v1.4.0
 * http://twitter.github.com/bootstrap/javascript.html#twipsy
 * Adapted from the original jQuery.tipsy by Jason Frame
 * ==========================================================
 * Copyright 2011 Twitter, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ========================================================== */


!function( $ ) {

  "use strict"

 /* CSS TRANSITION SUPPORT (https://gist.github.com/373874)
  * ======================================================= */

  var transitionEnd

  $(document).ready(function () {

    $.support.transition = (function () {
      var thisBody = document.body || document.documentElement
        , thisStyle = thisBody.style
        , support = thisStyle.transition !== undefined || thisStyle.WebkitTransition !== undefined || thisStyle.MozTransition !== undefined || thisStyle.MsTransition !== undefined || thisStyle.OTransition !== undefined
      return support
    })()

    // set CSS transition event type
    if ( $.support.transition ) {
      transitionEnd = "TransitionEnd"
      if ( $.browser.webkit ) {
      	transitionEnd = "webkitTransitionEnd"
      } else if ( $.browser.mozilla ) {
      	transitionEnd = "transitionend"
      } else if ( $.browser.opera ) {
      	transitionEnd = "oTransitionEnd"
      }
    }

  })


 /* TWIPSY PUBLIC CLASS DEFINITION
  * ============================== */

  var Twipsy = function ( element, options ) {
    this.$element = $(element)
    this.options = options
    this.enabled = true
    this.fixTitle()
  }

  Twipsy.prototype = {

    show: function() {
      var pos
        , actualWidth
        , actualHeight
        , placement
        , $tip
        , tp
        
      if (this.hasContent() && this.enabled) {
        
        $tip = this.tip()
                
        this.setContent()

        if (this.options.animate) {
          $tip.addClass('fade')
        }

        $tip
          .css({ top: 0, left: 0, display: 'block' })
          .prependTo(document.body)

        pos = $.extend({}, this.$element.offset(), {
          width: this.$element[0].offsetWidth
        , height: this.$element[0].offsetHeight
        })

        actualWidth = $tip[0].offsetWidth
        actualHeight = $tip[0].offsetHeight
        placement = maybeCall(this.options.placement, this, [ $tip[0], this.$element[0] ])
        
        this.checkPlacement(placement, pos, actualWidth, actualHeight, $tip);

      }
    }

  , checkPlacement: function (placement, pos, actualWidth, actualHeight, $tip) {
      var tp = this.setPlacement(placement, pos, actualWidth, actualHeight );

      if((tp.left + $tip.innerWidth()) > (window.innerWidth - 50)) {
        placement = "left";
        tp = this.setPlacement(placement, pos, actualWidth, actualHeight);
      } else if ((tp.top + $tip.innerHeight()) > (window.innerHeight - 50)){
        placement = "above";
        tp = this.setPlacement(placement, pos, actualWidth, actualHeight);
      }

      $tip.css(tp)
          .addClass(placement)
          .addClass('in')
  }

  , setPlacement: function (placement, pos, actualWidth, actualHeight) {
      var tp;
      switch (placement) {
        case 'below':
          tp = {top: pos.top + pos.height + this.options.offset, left: pos.left + pos.width / 2 - actualWidth / 2}
          break
        case 'above':
          tp = {top: pos.top - actualHeight - this.options.offset, left: pos.left + pos.width / 2 - actualWidth / 2}
          break
        case 'left':
          tp = {top: pos.top + pos.height / 2 - actualHeight / 2, left: pos.left - actualWidth - this.options.offset}
          break
        case 'topLeft':
          tp = {top: pos.top - (pos.height + 10), left: pos.left - actualWidth - this.options.offset}
          break
        case 'right':
          tp = {top: pos.top + pos.height / 2 - actualHeight / 2, left: pos.left + pos.width + this.options.offset}
          break
        case 'topRight':
          tp = {top: pos.top - (pos.height + 10), left: pos.left + this.options.offset}
          break
        case 'belowLeft':
          tp = {top: pos.top + pos.height + this.options.offset, left: pos.left + pos.width - actualWidth  + this.options.offset}
          break
        case 'belowRight':
          tp = {top: pos.top + pos.height + this.options.offset, left: pos.left + pos.width/2  - actualWidth/5 + this.options.offset}
          break
      }

      return tp;
    }

  , setContent: function () {
      var $tip = this.tip()
      $tip.find('.twipsy-inner')[this.options.html ? 'html' : 'text'](this.getTitle())
      $tip[0].className = 'twipsy'
      this.$element.attr("twipsy-content-set", true)
    }

  , hide: function() {
      var that = this
        , $tip = this.tip()

      $tip.removeClass('in')
      $tip.css({'display':"none"});
      // if($.browser.opera)
      // {
      //   $tip.remove();
      // }

      // function removeElement () {
      //   $tip.remove();
      // }

      // $.support.transition && this.$tip.hasClass('fade') ?
      //   $tip.bind(transitionEnd, removeElement) :
      //   removeElement()
    }

  , fixTitle: function() {
      var $e = this.$element
      if ($e.attr('title') || typeof($e.attr('data-original-title')) != 'string') {
        $e.attr('data-original-title', $e.attr('title') || '').removeAttr('title')
      }
    }

  , hasContent: function () {
      return this.getTitle()
    }

  , getTitle: function() {
      var title
        , $e = this.$element
        , o = this.options

        this.fixTitle()

        if (typeof o.title == 'string') {
          title = $e.attr(o.title == 'title' ? 'data-original-title' : o.title)
        } else if (typeof o.title == 'function') {
          title = o.title.call($e[0])
        }

        title = ('' + title).replace(/(^\s*|\s*$)/, "")

        return title || o.fallback
    }

  , tip: function() {
      return this.$tip = this.$tip || $('<div class="twipsy" />').html(this.options.template)
    }

  , validate: function() {
      if (!this.$element[0].parentNode) {
        this.hide()
        this.$element = null
        this.options = null
      }
    }

  , enable: function() {
      this.enabled = true
    }

  , disable: function() {
      this.enabled = false
    }

  , toggleEnabled: function() {
      this.enabled = !this.enabled
    }

  , toggle: function () {
      this[this.tip().hasClass('in') ? 'hide' : 'show']()
    }

  }


 /* TWIPSY PRIVATE METHODS
  * ====================== */

   function maybeCall ( thing, ctx, args ) {
     return typeof thing == 'function' ? thing.apply(ctx, args) : thing
   }

 /* TWIPSY PLUGIN DEFINITION
  * ======================== */

  $.fn.twipsy = function (options) {
    $.fn.twipsy.initWith.call(this, options, Twipsy, 'twipsy')
    return this
  }

  $.fn.twipsy.initWith = function (options, Constructor, name) {
    var twipsy
      , binder
      , eventIn
      , eventOut

    if (options === true) {
      return this.data(name)
    } else if (typeof options == 'string') {
      twipsy = this.data(name)
      if (twipsy) {
        twipsy[options]()
      }
      return this
    }

    options = $.extend({}, $.fn[name].defaults, options)
    
    function get(ele) {
      var twipsy = $.data(ele, name)

      if (!twipsy) {
        twipsy = new Constructor(ele, $.fn.twipsy.elementOptions(ele, options))
        $.data(ele, name, twipsy)
      }

      return twipsy
    }

    function enter() {
      var twipsy = get(this)
      twipsy.hoverState = 'in'

      if (options.delayIn == 0) {
        twipsy.show()
      } else {
        twipsy.fixTitle()
        setTimeout(function() {
          if (twipsy.hoverState == 'in') {
            twipsy.show()
          }
        }, options.delayIn)
      }
    }

    function leave() {
      var twipsy = get(this)
      twipsy.hoverState = 'out'
      if (options.delayOut == 0) {
            twipsy.hide()
      } else {
        setTimeout(function() {
          if (twipsy.hoverState == 'out') {
            twipsy.hide()
          }
        }, options.delayOut)
      }
    }

    if (!options.live) {
      this.each(function() {
        get(this)
      })
    }

    if (options.trigger != 'manual') {
      binder   = options.live ? 'on' : 'bind'
      eventIn  = options.trigger == 'hover' ? 'mouseenter' : 'focus'
      eventOut = options.trigger == 'hover' ? 'mouseleave' : 'blur'
      this[binder](eventIn, enter)[binder](eventOut, leave)
    }

    return this
  }

  $.fn.twipsy.Twipsy = Twipsy

  $.fn.twipsy.defaults = {
    animate: true
  , delayIn: 0
  , delayOut: 0
  , fallback: ''
  , placement: 'above'
  , html: false
  , live: false
  , offset: 0
  , title: 'title'
  , trigger: 'hover'
  , template: '<div class="twipsy-arrow"></div><div class="twipsy-inner"></div>'
  }

  $.fn.twipsy.rejectAttrOptions = [ 'title' ]

  $.fn.twipsy.elementOptions = function(ele, options) {
    var data = $(ele).data()
      , rejects = $.fn.twipsy.rejectAttrOptions
      , i = rejects.length

    while (i--) {
      delete data[rejects[i]]
    }
    //RTL 
    if ($("html").attr("dir") == "rtl"){
      switch(data['placement']){
        case 'right':
          data['placement'] = "left"
          break
        case 'topRight':
          data['placement'] = "topLeft"
          break
        case 'belowRight':
          data['placement'] = "belowLeft"
          break
        case 'left':
          data['placement'] = "right"
          break
        case 'topLeft':
          data['placement'] = "topRight"
          break
        case 'belowLeft':
          data['placement'] = "belowRight"
          break
      }
    }

    return $.extend({}, options, data)
  }

}( window.jQuery || window.ender );