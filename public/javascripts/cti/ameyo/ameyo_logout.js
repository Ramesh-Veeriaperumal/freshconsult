(function ($) {
	"use strict";
	$(document).ready(function () {
		$('body').on('click', 'a[href="/logout"]', function (ev) {
			doLogout();
		});
		
	});
}(jQuery));