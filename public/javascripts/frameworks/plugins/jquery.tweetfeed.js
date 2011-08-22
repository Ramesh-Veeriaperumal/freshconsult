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
                'baseurl'         : 'https://search.twitter.com/search.json',
                'query'           : '',
                'resultsperpage'  : 10,
                'refresh_timeout' : 30000,
                'templateid'      : '',
                onbeforeload      : function(){},
                onafterload       : function(){}
  };
  
  populateTweets = function(response, status, xhr){
     if($.param({q:settings.query}) == ("q="+response.query)){
        loading.remove(); 
        var newTweets = $(tweetsettings.template) 
                           .tmpl( response.results )
                           .appendTo("<div />");
                        
        newTweets.appendTo(tweetlist);       
        newTweets.find(".autolink").autoLink();
 
        tweetsettings.next_page   = response.next_page;
        tweetsettings.refresh_url = response.refresh_url;
        hasresults = (response.results.length == 0 && response.page == 1)?false:true;
        settings.onafterload(settings, hasresults);
     }
  }
  
  refreshData = function(response){  
     if($.param({q:settings.query}) == ("q="+response.query)){
        fresh_results = fresh_results.concat(response.results);
        tweetsettings.refresh_url = response.refresh_url;
     
        if(response.results.length){
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
  
  errorTweets = function(){ 
     settings.onafterload(settings, false);
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
     getData(settings.baseurl, populateTweets, { 'q': settings.query, 'rpp': settings.resultsperpage });
  }
 
  var methods = {
     init : function( options ) {

      if ( options ) $.extend( settings, options );

      self = $(this);
      self.data("tweetfeed", {
                  'template'     : settings.templateid,
                  'url'          : settings.baseurl
               });

      new_result.append(counter);
      
      tweetsettings = $(this).data("tweetfeed");

      self.append(new_result).append(tweetlist);
               
      new_search();
               
      setInterval(function(){ 
         if(tweetsettings.refresh_url){
            getData( settings.baseurl + tweetsettings.refresh_url, refreshData );
         }
      }, settings.refresh_timeout);
                 
      return $(this);
     },
     nextpage : function( ) { 
       if(tweetsettings.next_page){
         self.append(loading);
         getData( settings.baseurl + tweetsettings.next_page, populateTweets );
       }
     },
     search_query : function( query ) { 
        settings.query = query;
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