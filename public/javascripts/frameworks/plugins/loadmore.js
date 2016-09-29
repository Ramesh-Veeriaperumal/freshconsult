(function($) {


  var namespace = '.loadMore'
    , CLICK = 'click' + namespace
    , settings = { currentPage: 1
                 , pageIncrement: false // Can Increment currentPage value by default (true) or using options (false)
                 , params: {}
                 , url: location.href
                 , dataType: "html"
                 , pagination: '.pagination'
                 , loadMoreHtml: '<a id="load-more" class="btn" data-loading-text="Loading...">Load more...</a>'
                 , loadMoreButton: '#load-more'
                 , loadMoreAppendAfter: '' // By default appent after the Container element
                 , end: 'this.loadMoreButton.remove()'
                 , loading: 'this.loadMoreButton.button("loading")'
                 , complete: '$this.$el.append(data);$this.loadMoreButton.button("reset")'
                 }
    , $container;

  jQuery.fn.loadmore = function (opts) {
    return this.each(function()
    {
      var $el = $(this);

      var data = $el.data('loadMore');
      if (!data)
      {
        $el.data('loadMore', (data = new Loadmore(this, opts)));
      }
    });
  };

  // Initialization
  var Loadmore = function(element, options)
  {
    this.$el = $(element);
    this.opts = $.extend(settings, options);

    this.currentPage = this.opts.currentPage;

    this.init();
  }

  Loadmore.prototype = {
    // settings params: totalPages
    init: function () {

      var opts = this.opts;

      if(opts.totalPages > opts.currentPage){
        var $appendTo = (opts.loadMoreAppendAfter != '') ? $(opts.loadMoreAppendAfter) : this.$el;

        //load more element
        this.loadMoreHtml = $(this.opts.loadMoreHtml);
        this.loadMoreHtml.insertAfter($appendTo);
        this.loadMoreButton = $(this.opts.loadMoreButton)

        // start the listener
        this.startListener();
      }

      // for accessibility we can keep pagination links
      // but since we have javascript enabled we remove pagination links
      if (opts.pagination) {
        $(opts.pagination).remove();
      }
    },


    stopListener: function() {
      this.loadMoreButton.unbind(namespace);
      this.loadMoreButton.remove();
    },

    // * bind a scroll event
    // * trigger is once in case of reload
    startListener: function() {
      this.loadMoreButton.bind(CLICK, $.proxy(this.triggerLoadMore, this));
    },

    evalAttr: function(attr) {
      if (this.opts[attr]) {
        if(typeof this.opts[attr] == "string")
          eval(this.opts[attr]);
        else
          this.opts[attr].call();
      }
    },

    triggerLoadMore: function(){

      this.evalAttr("loading");
      // commenting changes with respect to pagination
      // move to next page
      //settings.currentPage++;

      var $this = this
      var settings = $this.opts

      var nextPage = ($this.opts.pageIncrement) ? ++$this.currentPage : settings.currentPage + 1;

      // set up ajax query params
      $.extend( settings.params
              , { page: nextPage });
      // finally ajax query
      $.ajax({
          url: settings.url,
          data: settings.params,
          success: function (data) {
            if (settings.complete){
              if(typeof settings.complete == "string")
                eval(settings.complete);
              else
                settings.complete.call();
            }

            //check for avoiding ajax call if next page is greater than total pages
            // listener was stopped or we've run out of pages
            if (settings.totalPages <= nextPage) {
              $this.stopListener();
              // if there is a afterStopListener callback we call it
              $this.evalAttr("end");
            }
          },
          dataType: settings.dataType
      });
    }
  }
})(jQuery);
