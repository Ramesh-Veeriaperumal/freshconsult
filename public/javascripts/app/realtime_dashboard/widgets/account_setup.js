RealtimeDashboard.Widgets = RealtimeDashboard.Widgets || {};


(function ($) {
	"use strict";
	RealtimeDashboard.Widgets.AccountSetup = {
		setupDetailsWasActive: false,
		init: function() {
			this.feedback = {
				form: $('#setup-widget-feedback'),
				type: "normalFeedback",
				accountInfo: '<p><b>Account Id:</b> <%= accountId %></p>' +
							'<p><b>Account URL:</b> <%= accountUrl %></p>' +
							'<p><b>Admin:</b> <%= isAdmin %></p>',
				subject: $("#setup-widget-feedback #helpdesk_ticket_subject"),
				fauxDescriptionElement: $("#setup-widget-feedback #helpdesk_ticket_body_faux"),
				descriptionElement: $("#setup-widget-feedback #helpdesk_ticket_ticket_body_attributes_description_html"),
				submitElement: $("#setup-widget-feedback #submit-feedback")
			};
			this.bindEvents();
			this.invokeFeedbackFormValidator();
			if(this.setupDetailsWasActive){this.showSetupDetails();}
			$('#sales-manager-info').trigger('afterShow');
		},
		bindEvents: function() {
			var $this = this;
      var $body = $('body');
      var $doc = $(document);
      $doc.on("ajaxStop.setupWidget", function(){ $this.setupProgressBar(); });
			$body.on('click.setupWidget', '#write-to-us:not(".disabled")', function(e) {
				$this.feedback.type = "normalFeedback";
				$this.toggleWriteToUsForm(true);
			});
			$body.on('keyup.setupWidget', "#setup-widget-feedback #helpdesk_ticket_body_faux", function(e) { 
				$("#submit-feedback").removeClass("disabled"); 
				$body.off('keyup.setupWidget', "#setup-widget-feedback #helpdesk_ticket_body_faux");
			})
			$body.on('click.setupWidget', '#cancel-feedback', function(e) {$this.toggleWriteToUsForm(false)});
			$body.on('click.setupWidget', '#request-demo:not(".disabled")', function(e) {$this.requestDemo($(this))});
			$body.on('click.setupWidget', '#helpdesk_setup', function(e) {$this.showSetupDetails()});
			$body.on('click.setupWidget', '#setup-request-trial-extension:not(".disabled")', function(e) { $this.requestTrialExtension($(this))});
			$doc.on('keyup.setupWidget', function(e) { if (e.keyCode == 27) { $this.closeSetupDetails();}});
			$('body').on('click.setupWidget', function(e) {
				var setupLinkId = "helpdesk_setup";
				var eventTarget = $(e.target);
				if(eventTarget.attr('id') != setupLinkId && eventTarget.parent().attr('id') != setupLinkId &&
					(eventTarget.parents(".setup-details-wrapper").length == 0) && eventTarget.closest('a').length == 0){
					$this.closeSetupDetails();
				}
			});
			$(document).on('mousemove.setupWidget', '.setup-details-wrapper', function(event) {
				event.preventDefault();
				$('body').addClass('preventscroll');
			});
			jQuery(document).on('mouseleave.setupWidget', '.setup-details-wrapper', function(event) {
				event.preventDefault();
				$('body').removeClass('preventscroll');
			});
			$body.on('mouseenter.setupWidget', ".setup-info:not('.complete')", function(e) { $this.highlightSetupInfo($(this),true)});
			$body.on('mouseleave.setupWidget', ".setup-info:not('.complete')", function(e) { $this.highlightSetupInfo($(this),false)});
		},
		toggleWriteToUsForm: function(toggleState, writeToUsToggle) {
      var $writeToUs = $("#write-to-us");
      $writeToUs.toggleClass('disabled', (writeToUsToggle || toggleState));
			$writeToUs.parents(".setup-cols").children().toggleClass('expanded', toggleState);
			$("#setup-widget-feedback").toggle(toggleState);
			$("#request-demo:not('.complete')").toggleClass("disabled", toggleState);
			var feedbackTextArea = $("#setup-widget-feedback #helpdesk_ticket_body_faux");
			var submitFeedbackToggleState = (feedbackTextArea.is(":visible") && feedbackTextArea.val().length == 0)
			$("#submit-feedback").toggleClass("disabled", submitFeedbackToggleState);
		},
		showSetupDetails: function(){
			var $setupDetails = $('.setup-details-wrapper');
			$setupDetails.toggleClass('active');
			if($setupDetails.hasClass("active")){
				$('.dashboard-details-wrapper').removeClass("active");
			}
		},
		closeSetupDetails: function(){
			$('.setup-details-wrapper').removeClass("active");
		},
		invokeFeedbackFormValidator: function(){
			var $this = this;
			var feedbackUtils = $this.feedback;
			$("#setup-widget-feedback").validate(
				{
				 debug: false,
				 rules: {
						"helpdesk_ticket[ticket_body_attributes][description_html_faux]" : { required: true }
				 },
				 messages: {
					"helpdesk_ticket[ticket_body_attributes][description_html_faux]": {
						required: window.feedback_subject_required_error
					 }
				},
				submitHandler: function(form, btn) {
					var feedbackType = feedbackUtils.type;
					var accountInfo = _.template(feedbackUtils.accountInfo,
								{ 	accountId: window.current_account_id,
									accountUrl: window.current_account_full_domain,
									  isAdmin: window.is_current_user_admin});
					$this[feedbackType+"BeforeSubmit"]();
					feedbackUtils.descriptionElement.val($this[feedbackType+"Description"]() + accountInfo);
					feedbackUtils.form.ajaxSubmit({
						crossDomain: true,
						dataType: 'jsonp',
						success: function(response, status){
							$this[feedbackType+"SuccessHandler"](response, status);
						},
						error:function(err){
							$this[feedbackType+"ErrorHandler"](err);
						}
					});
				}
			});
		},
		normalFeedbackBeforeSubmit: function(){
			this.feedback.submitElement.button("loading");
			this.feedback.fauxDescriptionElement.attr("disabled", true);
			var feedbackSubject = this.feedback.subject;
			feedbackSubject.val(feedbackSubject.val().sub("Demo request", "Message"));
		},
		normalFeedbackSuccessHandler: function(response, status){
			var $this =this;
			$this.feedback.submitElement.button("reset");
			if(response.success === true){
				$this.feedback.form.fadeOut(500, function(){
					$('#setup-widget-feedback-thanks').fadeIn(500, function(){
						setTimeout(function(){
							$(this).fadeOut(500,$this.toggleWriteToUsForm(false, true));
						}, 2000);
					});
					$this.feedback.fauxDescriptionElement.attr("disabled", false);
				});
			}else {
				//show error?
			}
		},
		normalFeedbackErrorHandler: function(err){
			this.feedback.submitElement.button("reset");
			this.feedback.fauxDescriptionElement.attr("disabled", false);
		},
		normalFeedbackDescription: function(){
			return '<div>' + this.feedback.fauxDescriptionElement.val() +'</div><br/><br/>'
		},
		requestDemo: function(elem){
			elem.button('loading');
			elem.addClass("sloading loading-small loading-box");
			this.feedback.type = "demoRequest";
			this.feedback.form.submit();
		},
		demoRequestBeforeSubmit: function(){
			var feedbackSubject = this.feedback.subject;
			feedbackSubject.val(feedbackSubject.val().sub("Message", "Demo request"));
		},
		demoRequestSuccessHandler: function(){
			var requestDemoLink = $('#request-demo');
      requestDemoLink.removeClass("sloading loading-small loading-box");
			requestDemoLink.button("complete").addClass("complete");
      this.disableWithTimeout(requestDemoLink);
		},
		demoRequestErrorHandler: function(){
			$('#request-demo').button("reset");
		},
		demoRequestDescription:function() { return "" },
		setupProgressBar: function(){
			var progressBar = $('.progress-bar');
			progressBar.attr("style", "width:" + progressBar.attr("aria-valuenow") + "%");
			progressBar.show("slide", { direction: "left" }, 400);
			$(document).off("ajaxStop.setupWidget");			  
		},
		requestTrialExtension: function(elem){
      var _this = this;
			elem.button('loading');
			elem.addClass("sloading loading-small loading-box");
			$.ajax({
				method: "POST",
				url: '/subscription/request_trial_extension',
				success:function(data){
					elem.button('complete');
            _this.disableWithTimeout(elem);
				}
			});
		},
    disableWithTimeout: function(elem) {
        setTimeout(function() {
            elem.addClass("disabled");
        },5);
    },
    highlightSetupInfo: function(elem,toggle) {
    	elem.toggleClass("highlight", toggle);
    	elem.parents('.setup-info-wrapper').find('.setup-icon-wrap').toggleClass("complete", toggle);
    	elem.parents('.setup-info-wrapper').find('.setup-icon').toggleClass("highlight", toggle);
    },
		destroy: function(){
			if($('.setup-details-wrapper').hasClass("active")){
				this.setupDetailsWasActive = true;
			}
			$('body').off('.setupWidget');
			$(document).off('.setupWidget');
		}
	};
}(window.jQuery));
