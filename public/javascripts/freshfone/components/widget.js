var FreshfoneWidget;
(function ($) {
    "use strict";
	FreshfoneWidget = function () {
		this.isWidgetUninitialized = true;
		this.widget = $('.freshfone_widget');
		this.$sidebarTabsContainer = $('.grey_widget_background');
	};

	FreshfoneWidget.prototype = {
		initializeWidgets: function () {
			this.$contentContainer = $('.freshfone_content_container');
			this.outgoingCallWidget = this.widget.find('.outgoing');
			this.ongoingCallWidget = this.widget.find('.ongoing');
			this.endCallNote = $('#end_call_notes');
			this.endCallForm = $('#end_call');
			this.$endCallMainContent = this.endCallForm.find('.main_content');
			this.$endCallNewTicketDetailsForm = this.endCallForm.find('.new_ticket_details_form');
			this.$ticketSearchPane = this.endCallForm.find('.ticket_search_pane');
			this.$requesterNameContainer = this.endCallForm.find('.requester_name_container');
			this.callNote = $('#call_notes');
			this.$number = $('#number');
			this.$dialpadButton = this.outgoingCallWidget.find(".showDialpad");
			this.freshfone_dashboard = $('.freshfone_dashboard');
			this.$freshfone_realtime = this.freshfone_dashboard.find('.freshfone_realtime');
			this.$freshfone_alert = this.freshfone_dashboard.find('.freshfone_alert');
			this.isWidgetUninitialized = false;
			this.isPageCloseBinded = false;
			this.noteType = false;
			this.force_disable_widget = false;
		},
		loadDependencies: function (freshfonecalls, freshfoneuser) {
			this.freshfoneuser = freshfoneuser;
			this.freshfonecalls = freshfonecalls;
		},
		handleWidgets: function (type) {
			if (this.isWidgetUninitialized) { this.initializeWidgets(); }
			if (this.isPageCloseBinded) { this.undbindPageClose(); }
			this.widget.popupbox('hidePopupContents');
			if (type === "incoming") {
				this.showIncoming();
			} else if (type === "ongoing") {
				this.showOngoing();
			} else {
				this.showOutgoing();
			}
			this.toggleSidebarTabsContainer(type === "ongoing");
		},
		incoming: function () {
			this.handleWidgets('incoming');
		},
		ongoing: function () {
			this.handleWidgets('ongoing');
		},
		outgoing: function () {
			this.handleWidgets();
		},
		showOngoing: function () {
			this.hideAllWidgets();
			this.ongoingCallWidget.show();
			this.bindPageClose();
		},
		showOutgoing: function () {
			this.hideAllWidgets();
			this.outgoingCallWidget.show();
		},
		disableFreshfoneWidget: function () {
			if (freshfonewidget.ongoingCallWidget.is(':visible')){
				this.force_disable_widget = true;
			}else{
				this.outgoingCallWidget.addClass("disabled");
				this.widget
							.addClass('tooltip inactive')
							.attr('title', freshfone.widget_inactive)
							.data('offset', 10)
							.popupbox('hidePopupContents');
				this.displayAlert();
			}
		},
		enableFreshfoneWidget: function () {
			this.force_disable_widget = false;
			this.outgoingCallWidget.removeClass("disabled");
			this.widget
						.removeClass('tooltip inactive')
						.removeAttr('title')
						.removeData('offset');
			this.hideAlert();
		},
		displayAlert: function () {
			this.$freshfone_alert.removeClass('hide');
			this.$freshfone_realtime.addClass('hide');
		},
		hideAlert: function () {
			this.$freshfone_alert.addClass('hide');
			this.$freshfone_realtime.removeClass('hide');
		},
		hideAllWidgets: function () {
			if (this.isWidgetUninitialized) { this.initializeWidgets(); }
			this.outgoingCallWidget.hide();
			this.ongoingCallWidget.hide();
		},
		bindPageClose: function () {
			var self = this;
			$(window).bind("beforeunload", function () {
				if (!self.freshfonecalls.callError()) {
					return "You have a CALL in progress. Navigating away from this page will end the call.";
				}
			});
      $(window).on("unload", function () {
        self.freshfonecalls.hangup();
        self.freshfoneuser.resetStatusAfterCall();
        self.freshfoneuser.updatePresence(false);
      });
			this.isPageCloseBinded = true;
		},
		undbindPageClose: function () {
			$(window).unbind("beforeunload");
			this.isPageCloseBinded = false;
		},
		resetForm: function () {
			this.callNote.val('');
		},
		resetToDefaultState: function () {
			freshfonewidget.handleWidgets('outgoing');
			if (this.force_disable_widget) {
				this.disableFreshfoneWidget();
			};
			this.resetForm();
		},
		hideTransfer: function () {
			$('#transfer_call .transfering_call').hide();
		},
		resetPreviewMode: function () {
			this.previewMode(true);
		},
		resetPreviewButton: function () {
			var $ivrPreview = $('#ivr_preview');
			if ($ivrPreview) {
				$ivrPreview.button('reset');
				$('#ivr_submit').button('reset');
			}
		},
		enablePreviewMode: function () {
			this.previewMode(false);
		},
		previewMode: function (show) {
			this.ongoingCallWidget.find('.transfer_call').parent().toggle(show);
			this.ongoingCallWidget.find('.add_notes').parent().toggle(show);
		},
		showDialPad: function () {
			this.$number.val(freshfonecalls.number);
			if (this.outgoingCallWidget.is(":visible")) {
				this.$dialpadButton.popupbox('show');
			}
		},
		toggleSidebarTabsContainer: function (show) {
			this.$sidebarTabsContainer.toggle(this.$sidebarTabsContainer.data('chat') || show);
			this.$sidebarTabsContainer.data('freshfone', show);
		}
	};
	
	$(window).on("load", function () {
      	var callerIdNumber = localStorage.getItem("callerIdNumber");
      	this.freshfonecalls.selectFreshfoneNumber(callerIdNumber);
      });
}(jQuery));