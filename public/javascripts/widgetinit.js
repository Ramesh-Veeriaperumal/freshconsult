(function($){
	// Hack for IE-11 Browser Variable setting
  if (navigator.userAgent.match(/^(?=.*\bTrident\b)(?=.*\brv\b).*$/)){
    $.browser = { msie: true, version: "11" };
  }
})(jQuery);