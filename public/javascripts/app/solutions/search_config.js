/*jslint browser: true, devel: true */
/*global  App, $H, delay, JST, SEARCH_RESULT_LANG */

window.App = window.App || {};
window.App.Solutions = window.App.Solutions || {};
(function ($) {
  "use strict";
  App.Solutions.SearchConfig = {
    
    currentString: "",
    languageChange: false,

    onVisit: function () {
      this.bindHandlers();
    },

    bindHandlers: function () {
      var $this = this;
      $this.formatTranslationDropdown();
      $("body").on('keyup.community-search', '.community-search', $this.searchStrategy.bind($this));
      $("body").on('click.community-search', '#search-show', $this.showSearch);
      $("body").on('click.community-search', '#search-hide', $this.hideSearch);
      $("body").on('change.community-search', '#language_select', function () {
        $this.languageChange = true;
        $('.community-search').trigger('keyup');
      });
    },

    searchStrategy: function (e) {
      if (e.target.value === undefined || e.target.value === null) { return; }
      var searchString = e.target.value.replace(/^\s+|\s+$/g, ""), resultList = $('#page_search_results'), $this = this;
      if (!searchString.empty() && searchString.length > 1 && (this.currentString !== searchString || this.languageChange)) {
        this.currentString = searchString;
        resultList.hide().empty();
        setTimeout(function () {
          $(".community-search").parent().first().addClass("sloading loading-small loading-right");
          $('#search-hide').hide();
          $this.fetchSearchResults(searchString);
        }, 450);
      } else if (this.currentString !== searchString) {
        resultList.hide();
        $('.solution-list').show();
        $(".community-search").parent().first().removeClass("sloading loading-small loading-right");
        $('#search-hide').show();
      }
    },

    showSearch: function () {
      $('#sticky_search_wrap').addClass('search-ani');
      $('#sticky_header').addClass('search-open');
      $('.community-search').focus();
      $('#cm-sb-solutions-toggle').hide();
      $('#fa_item-select-all').prop('disabled', true);
      $('#search-show').data().twipsy.hide();
    },

    hideSearch: function () {
      $('#sticky_search_wrap').removeClass('search-ani');
      $('#sticky_header').removeClass('search-open');
      $('#page_search_results').hide().empty();
      $('.community-search').val('');
      $('.solution-list').show();
      $('.sticky_title').show();
      $('#cm-sb-solutions-toggle').show();
      $('#fa_item-select-all').prop('disabled', false);
    },

    formatTranslationDropdown: function () {
      $('#language_select').select2(
        $.extend({}, App.Solutions.translationDropdownOpts, {
          dropdownCssClass: "language-select-solution-search"
        })
      );
    },

    searchCallback: function (data) {
      if ($('body .community-search').val() === "") { return; }
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
      $('#search-hide').show();
    },

    fetchSearchResults: function (searchString) {
      var $this = this;
      $.ajax({
        url: $this.ajaxURL(searchString),
        dataType: "json",
        success: function (data) {
          $this.searchCallback(data);
        }
      });
    },

    ajaxURL: function (searchString) {
      if (this.languageChange) {
        return $('.community-search').data('search-url') + encodeURIComponent(searchString) + '&language_id=' + $('#language_select').val();
      } else {
        return $('.community-search').data('search-url') + encodeURIComponent(searchString);
      }
    },

    onLeave: function () {
      $('body').off('.community-search');
    }
  };
}(window.jQuery));