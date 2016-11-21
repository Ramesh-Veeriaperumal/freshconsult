window.App = window.App || {};

(function ($) {
  "use strict";

  App.AdminOnboarding = {
    onboardingMainModal : "#admin-onboarding-modal",
    channelToggleClass : ".channel-selector .item",


    initialize: function(){
      this.initMainModal();
      this.bindTriggers();
    },

    bindTriggers: function(){
      this.channelsToggleTrigger();
      this.frameNavigateTrigger();
      this.frameSpecificTriggers();
      this.inviteEmailsUpdateTrigger();
      this.inviteAgentTrigger();
      this.finishOnboardingTrigger();
      this.updateChannelsConfig();
    },
   
    emailValidate :function(emails){
      var $this = this;
      var emailArray = emails.split(",");
      var filter = /\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/;
      for(var e=0;e < emailArray.length;e++)
      {
        var email = $this.extractEmail(emailArray[e]);
        if(filter.test(email)){
          return true;
        }
        else{
          return false;
        }
      }
    },

    extractEmail: function(email){
      var email_match = email.match(/<(.+?)>/);
      if(email_match!=null){email = email_match[1];}
      return email;
    },

    initMainModal: function(){
      var $this = this;
      $($this.onboardingMainModal).modal({ backdrop: 'static', keyboard: false});
    },

    channelsToggleTrigger: function(){
      var $this = this;
      $($this.onboardingMainModal).on("click", $this.channelToggleClass , function(){
        if($(this).hasClass('default'))
        { 
          return false; 
        }
        $(this).toggleClass('active');
        $this.updateChannelsConfig();
      });
    },

    updateChannelsConfig: function(){
      var $this = this;
      var channelConfig = {};
      var channels = $($this.onboardingMainModal + " " + $this.channelToggleClass);
      channels.each(function(i,obj){
        channelConfig[$(obj).data('channel')] = $(obj).hasClass('active');
      });
      $this.hideAdminTabs(channelConfig);
      $($this.onboardingMainModal + " #account_channel_config").val(Browser.stringify(channelConfig));

    },

    finishOnboardingTrigger: function(){
      var $this  = this;
      var submitUrl = $($this.onboardingMainModal + " .channel-config-form").attr("action");
      $($this.onboardingMainModal).on("click", ".onboarding-modal--close" , function(){
        $this.updateChannelsConfig();
        $.post( submitUrl, $($this.onboardingMainModal + " .channel-config-form").serialize());
        $($this.onboardingMainModal).modal('toggle'); 
        $($this.onboardingMainModal).remove();
      });
    },

    frameNavigateTrigger: function(){
      var $this = this;
      $($this.onboardingMainModal).on("click", ".footer-action", function(){
        var target = $(this).data('target');
        if( target!= ''){
          $('.nav a[href="#' + target + '"]').tab('show');
        }
      });
    },

    frameSpecificTriggers: function(){
      var $this = this;
      $($this.onboardingMainModal).on( 'shown.bs.tab', 'a[data-toggle="tab"]', function (e) {
        if($(e.target).attr('href') == "#overview")
        {
          $('.nav a[href="#overview"]').tab('show');
          $('.nav.onboarding-frame-nav-container').empty();
        }
        if($(e.target).attr('href') == "#invite")
        {
          $("#agents_invite_email_input").select2('open');
        }
      });
    },

    hideAdminTabs: function(channel_config){
      var $this = this;
      Object.keys(channel_config).forEach(function(channel){
        if(channel_config[channel]===true)
          $(".header-tabs").find("[data-tab-name='"+channel+"']").show();
        else
          $(".header-tabs").find("[data-tab-name='"+channel+"']").hide();
      });
    },

    inviteEmailsUpdateTrigger: function(){
      var $this = this;
      var errorDiv = $($this.onboardingMainModal + ' .agent_email_count_status');

      $("#agents_invite_email_input").select2({
          tags: [],
          tokenSeparators: [",", " "],
          formatNoMatches: function () {
            return "  ";
          },
          selectOnBlur: true
      });
      

      $("#agents_invite_email_input").on("change", function(){
        if($("#agents_invite_email_input").val().split(",").length > 25){
          $($this.onboardingMainModal+ ' .invite-button').addClass('disabled');
          $($this.onboardingMainModal + ' .agent_invite_status').addClass('hide');
          errorDiv.removeClass('hide');
        }
        else if ( $("#agents_invite_email_input").val().length > 0){
          errorDiv.addClass('hide');
          $($this.onboardingMainModal+ ' .invite-button').removeClass('disabled');
          $($this.onboardingMainModal + ' .agent_invite_status').addClass('hide');
        }
        else{
          errorDiv.addClass('hide');
          $($this.onboardingMainModal + ' .agent_invite_status').addClass('hide');
          $($this.onboardingMainModal+ " .invite-button").addClass('disabled');
        }
      });
    },

    inviteAgentTrigger: function(){
      var $this = this;
      $($this.onboardingMainModal + " .invite-button").click( function(event) {
        var form = $($this.onboardingMainModal+ " form#agent_invite");
        var errorDiv = $($this.onboardingMainModal + ' .agent_invite_status');
        var invalidEmailsExist = false;   
        var agentEmails = "";

        $.each( $('.select2-choices .select2-search-choice'), function(index,obj){
          var agentEmail = $(obj).find('div').text();
          if(!$this.emailValidate(agentEmail)){
            $(obj).addClass("error_bubble");                           
            invalidEmailsExist = true;
          }
          agentEmails = (agentEmails) ? agentEmails+"," : "";
          agentEmails += agentEmail;
        });
    
        if(!invalidEmailsExist){  
          $('.nav a[href="#overview"]').tab('show');
          $.each ( $($this.onboardingMainModal+ " #agents_invite_email_input").val().split(","), function(index,obj){
            form.append("<input type='hidden' name='agents_invite_email[]' value='"+obj+"'/>")
          });
          $($this.onboardingMainModal+ " .invite-button").addClass('disabled');
          $($this.onboardingMainModal+ " #s2id_agents_invite_email").addClass('disabled');
        }
        else{
          errorDiv.removeClass('hide');        
          invalidEmailsExist = false;
          return false;
        }
      }); 
    }
  };
}(window.jQuery));

jQuery(document).ready(function(){
  App.AdminOnboarding.initialize();
});

