var Freshapp = Freshapp || {};

(function(fa){
  
  init:(function(){
    funqueue = [];
    jQuery(document).on("dom_helper_loaded", function() {
      if(funqueue.length > 0) {
        while((code = funqueue.shift())!= undefined){
          code.call();
        }
      }
    });
  })();

  fa.run = function(callback){
    funqueue.push(callback);
  }
})(Freshapp);
