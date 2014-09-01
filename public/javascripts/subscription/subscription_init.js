var $J = jQuery.noConflict();

(function($){
  $(document).ready(function() {
		$("input[rel=toggle]").livequery(function(){ $(this).itoggle(); });
	})
})(jQuery);