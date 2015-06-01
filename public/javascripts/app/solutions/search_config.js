window.App = window.App || {};
window.App.Solutions = window.App.Solutions || {};
(function ($) {
  "use strict";
  App.Solutions.SearchConfig = {

    resultsContainer: $('#page_search_results'),
    solutionsContainer: $('.solution-list'),

    onVisit: function () {
      this.bindHandlers();
    },

    bindHandlers: function () {
      this.searchBarSettings();
      $('.community-search').bind("keyup", this.searchStrategy.bind(this));
    },

    searchStrategy: function (e) {
      var searchString = e.target.value.replace(/^\s+|\s+$/g, "");
      var resultList = this.resultsContainer;
      var $this = this;
      if(!searchString.empty() && searchString.length > 1){
        resultList.hide().empty();
        setTimeout(function(){
          $(".community-search").parent().first().addClass("sloading loading-small loading-right");
            $this.fetchSearchResults(searchString);
        }, 450 ); 
      }else{
        resultList.hide();
        $this.solutionsContainer.show();
       $(".community-search").parent().first().removeClass("sloading loading-small loading-right"); 
      }
    },

    searchBarSettings: function () {
      var $this = this;
      $("body").on('click.community-search', '#search-show', function () {
        $('#sticky_search_wrap').addClass('search-ani');
      });
      $("body").on('click.community-search', '#search-hide', function () {
        $('#sticky_search_wrap').removeClass('search-ani');
        $this.resultsContainer.hide();
        $this.resultsContainer.empty();
        $('.community-search').empty();  
        $this.solutionsContainer.show();
      });
    },

    searchCallback: function (data) {
      console.log("Inside searchCallback");
      var resultList = this.resultsContainer;
      var resultHtml = ''
      if(data.results.length){
        data.results.each(function(result){
          var templateName = ["app/search/templates/", result.result_type].join("");
          if(result) { 
            resultHtml += (JST[templateName](result)); 
          }
        })
      } else {
        resultHtml = SEARCH_RESULT_LANG["no_result"]
      }
      resultList.html(resultHtml).show();
      this.solutionsContainer.hide();
      $(".community-search").parent().removeClass("sloading loading-small");
    },

    fetchSearchResults: function (searchString) {
      var $this = this;
      $.ajax({ 
        url: $('.community-search').data('search-url')+encodeURIComponent(searchString),
        dataType: "json",
        success: function(data){
          $this.searchCallback(data);
        }});
    },
    onLeave: function () {
      $('body').off('.community-search');
    }
  };

  }(window.jQuery));