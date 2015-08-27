/*jslint browser: true, devel: true */
/*global  App, $H, delay */

window.App = window.App || {};
window.App.Solutions = window.App.Solutions || {};
(function ($) {
  "use strict";
  App.Solutions.SearchConfig = {
    
    currentString: "",

    onVisit: function () {
      this.bindHandlers();
    },

    bindHandlers: function () {
      $('.community-search').bind("keyup", this.searchStrategy.bind(this));
      $("body").on('click.community-search', '#search-show', this.showSearch);
      $("body").on('click.community-search', '#search-hide', this.hideSearch);
    },

    searchStrategy: function (e) {
      var searchString = e.target.value.replace(/^\s+|\s+$/g, ""), resultList = $('#page_search_results'), $this = this;
      if (!searchString.empty() && searchString.length > 1 && this.currentString !== searchString) {
        this.currentString = searchString;
        resultList.hide().empty();
        setTimeout(function () {
          $(".community-search").parent().first().addClass("sloading loading-small loading-right");
          $this.fetchSearchResults(searchString);
        }, 450);
      } else if (this.currentString !== searchString) {
        resultList.hide();
        $('.solution-list').show();
        $(".community-search").parent().first().removeClass("sloading loading-small loading-right");
      }
    },

    showSearch: function () {
      $('#sticky_search_wrap').addClass('search-ani');
      $('#sticky_header').addClass('search-open');
      $('.community-search').focus();
      $('#cm-sb-solutions-toggle').hide()
      $('#fa_item-select-all').prop('disabled', true);
    },

    hideSearch: function () {
      $('#sticky_search_wrap').removeClass('search-ani');
      $('#sticky_header').removeClass('search-open');
      $('#page_search_results').hide().empty();
      $('.community-search').val('');
      $('.solution-list').show();
      $('.sticky_title').show();
      $('#cm-sb-solutions-toggle').show()
      $('#fa_item-select-all').prop('disabled', false);
    },

    searchCallback: function (data) {
      var resultList = $('#page_search_results'), resultHtml = '';
      if (data.results.length) {
        data.results.each(function (result) {
          var templateName = "app/search/templates/solution_context_search";
          if (result) {
            resultHtml += (JST[templateName](result));
          }
        });
      } else {
        resultHtml = SEARCH_RESULT_LANG.no_result;
      }
      resultList.html(resultHtml).show();
      $('.solution-list').hide();
      $(".community-search").parent().removeClass("sloading loading-small");
    },

    fetchSearchResults: function (searchString) {
      var $this = this;
      $.ajax({
        url: $('.community-search').data('search-url') + encodeURIComponent(searchString),
        dataType: "json",
        success: function (data) {
          $this.searchCallback(data);
        }
      });
    },
    onLeave: function () {
      $('body').off('.community-search');
    }
  };
}(window.jQuery));