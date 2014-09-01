(function ($) {
	custom_options = {
		loadRingColor: '#e9e9e9',// amount of sound which has loaded
		playRingColor: '#444', // amount of sound which has played
		backgroundRingColor: '#e9e9e9', // "default" color shown underneath everything else
		animDuration: 500,
		scaleArcWidth: 0.7,
		showHMSTime: true,
		animTransition: Animator.tx.bouncy, // http://www.berniecode.com/writing/animator.html
		playCallback: function (sm) {
			jQuery('.ui360.playing').removeClass('playing').find('a').show();
			jQuery(sm._360data.oUIBox).parent().addClass('playing').find('a').hide();
			var attached_file = jQuery(sm._360data.oUIBox).parents('.attached_file, .recorded-message').eq(0);
			if (attached_file.length !== 0) {
				attached_file.addClass('playing');
			}
		},
		finishCallback: function (sm) {
			jQuery(sm._360data.oUIBox).parent().removeClass('playing').find('a').show();
			var attached_file = jQuery(sm._360data.oUIBox).parents('.attached_file, .recorded-message').eq(0);
			if (attached_file.length !== 0) {
				attached_file.removeClass('playing');
			}
		},
		stopCallback: function (sm) {
			jQuery(sm._360data.oUIBox).parent().removeClass('playing').find('a').show();
			var attached_file = jQuery(sm._360data.oUIBox).parents('.attached_file, .recorded-message').eq(0);
			if (attached_file.length !== 0) {
				attached_file.removeClass('playing');
			}
		},
		fallbackFormat: jQuery.browser.mozilla || jQuery.browser.opera
	};

	if (threeSixtyPlayer && threeSixtyPlayer.config) {
		$.extend(threeSixtyPlayer.config, custom_options);
	}
}(jQuery));