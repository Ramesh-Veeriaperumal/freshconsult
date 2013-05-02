(function( $ ){
  
  var self           = null,
      tweetlist      = $("<div />"),
      loading        = $("<div class='loadingbox' />"),
      new_result     = $("<div class='info-highlight center' />").hide(),
      counter        = $("<a href='#' />")
                           .bind("click", function(ev){ ev.preventDefault(); prependTweets(); });
      tweetsettings  = null,
      fresh_results  = [];  
  
  var settings = {
                'searchurl'       : '',
                'query'           : '',
                'twitter_handle'  : '',
                'resultsperpage'  : 10,
                'refresh_timeout' : 63000,
                'templateid'      : '',
                onbeforeload      : function(){},
                onafterload       : function(){}
  };
  
  populateTweets = function(response, status, xhr){

    if($.param({q:settings.query}) == ("q="+response.attrs["search_metadata"].query)){
        loading.remove();
        var newTweets = $(tweetsettings.template) 
                           .tmpl( response.attrs["statuses"] )
                           .appendTo("<div />");
                           
        newTweets.appendTo(tweetlist);
        newTweets.find(".autolink").autoLink();
 
        tweetsettings.next_page   = response.attrs["search_metadata"].next_results;
        tweetsettings.refresh_url = response.attrs["search_metadata"].refresh_url;
        hasresults = response.attrs["statuses"].length==0  ? false:true;
        settings.onafterload(settings, hasresults, newTweets);
     }
  }
  populateOldTweets = function(response, status, xhr){

    if($.param({q:settings.query}) == ("q="+response.attrs["search_metadata"].query)){
        loading.remove(); 
        var newTweets = $(tweetsettings.template) 
                           .tmpl( response.attrs["statuses"] )
                           .appendTo("<div />");
                           
        newTweets.appendTo(tweetlist);
        newTweets.find(".autolink").autoLink();
 
        tweetsettings.next_page   = response.attrs["search_metadata"].next_results;
        hasresults = response.attrs["statuses"].length==0  ? false:true;
        settings.onafterload(settings, hasresults, newTweets);
     }
  }
  
  refreshData = function(response){  
  
    if($.param({q:settings.query}) == ("q="+response.attrs["search_metadata"].query)){
      
        fresh_results = fresh_results.concat(response.attrs["statuses"]);
        tweetsettings.refresh_url = response.attrs["search_metadata"].refresh_url;
     
        if(response.attrs["statuses"].length){
          counter.html(fresh_results.length + " new tweets");
          new_result.show();
        }
    }
  }
  
  prependTweets = function(){
     new_result.hide();
     var newTweets = $(tweetsettings.template) 
                        .tmpl(fresh_results)
                        .appendTo("<div />");
     newTweets.prependTo(tweetlist);       
     newTweets.find(".autolink").autoLink();
     fresh_results = [];
  }
  
  getData = function( url, callback, data ){ 
    $.ajax({
      url: url,
      dataType: 'jsonp',
      data: data,
      success: callback
    });
  }
  
  new_search = function(){
     settings.onbeforeload(settings);
     tweetlist.empty();
     self.append(loading);
     fresh_results = [];
     new_result.hide();
     tweetsettings.next_page = null;
     tweetsettings.refresh_url = null;
     getData(settings.searchurl, populateTweets, { 'q': settings.query, 'rpp': settings.resultsperpage, 'handle' : settings.twitter_handle });
  }
 
  var methods = {
     init : function( options ) {

      if ( options ) $.extend( settings, options );

      self = $(this);
      self.data("tweetfeed", {
                  'template'     : settings.templateid,
                  'url'          : settings.searchurl
               });

      new_result.append(counter);
      
      tweetsettings = $(this).data("tweetfeed");

      self.append(new_result).append(tweetlist);
               
      new_search();
               
      setInterval(function(){ 
         if(tweetsettings.refresh_url){
            getData( settings.searchurl + tweetsettings.refresh_url, refreshData, {'handle' : settings.twitter_handle});
         }
      }, settings.refresh_timeout);
                 
      return $(this);
     },
     nextpage : function( ) { 
       if(tweetsettings.next_page){
         self.append(loading);
         getData( settings.searchurl + tweetsettings.next_page, populateOldTweets, {'handle' : settings.twitter_handle});
       }
     },
     search_query : function( query, handle ) { 
        settings.query = query;
        settings.twitter_handle = handle
        new_search();
     }     
  };

  $.fn.tweetfeed = function( method ) {
    
    if ( methods[method] ) {
      return methods[method].apply( this, Array.prototype.slice.call( arguments, 1 ));
    } else if ( typeof method === 'object' || ! method ) {
      return methods.init.apply( this, arguments );
    } else {
      $.error( 'Method ' +  method + ' does not exist on jQuery.tweetfeed' );
    }    
  
  };

})( jQuery );