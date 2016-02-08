var FreshfoneTimer;
(function ($) {
	"use strict";
	FreshfoneTimer = function () {
		this.className = "FreshfoneTimer";
		this.stopTimer = false;
		this.timerElement = $("#call_timings");
	};

	FreshfoneTimer.prototype = {
		setCallTimer: function () {
			var seconds = parseInt($(this.timerElement).data('runningTime') || 0, 10) + 1;
			$(this.timerElement).html(seconds.toTime()).data('runningTime', seconds);
		},
		startCallTimer: function (timerEle) {
			this.timerElement = timerEle ? timerEle : $("#call_timings");
			this.stopTimer = false;
			this.resetCallTimer(this.timerElement);
			var self = this;
			new PeriodicalExecuter(function (pe) {
				self.setCallTimer();
				if (self.stopTimer) { pe.stop(); }
			}, 1);
		},
		stopCallTimer: function () {
			this.stopTimer = true;
		},
		resetCallTimer: function () {
			$(this.timerElement).data('runningTime', -1);
			this.setCallTimer();
		}
	};
}(jQuery));