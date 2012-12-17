(function($) {
	$(document).ready(function() {
		function checkLength(counter, textarea, limit) {
			limit = Number(limit);
			$('#' + counter).html(jQuery.trim($(textarea).val()).length);
			if (jQuery.trim($(textarea).val()).length > limit)
				jQuery('#' + counter).addClass('error');
			else
				jQuery('#' + counter).removeClass('error');
		}
		$('[rel=charcounter]').each(function(i,node) {
			$(node).bind("paste, cut", function() {
				setTimeout(function(){
					checkLength($(this).data('counter'), this, $(this).data('limit'))
				}, 10);
			});
			$(node).live("keyup", function() {
				checkLength($(this).data('counter'), this, $(this).data('limit'))
			});
			checkLength($(node).data('counter'), node, $(node).data('limit'))
		});
	});
})(jQuery)