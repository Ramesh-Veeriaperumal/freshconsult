var FreshfoneSubscription, freshfoneSubscription;
(function ($) {
  "use strict";
  FreshfoneSubscription = function(){
    this.init();
  };

  FreshfoneSubscription.prototype = {
    init: function(){
      this.$dialPad = $('#freshfone_dialpad');
      this.$dialpadContainer = $('.ff-dial-pad');
      this.$contextContainer = $('.freshfone-context-container');
      this.$contactDetails = this.$dialpadContainer.find('.contact-details-msg');
      this.$trialToExpireWarning = this.$contactDetails.find('.trial_expiry_warning');
      this.$trialActivationTemplate = this.$dialPad.find('#freshfone-trial-activation');
      this.$trialActivateDiv = this.$dialPad.find('.ff-trial-activate');
      this.$trialWarningsContainer = this.$contextContainer.find('.trial_warnings');
      this.$incomingTrialWarning = this.$trialWarningsContainer.find('.trial_incoming_warning');
      this.$incomingTrialWarningSingular = this.$trialWarningsContainer.find('.trial_incoming_warning_one');
      this.$outgoingTrialWarning = this.$trialWarningsContainer.find('.trial_outgoing_warning');
      this.$outgoingTrialWarningSingular = this.$trialWarningsContainer.find('.trial_outgoing_warning_one');
      this.$trialExpiryWarning = this.$trialWarningsContainer.find('.trial_expiry_warning');
      this.$trialExpiryWarningSingular = this.$trialWarningsContainer.find('.trial_expiry_warning_one');
    },
    showDialpadWarnings: function(){
      var self = this;
      if(freshfone.trialExpired){
        return self.showTrialExpired();
      }
      else if (freshfone.trialOutgoingExhausted) {
        return self.showTrialExhausted();
      }
    },
    showTrialExpired: function(){
      var self = this;
      if(self.$trialActivateDiv.length)
        self.$trialActivateDiv.remove();
      return self.populateTrialActivate('trial_expired', self.activationRequested);
    },
    showTrialExhausted:function(){
      var self = this;
      if(self.$trialActivateDiv.length)
        self.$trialActivateDiv.remove();
      return self.populateTrialActivate('outbound_usage_exceeded',
          self.activationRequested);
    },
    populateTrialActivate:function(reason, isRequested){
      var self = this; var trialTemplate;
      self.$dialPad.children().hide();
      trialTemplate = self.$trialActivationTemplate.clone();
      self.$dialPad.prepend(trialTemplate.tmpl(
        {reason: reason, requested: freshfone.activationRequested}));
      return true;
    },
    loadWarningsTimer:function(){
      if(freshfone.isTrial)
        setTimeout(freshfoneSubscription.loadTrialWarnings, 5000); // 5 second delay for in_call race condition
    },
    loadTrialWarnings: function(){
      var self = this;
      $.ajax({
        url: '/freshfone/call/trial_warnings',
        type: 'GET',
        dataType: "json",
        data: { CallSid: freshfonecalls.tConn.parameters.CallSid},
      })
      .done(function(result) {
        if(result)
          freshfoneSubscription.showTrialWarnings(result);
      });
    },
    setOutgoingWarning: function(data){
      var self = this;
      if(typeof data.trial_outbound_left !== "undefined"){
        if(data.trial_outbound_left == 1)
          self.forSingularWarnings(self.$outgoingTrialWarningSingular, '.min_left');
        else
          self.forOtherWarnings(self.$outgoingTrialWarning, '.min_left',
            data.trial_outbound_left);
        return true;
      }
    },
    setIncomingWarning: function(data){
      var self = this;
      if(typeof data.trial_inbound_left !== "undefined"){
        if(data.trial_inbound_left == 1)
          self.forSingularWarnings(self.$incomingTrialWarningSingular,
            '.min_left');
        else
          self.forOtherWarnings(self.$incomingTrialWarning,
            '.min_left', data.trial_inbound_left);
        return true;
      }
    },
    setTrialExpiryWarning: function(data){
      var self = this;
      if(typeof data.trial_period_left !== "undefined"){
        if(data.trial_period_left == 1)
          self.forSingularWarnings(self.$trialExpiryWarningSingular, '.days_left');
        else
          self.forOtherWarnings(self.$trialExpiryWarning, '.days_left',
            data.trial_period_left);
        return true;
      }
    },
    forSingularWarnings: function(ele, min_or_day_class){
      $(ele).toggle(true).children().toggle(true);
      $(ele).find(min_or_day_class).toggle(true);
    },
    forOtherWarnings: function(ele, min_or_day_class, value){
      $(ele).toggle(true).children().toggle(true);
      $(ele).find(min_or_day_class).toggle(true).html(value);
    },
    showTrialWarnings: function(data){
      var self = this;
      if(!data || $.isEmptyObject(data))
        return;
      var warningShown = false;
      warningShown = self.setIncomingWarning(data) ||
        self.setOutgoingWarning(data) || self.setTrialExpiryWarning(data);
      if(warningShown){
        self.$trialWarningsContainer.toggle(true);
      }
    },
    hideTrialWarnings: function(){
      var self = this;
      self.$trialWarningsContainer.children().toggle(false);
      self.$trialWarningsContainer.toggle(false);
    }
  };

  $(document).ready(function(){
    freshfoneSubscription = new FreshfoneSubscription();
  });
})(jQuery);
  