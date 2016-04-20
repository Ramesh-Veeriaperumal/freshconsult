(function() {
	var imInterval = setInterval(function(){
		if (typeof(inline_manual_player) != 'undefined' ){

			if (window.im_option.to_activate) {
				inline_manual_player.activateTopic(window.im_option.topic_id);

				jQuery.ajax({
		                        type: "POST",
		                        data: { "_method" : "put" },
		                        url: "/profiles/on_boarding_complete",
		                        success: function () {
		                        }
                  			});
			}
			clearInterval(imInterval);
		}
	},500)

	window.inlinemanual_callbacks = {
		imClickMimic: function(player_id, topic_id, step_id, custom_data) {
			document.querySelector(custom_data.element).click();
		}
	}
})()