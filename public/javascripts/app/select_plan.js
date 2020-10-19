/*jslint browser: true, devel: true */
/*global  App, FreshWidget, escapeHtml */

window.App = window.App || {};

(function ($) {
  "use strict";

  App.SelectPlan = {
    calculate_request : null,
    clone_button : null,
    selected_plan : null,
    agents : null,
    field_agents_count: null,
    current_plan_id : null,
    currency : null,
    original_data : null,
    current_active_plan_flag : false,
    billing_cycle : null,
    initial_billing_cycle : null,
    subscribed_plan_id : null,
    current_agent_limit: null,
    omni_disabled: null,
    request_change: false,
    agent_reduced: false,
    agent_changed: false,
    field_agent_reduced: false,
    field_agent_changed: false,
    billing_cycle_downgraded: false,
    billing_cycle_changed: false,
    downgrade_launched: false,
    fsm_disabled: false,
    current_plan_name: null,
    fsm_active: false,
    subscription_state: null,
    selected_plan_id: null,
    editBilling: false,
    free_agent_count: null,
    addons: {},
    fsm_addon_key: 'field_service_management',
    subscription_cancel: 'subscription-cancellation',
    suspended_key: 'suspended',
    freddy_addon_count: 0,
    freddy_active: false,
    freddy_disabled: false,
    freddy_option: '',
    freddy_self_service_addon_key: 'freddy_self_service',
    freddy_ultimate_addon_key: 'freddy_ultimate',
    freddy_sessions_addon_key: 'freddy_session_packs',
    freddy_session_pack_reduced: false,
    freddy_session_pack_changed: false,
    freddy_sessions: 0,
    freddy_auto_recharge_launched: false,
    freddy_auto_recharge_enabled: false,
    freddy_auto_recharge_enabled_changed: false,
    freddy_auto_recharge_packs: 1,
    freddy_auto_recharge_packs_changed: 1,
    initialize: function (planInfo) {
      this.currency = ''+planInfo.currency_name;
      this.billing_cycle = planInfo.renewal_period;
      this.initial_billing_cycle = planInfo.renewal_period;
      this.subscribed_plan_id = planInfo.subscribed_plan_id;
      this.current_agent_limit = parseInt(planInfo.agent_limit);
      this.freddy_session_pack = parseInt(planInfo.freddy_session_pack);
      this.downgrade_launched = planInfo.downgrade_policy_launched;
      this.field_agents_count = parseInt(planInfo.fsm_agent_limit);
      this.current_plan_name = planInfo.subscribed_plan_name;
      this.fsm_active = planInfo.fsm_enabled;
      this.fsm_disabled = !(planInfo.fsm_enabled);
      this.initial_fsm_state = !(planInfo.fsm_enabled);
      this.freddy_addon_count = planInfo.freddy_addon_count;
      this.freddy_active = planInfo.freddy_enabled;
      this.initial_freddy_state = !planInfo.freddy_enabled;
      this.freddy_disabled = !planInfo.freddy_enabled;
      this.initial_freddy_option = planInfo.freddy_option;
      this.freddy_option = planInfo.freddy_option;
      this.freddy_sessions = planInfo.freddy_sessions || 0;
      this.freddy_auto_recharge_launched = planInfo.freddy_auto_recharge_launched;
      this.freddy_auto_recharge_enabled = planInfo.freddy_auto_recharge_enabled;
      this.freddy_auto_recharge_enabled_changed = planInfo.freddy_auto_recharge_enabled;
      this.freddy_auto_recharge_packs = planInfo.freddy_auto_recharge_packs || 1;
      this.freddy_auto_recharge_packs_changed = planInfo.freddy_auto_recharge_packs || 1;
      this.subscription_state = planInfo.subscription_state;
      this.pending_cancellation_request = planInfo.has_account_cancellation_request;
      this.free_agent_count = parseInt(planInfo.free_agents_count);
      this.is_omni_plan = planInfo.is_omni_plan;
      if(this.downgrade_launched && this.pending_cancellation_request && this.subscription_state !== this.suspended_key) {
        $('.downgrade-plan-button, .free-plan-button').removeAttr('rel');
      }
      this.bindEvents();
      this.initializeAutoRechargeTooltip();
    },
    namespace: function(){
      return '.selectplans';
    },
    bindEvents: function(){
      var $this = this
      $(document).on('click'+$this.namespace(),  '.billing-cancel', function(ev){ $this.billingCancel(ev); })
      $(document).on('click'+$this.namespace(),  '.edit-plan', function(ev){ $this.editingSubscription(ev); })
      $(document).on('click'+$this.namespace(),  '.plan-button, .plan-button1, .downgrade-plan-button, .free-plan-button', function(ev){ $this.checkCancellationPending(ev) })
      $(document).on('click'+$this.namespace(),  '.plan-button, .plan-button1', function(ev){ $this.bindPlanChange(ev, this) })
      $(document).on('click'+$this.namespace(),  '.suspended-plan-button', function(ev){ $this.bindSuspendedPlanChange(ev,this) })
      $(document).on('click'+$this.namespace(),  '.downgrade-plan-button', function(){ $this.cloneButton(this) })
      $(document).on('click'+$this.namespace(),  '.downgrade-modal .btn-primary', function(){ $this.closeModal() })
      $(document).on('change'+$this.namespace(), '#agents-text-box', function(ev){ $this.agentChange(ev, this) })
      $(document).on('change'+$this.namespace(), '#billing_cycle', function(){ $this.billingCycleChange(this) })
      $(document).on('click'+$this.namespace(), '#switch-to-annual-link', function(){ $this.switchToAnnual(this)} )
      $(document).on('click'+$this.namespace(),  '.trial-plan-change', function(){ $this.trialPlanChange(this) })
      $(document).on('click'+$this.namespace(),  '.omni-toggle-holder .toggle-button', function(){ $this.toggleOmniPlans(this) })
      $(document).on('click'+$this.namespace(),  '.omni-billing-edit .toggle-button', function(){ $this.toggleOmniPlans(this) })
      $(document).on('click'+$this.namespace(),  '#omni-disable-confirmation-submit', function(){ $this.submitPlanUpdate(this) })
      $(document).on('click'+$this.namespace(),  '.fsm-toggle-holder .toggle-button', function(ev, triggerType){ $this.toggleFSMAddon(this, false, triggerType) })
      $(document).on('click'+$this.namespace(),  '.fsm-billing-edit .toggle-button', function(ev, triggerType){ $this.toggleFSMAddon(this, true, triggerType) })
      $(document).on('change'+$this.namespace(), '#field-agents-text-box', function(){ $this.fieldAgentChange(this) })
      $(document).on('click'+$this.namespace(),  '#buy-more-sesion, .enable-auto-recharge-here', function(){ $('.edit-plan').trigger("click") })
      $(document).on('click'+$this.namespace(),  '.freddy-billing-edit .toggle-button', function(ev, triggerType){ $this.toggleFreddyAddon(this, true, triggerType, false) })
      $(document).on('click'+$this.namespace(),  '.freddy-cx-self-billing-edit .toggle-button', function(ev, triggerType){ $this.toggleFreddyAddon(this, true, triggerType, true) })
      $(document).on('click'+$this.namespace(),  'input[name="freddy_options"]', function(){ $this.toggleFreddyCXPlanOptions(this) })
      $(document).on('change'+$this.namespace(), '#freddy-session-pack', function(){ $this.freddySessionPackChange(this) })
      $(document).on('click'+$this.namespace(),  '#warning-freddy-billing-edit-submit', function(){ $this.checkAndRemoveFreddyCX('submit') })
      $(document).on('click'+$this.namespace(),  '#warning-freddy-billing-edit-cancel, #warning-freddy-billing-edit .modal-header .close', function(){ $this.checkAndRemoveFreddyCX('cancel', true) })
      $(document).on('click'+$this.namespace(),  '#freddy_auto_recharge_enabled_field', function(){ $this.toggleFreddyAutorecharge(this) })
      $(document).on('change'+$this.namespace(), '#freddy_auto_recharge_packs_field', function(){ $this.freddyAutoRechargePacksChange(this) })
      $(document).on('click'+$this.namespace(),  '#warning-fsm-billing-change-submit', function(){ $this.checkAndRemoveFSM('submit') })
      $(document).on('click'+$this.namespace(),  '#warning-fsm-billing-change-cancel', function(){ $this.checkAndRemoveFSM('cancel', false) })
      $(document).on('click'+$this.namespace(),  '#warning-fsm-billing-change .modal-header .close', function(){ $this.checkAndRemoveFSM('cancel', false) })
      $(document).on('click'+$this.namespace(),  '#warning-fsm-billing-edit-submit', function(){ $this.checkAndRemoveFSM('submit') })
      $(document).on('click'+$this.namespace(),  '#warning-fsm-billing-edit-cancel', function(){ $this.checkAndRemoveFSM('cancel', true) })
      $(document).on('click'+$this.namespace(),  '#warning-fsm-billing-edit .modal-header .close', function(){ $this.checkAndRemoveFSM('cancel', true) })
      $(document).on('click'+$this.namespace(),  '.second-downgrade-modal-wrapper .btn-primary', function(e){ $this.secondTimeDowngrade(e) })
      $(document).on('click'+$this.namespace(),  '.second-downgrade-modal', function(e){ $this.secondTimeDowngradeModal(e) })
      $(document).on('click','.sprout-second-downgrade-modal', function(e){ $this.sproutDowngradeModal(e) })
      $(document).on('click','#sprout-downgrade-submit', function(e){ $this.sproutDowngradeCompareModal(e) })
      $(document).on('click','#downgrade-sprout-btn', function(e){ $this.sproutDowngradeFormSubmit(e) })
      $(document).on('click'+$this.namespace(),  '.cancel-request', function(ev){ $this.performCancelRequest(ev, this) })
      $(document).on('click', '#try-freshsales', function(ev){ $this.tryFreshsalesEvent($(this).data('attr'))})
    },
    editingSubscription: function() {
      this.editBilling = true;
      $('#buy-more-sesion').get(0) ? $('#buy-more-sesion').hide() : '';
      $('.auto-recharge-section').get(0) ? $('.auto-recharge-section').hide() : '';
      $('.auto-recharge-tooltip').popover('hide');
    },
    tryFreshsalesEvent: function(isInvite) {
      var openOmnibarEvent = new CustomEvent('showPromotionForProduct', {
        detail: {
          productName: 'freshsales',
          invite: isInvite
        }
      });
      this.triggerOmnibarEvent(openOmnibarEvent);
    },
    triggerOmnibarEvent: function(event) {
      var eventTarget = window.parent.document.querySelector('[data-omnibar-event-target]');
      eventTarget.dispatchEvent(event);
    },
    performCancelRequest: function(ev, tag) {
      $('#cancellation-wrapper').addClass('sloading inner-form-hide');
      $('#pending-cancellation-request-modal').modal("hide");
      ev.preventDefault();
      var self = this;
      var cancel_type = $('#cancellation-button').attr('data-cancel-type');
      $('#cancellation-button').addClass('disabled');
      $.ajax({
            url: "/subscription/cancel_request",
            type: "DELETE",
            async :true,
            success: function(status){
              self.handleCancellationSuccess(cancel_type);
            },
            error: function(data){
              self.handleCancellationFailure(cancel_type);
            }
        });
    },
    handleCancellationSuccess: function(cancel_type) {
      this.pending_cancellation_request = false;
      var message = cancel_type === this.subscription_cancel ? 'downgrade_policy.subscription_cancel_request_success' : 'downgrade_policy.request_cancel_success'
      $('#cancellation-wrapper').removeClass('sloading inner-form-hide');
      $('#annual-savings-wrapper').removeClass('hide');
      $('.request-change-wrapper').addClass('hide');
      $('.request-change-info').addClass('hide');
      $('.request-change-status').addClass('success').removeClass('hide');
      $('#request-change-message').text(I18n.t(message));
      $('.downgrade-plan-button, .free-plan-button').attr('rel', 'freshdialog');
      setTimeout(function() {
        $('.request-change-status').addClass('hide');
      }, 5000);
    },
    handleCancellationFailure: function(cancel_type) {
      var message = cancel_type === this.subscription_cancel ? 'downgrade_policy.subscription_cancel_request_failure' : 'downgrade_policy.cancel_request_failure'
      $('#cancellation-button').removeClass('disabled');
      $('#cancellation-wrapper').removeClass('sloading inner-form-hide');
      $('.request-change-status').addClass('failure').removeClass('hide');
      $('#request-change-message').text(I18n.t(message));
      setTimeout(function() {
        $('.request-change-status').addClass('hide');
      }, 5000);
    },
    checkCancellationPending: function(ev) {
      if(this.downgrade_launched && this.pending_cancellation_request && this.subscription_state !== this.suspended_key) {
        $('#pending-cancellation-request-modal').appendTo("body").modal('show');
        ev.stopImmediatePropagation();
      }
    },
    sproutDowngradeModal: function(e){
      $($(e.currentTarget).attr('data-id')).appendTo('body').modal('show');
    },
    secondTimeDowngrade: function(e){
      $('.'+e.currentTarget.id).find('#commit').attr('type','submit');
      $('.second-downgrade-modal').css('display','none')
      $('.'+e.currentTarget.id).find('#commit').trigger('click')
    },
    sproutDowngradeCompareModal: function(e) {
      $('#sprout-downgrade-modal-show').find('.downgrade-non-sprout').css('display','none');
      $('#sprout-downgrade-modal-show').find('.downgrade-sprout').css('display','block');
      $(".latest-request #current-date").html(moment(new Date()).format('D MMM, YYYY'));
      $("#sprout-downgrade-modal-show").appendTo('body').modal('show');
    },
    secondTimeDowngradeModal: function(e){
      e.preventDefault();
      $(".latest-request #current-date").html(moment(new Date()).format('D MMM, YYYY'));
      $($(e.currentTarget).attr('data-id')).modal('show');
      $('body').find('.modal-backdrop').addClass('downgrade-backdrop')
    },
    sproutDowngradeFormSubmit: function(){
      $('.sprout-form-submit').find('form').submit();
    },
    billingCancel: function (ev) {
      ev.preventDefault();
      $("#billing-template").detach().appendTo('#Pagearea').hide();
      $(".features-billing-edit").addClass('hide');
      $('#buy-more-sesion, .auto-recharge-section').show();
      $('.auto-recharge-tooltip').popover('hide');
      this.initializeAutoRechargeTooltip();
      var data_content = this.original_data;
      $(".subscribed-plan-details").html(data_content);
    },
    bindPlanChange: function (ev, button) {
      if($(button).data('billing-cycle')) {
        this.billing_cycle = $(button).data('billing-cycle')
      }
      ev.stopPropagation();
      this.choosePlan(ev.currentTarget);
    },
    bindSuspendedPlanChange: function (ev, button) {
      $('.pricelist.active .suspended-plan-button').show();
      $('.pricelist.active').removeClass('active');
      $(button).hide();
      ev.stopPropagation();
      this.choosePlan(ev.currentTarget);
    },
    cloneButton: function (button) {
      this.clone_button = button;
      if($('.trial-plan-change').length > 0){
        $('#billing-template').hide();
        $('.trial-plan-change').show()
      }
    },
    closeModal: function () {
      $('.downgrade-modal').modal('hide');
      $('.pricelist.active .toggle-omni-billing').addClass('hide');
      $('.pricelist.active').removeClass('active');
      this.choosePlan(this.clone_button);
    },
    agentChange: function (ev, agent) {
      this.agent_reduced = this.downgrade_launched ? this.current_agent_limit > agent.value : false;
      this.agent_changed = this.current_agent_limit != agent.value;
      var non_omni_plan_id = this.nonOmniId(agent);
      var parent_plan_element = this.parentPlanItem(agent);
      if(this.IsNumeric(agent.value) && agent.value != 0){
        this.agents = Math.abs(agent.value);
        $(".billing-submit").attr("disabled", "true");
        if (this.freddy_option === this.freddy_ultimate_addon_key) {
          this.addons[this.freddy_option]['value'] = this.agents;
        }
        this.callCalculateCost(non_omni_plan_id, parent_plan_element);
      }
      else{
        agent.value = this.agents;
      }
    },
    fieldAgentChange: function (agent) {
      this.field_agent_reduced = this.downgrade_launched ? parseInt(this.field_agents_count) > agent.value : false;
      this.field_agent_changed = parseInt(this.field_agents_count) != agent.value;
      var non_omni_plan_id = this.nonOmniId(agent);
      var parent_plan_element = this.parentPlanItem(agent);
      if(this.IsNumeric(agent.value)) {
        var agents = Math.abs(agent.value);
        $(".billing-submit").attr("disabled", "true");
        this.addons['field_service_management']['value'] = agents;
        this.callCalculateCost(non_omni_plan_id, parent_plan_element);
      } else {
        agent.value = this.field_agents_count;
      }
    },
    freddySessionPackChange: function(sessionPack) {
      this.freddy_session_pack_reduced = this.downgrade_launched ? parseInt(this.freddy_session_pack) > sessionPack.value : false;
      this.freddy_session_pack_changed = parseInt(this.freddy_session_pack) != sessionPack.value;
      var non_omni_plan_id = this.nonOmniId(sessionPack);
      if(this.IsNumeric(sessionPack.value)){
        var freddy_session_pack = Math.abs(sessionPack.value);
        $(".billing-submit").attr("disabled", "true");
        this.includeFreddySessionPacks(freddy_session_pack);
        this.calculateCost(non_omni_plan_id);
      } else {
        sessionPack.value = this.freddy_session_pack || 0;
        this.removeAddon(this.freddy_sessions_addon_key)
      }
    },
    callCalculateCost: function(planId, parentPlanElement){
      if(planId) {
        this.calculateCost(planId);
      } else {
        this.calculateCost(null);
      }
    },
    billingCycleChange: function (billing_period) {
      var non_omni_plan_id = this.nonOmniId(billing_period);
      var parent_plan_element = this.parentPlanItem(billing_period);
      this.billing_cycle_downgraded = this.downgrade_launched ? this.initial_billing_cycle > billing_period.value : false;
      this.billing_cycle_changed = this.initial_billing_cycle != billing_period.value;
      this.billing_cycle = billing_period.value;
      $(".billing-submit").attr("disabled", "true");
      this.callCalculateCost(non_omni_plan_id, parent_plan_element);
    },
    parentPlanItem: function(selectedItem) {
      return jQuery(selectedItem).closest(".pricelist").length ? jQuery(selectedItem).closest(".pricelist") : jQuery(selectedItem).closest(".calculate-container");
    },
    nonOmniId: function(selectedItem){
      var non_omni_plan = null;
      var non_omni_plan_id = null;
      var parent_plan_element = this.parentPlanItem(selectedItem);
      var toggle_button = this.selected_plan.hasClass('pricelist') ? '.omni-toggle-holder .toggle-button' : '.omni-billing-edit .toggle-button'
      if(jQuery(parent_plan_element).find(toggle_button).hasClass("active")) {
       non_omni_plan =  jQuery(parent_plan_element).prev().attr("data-omni-plan-id").indexOf("omni") > 0 ? jQuery(parent_plan_element).prev().attr("data-omni-plan-id") : jQuery(parent_plan_element).prev().attr("data-omni-plan-id").replace(/_/,"_omni_");
       return jQuery(jQuery("[data-omni-plan-id='"+non_omni_plan+"']")[0]).attr("data-plan-id");
      } else {
       non_omni_plan = jQuery(parent_plan_element).prev().attr("data-omni-plan-id").replace("_omni_","_");
       return jQuery(jQuery("[data-omni-plan-id='"+non_omni_plan+"']")[0]).attr("data-plan-id");
      }

    },
    switchToAnnual: function (ev) {
      $('.edit-plan').click();
      this.editBilling = false;
      jQuery('#billing_cycle').val('12').trigger('change');
    },
    trialPlanChange: function (button) {
      var $this = $(button),
      to_plan = $this.data('planId'),
      to_plan_name = $this.data('plan');
      if(to_plan == this.subscribed_plan_id || to_plan_name.indexOf("sprout") != -1 || (to_plan_name.indexOf("garden") || to_plan_name.indexOf("estate"))){
        if($('.pricelist.active .trial-plan-change').hasClass('hide')) {
          $('.pricelist.active .trial-plan-change').removeClass('hide').show();
        }
        $('.pricelist.active').removeClass('active');
        $this.addClass('hide').hide();
        this.choosePlan($this);
      }
    },
    IsNumeric: function(input){
      return (input - 0) == input && input.length > 0;
    },
    currentPlanId: function () {
      return this.current_plan_id;
    },

    toggleOmniPlans: function(button) {
      if(jQuery(button).parent().hasClass("omni-billing-edit") && !jQuery(button).hasClass("active")) {
        this.omni_disabled = true;
      } else if(jQuery(button).hasClass("active")) {
        this.omni_disabled = false;
      }

      if(jQuery(button).hasClass("active")) {
        var plan_name = jQuery(button).prev().data("plan").indexOf("omni") >= 0 ?  jQuery(button).prev().data("plan") : jQuery(button).prev().data("plan").replace("_", "_omni_");
        var amount = jQuery("[data-omni-plan-id='"+plan_name+"']").data("plan-amount");
        var plan_id = jQuery("[data-omni-plan-id='"+plan_name+"']").data("plan-id");
        // jQuery("#plan-"+jQuery(button).prev().data("plan")+" .plan-cost").text(amount);
        this.agents = $("#agents-text-box").val();
        this.calculateCost(plan_id);
      } else {
        var plan_name = jQuery(button).prev().data("plan").replace("_omni", '');
        var amount = jQuery("[data-omni-plan-id='"+plan_name+"']").data("plan-amount");
        var plan_id = jQuery("[data-omni-plan-id='"+plan_name+"']").data("plan-id");
        // jQuery("#plan-"+jQuery(button).prev().data("plan")+" .plan-cost").text(amount);
        this.agents = $("#agents-text-box").val();
        this.calculateCost(plan_id);
      }
    },
    toggleFSMAddon: function(toggler, editBilling, triggerType) {
      var parent_plan = this.selected_plan;
      var non_omni_plan_id = this.nonOmniId(toggler);
      var parent_plan_element = this.parentPlanItem(toggler);
      if(editBilling || (parent_plan.hasClass('active') && !parent_plan.hasClass('hide'))) {
        if($(toggler).hasClass("active")) {
          this.fsm_disabled = false;
          if(triggerType != 'reset') {
            $(".billing-submit").attr("disabled", "true");
            this.addAddon(this.fsm_addon_key, $("#field-agents-text-box").val());
            this.calculateCost(non_omni_plan_id, parent_plan_element);
          }
        } else {
          this.fsm_disabled = true;
          var fsmWarning = editBilling ? $("#warning-btn-fsm-billing-edit") : $("#warning-btn-fsm-billing-change");
          var isEditBilling = jQuery(parent_plan_element).hasClass('calculate-container');
          fsmWarning.length ? this.triggerWarningModal(fsmWarning, non_omni_plan_id) : this.checkAndRemoveFSM('submit', isEditBilling);
        }
      }
    },
    triggerWarningModal: function(WarningElement, non_omni_plan_id) {
      this.selected_plan_id = non_omni_plan_id || null;
      WarningElement.trigger("click")
    },
    checkAndRemoveFSM: function(action, editBilling) {
      if(action === 'submit') {
        this.fsm_disabled = true;
        $(".billing-submit").attr("disabled", "true");
        this.removeAddon(this.fsm_addon_key);
        this.selected_plan_id ? this.calculateCost(this.selected_plan_id) : this.calculateCost();
      } else if(action === 'cancel') {
        var toggler = editBilling ? $(".fsm-billing-edit .toggle-button") : this.selected_plan.find('.fsm-toggle-holder .toggle-button');
        toggler.trigger("click", "reset");
      }
    },
    enableFSMandShowFieldAgents: function() {
      var billing_template = $("#billing-template");
      billing_template.find("#field_agents").removeClass('hide');
      billing_template.find("input[name='addons[field_service_management][enabled]']").val('true');
      billing_template.find("input[name='addons[field_service_management][value]']").val($("#field-agents-text-box").val());
    },
    disableFSMandHideFieldAgents: function() {
      var billing_template = $("#billing-template");
      billing_template.find("#field_agents").addClass('hide');
      billing_template.find("input[name='addons[field_service_management][enabled]']").val('false');
      billing_template.find("input[name='addons[field_service_management][value]']").val('');
    },
    enableFreddy: function(option) {
      var is_freddy_ultimate = option === this.freddy_ultimate_addon_key;
      is_freddy_ultimate ? this.showFreddyUltimateHTML() : this.showFreddySelfServiceHTML();
      var billing_template = $("#billing-template");
      billing_template.find("input[name='addons[freddy_self_service][enabled]']").val(!is_freddy_ultimate);
      billing_template.find("input[name='addons[freddy_ultimate][enabled]']").val(is_freddy_ultimate);
      billing_template.find("input[name='addons[freddy_ultimate][value]']").val(is_freddy_ultimate ? $("#agents-text-box").val(): '');
      this.setFreddySessionPack(billing_template);
    },
    disableFreddy: function() {
      var billing_template = $("#billing-template");
      $("#freddy_self_service, #freddy_ultimate").addClass('hide');
      billing_template.find("input[name='addons[freddy_self_service][enabled]']").val('false');
      billing_template.find("input[name='addons[freddy_ultimate][enabled]']").val('false');
      billing_template.find("input[name='addons[freddy_ultimate][value]']").val('');
      this.setFreddySessionPack(billing_template);
    },
    toggleFreddyAddon: function(toggler, editBilling, triggerType, isFreddyCXSelfService) {
      var parent_plan = this.selected_plan;
      var non_omni_plan_id = this.nonOmniId(toggler);
      var parent_plan_element = this.parentPlanItem(toggler);
      if(editBilling || (parent_plan.hasClass('active') && !parent_plan.hasClass('hide'))) {
        if($(toggler).hasClass("active")) {
          this.freddy_disabled = false;
          this.freddy_option = this.initial_freddy_option || this.freddy_self_service_addon_key;
          if(triggerType != 'reset') {
            $(".billing-submit").attr("disabled", "true");
            if (!isFreddyCXSelfService) {
              $(".freddy-billing-edit").addClass('freddy-billing-exists');
              $(".freddy-cx-options").show();
            }
          }
          if (!isFreddyCXSelfService) {
            this.freddy_option === this.freddy_self_service_addon_key ? this.addFreddySelfServiceAddon() : this.addFreddyUltimateAddon($("#agents-text-box").val());
            $("input[name='freddy_options']").val([this.freddy_option]);
          } else {
            this.addFreddySelfServiceAddon();
          }
          $('.freddy_auto_recharge_section').show();
          this.calculateCost(non_omni_plan_id, parent_plan_element);
        } else {
          var freddyWarning = editBilling ? $("#warning-btn-freddy-billing-edit") : $("#warning-btn-freddy-billing-change");
          var isEditBilling = jQuery(parent_plan_element).hasClass('calculate-container');
          if (freddyWarning.length) {
            this.triggerWarningModal(freddyWarning, non_omni_plan_id);
            this.disableFreddyValues();
          } else {
            this.checkAndRemoveFreddyCX('submit', isEditBilling);
          }
        }
      }
    },
    toggleFreddyCXPlanOptions: function(toggler) {
      var checkedValue = $(toggler).val();
      this.freddy_option = checkedValue;
      checkedValue === this.freddy_self_service_addon_key ? this.addFreddySelfServiceAddon() : this.addFreddyUltimateAddon($("#agents-text-box").val());
      this.calculateCost(this.current_plan_id);
    },
    checkAndRemoveFreddyCX: function(action, editBilling) {
      if(action === 'submit') {
        $('.freddy-cx-options').hide();
        $(".freddy-billing-edit").removeClass('freddy-billing-exists');
        $(".billing-submit").attr("disabled", "true");
        this.disableFreddyValues();
        this.removeFreddyAddon();
        this.includeFreddySessionPacks(this.freddy_addon_count > 2 ? Number($("#freddy-session-pack").val()) : 0);
        this.freddy_sessions > 0 ? $('.freddy_auto_recharge_section').show() : $('.freddy_auto_recharge_section').hide();
        this.selected_plan_id ? this.calculateCost(this.selected_plan_id) : this.calculateCost();
      } else if(action === 'cancel') {
        if (editBilling) {
          if ($(".freddy-cx-self-billing-edit").length) {
            $(".freddy-cx-self-billing-edit .toggle-button").trigger("click", "reset");
          } else {
            $(".freddy-billing-edit .toggle-button").trigger("click", "reset");
          }
        }
      }
    },
    disableFreddyValues: function() {
      this.freddy_disabled = true;
      this.freddy_option = '';
    },
    addFreddySelfServiceAddon: function() {
      this.addons[this.freddy_self_service_addon_key] = { enabled: true };
      this.addons[this.freddy_ultimate_addon_key] = { enabled: false };
    },
    addFreddyUltimateAddon: function(agentValue) {
      this.addAddon(this.freddy_ultimate_addon_key, agentValue);
      this.addons[this.freddy_self_service_addon_key] = { enabled: false };
    },
    removeFreddyAddon: function() {
      this.addons[this.freddy_self_service_addon_key] = { enabled: false };
      this.addons[this.freddy_ultimate_addon_key] = { enabled: false };
    },
    includeFreddySessionPacks: function(sessionPackValue) {
      sessionPackValue != 0 && sessionPackValue != undefined ? this.addAddon(this.freddy_sessions_addon_key, sessionPackValue) : this.addons[this.freddy_sessions_addon_key] = { enabled: false };
    },
    setFreddySessionPack: function(billing_template) {
      var freddy_session_pack = Number($("#freddy-session-pack").val());
      billing_template.find("input[name='addons[freddy_session_packs][enabled]']").val(Boolean(freddy_session_pack));
      billing_template.find("input[name='addons[freddy_session_packs][value]']").val(freddy_session_pack);
    },
    showFreddySelfServiceHTML: function()  {
      $("#freddy_self_service").removeClass('hide');
      $("#freddy_ultimate").addClass('hide');
    },
    showFreddyUltimateHTML: function()  {
      $("#freddy_ultimate").removeClass('hide');
      $("#freddy_self_service").addClass('hide');
    },
    toggleFreddyAutorecharge: function(toggler) {
      if (toggler.checked) {
        toggler.setAttribute('checked', 'checked');
        toggler.value = true;
        $("input[name='freddy_auto_recharge_enabled']").val(true);
        $(".freddy_auto_recharge_packs_section").show();
      } else {
        toggler.removeAttribute('checked');
        toggler.value = false;
        $("input[name='freddy_auto_recharge_enabled']").val(false);
        $('.freddy_auto_recharge_packs_section').hide();
      }
      this.freddy_auto_recharge_enabled_changed = toggler.checked;
      $(".billing-submit").removeAttr("disabled");
    },
    freddyAutoRechargePacksChange: function(pack) {
      if(this.IsNumeric(pack.value) && Boolean(Number(pack.value)) && (pack.value !== this.freddy_auto_recharge_packs) && pack.value >= 0) {
        $("input[name='freddy_auto_recharge_packs']").val(pack.value);
        $(".billing-submit").removeAttr("disabled");
        this.freddy_auto_recharge_packs_changed = pack.value;
      } else {
        pack.value = this.freddy_auto_recharge_packs;
        $("input[name='freddy_auto_recharge_packs']").val(this.freddy_auto_recharge_packs);
      }
    },
    setFreddyAutorecharge: function() {
      if (this.freddy_auto_recharge_enabled_changed) {
        $("#freddy_auto_recharge_enabled_field").attr('checked', 'checked');
        $(".freddy_auto_recharge_packs_section").show();
      } else {
        $("#freddy_auto_recharge_enabled_field").removeAttr('checked');
        $(".freddy_auto_recharge_packs_section").hide();
      }
      $("#freddy_auto_recharge_packs_field").val(this.freddy_auto_recharge_packs_changed);
      $("input[name='freddy_auto_recharge_enabled']").val(this.freddy_auto_recharge_enabled_changed);
      $("input[name='freddy_auto_recharge_packs']").val(Number(this.freddy_auto_recharge_packs_changed));
    },
    addAddon: function(key, value) {
      this.addons[key] = { enabled: true, value: value };
    },
    removeAddon: function(key) {
      delete this.addons[key];
    },
    submitPlanUpdate: function() {
      jQuery(".billing-actions .submit-confirm").hide();
      jQuery(".billing-actions #commit").show().trigger("click");
      this.omni_disabled = null;
    },
    choosePlan: function (button) {
      var btn = $(button),
      current_plan = btn.data("plan"),
      plan_cost = btn.data("planCost"),
      has_free_agents = btn.data("freePlan");
      if(!btn.hasClass('suspended-plan-button')) {
        jQuery(".suspended-plan-button").show();
      }
      var billing_template = $("#billing-template");
      $(".toggle-omni-billing").hide();
      $(".toggle-fsm-billing").hide();

      this.current_active_plan_flag = btn.data("currentPlan");
      if(this.selected_plan != null) {
        this.selected_plan.removeClass('active');
      }
      else {
        $('.pricelist.active').removeClass('active');
      }
      this.current_plan_id = btn.data("planId");
      if(!has_free_agents ){
        if(this.selected_plan != null) this.selected_plan.removeClass('free-plan-options');
      }
      this.selected_plan  = $("#plan-"+current_plan).addClass('active');
      this.agents = $("#agents-text-box").val();
      this.field_agents_count = $("#field-agents-text-box").val();

      if(has_free_agents && !this.current_active_plan_flag){
        if(btn.attr('class').indexOf("plan-button1") >= 0)
          $('.active').removeClass("free-plan-options");
        else
          $('.active').addClass("free-plan-options");
      }else{
        var fsm_addon_value = $("#field-agents-text-box").val();
        var freddy_session_pack = $("#freddy-session-pack").val();
        if(button.classList != undefined && button.classList.contains("edit-plan")) {
          $(".toggle-omni-billing:visible").hide();
          $('#edit-billing-fsm-toggle').is(':checked') ? this.addAddon(this.fsm_addon_key, fsm_addon_value) : this.removeAddon(this.fsm_addon_key);
          if(document.contains($("#edit-billing-freddy-ss-toggle")[0])) {
            $('#edit-billing-freddy-ss-toggle').is(':checked') ? this.addons[this.freddy_self_service_addon_key] = { enabled: true } : this.addons[this.freddy_self_service_addon_key] = { enabled: false };
            this.includeFreddySessionPacks(freddy_session_pack);
          } else {
            if ($('#edit-billing-freddy-toggle').is(':checked')) {
              this.freddy_option === this.freddy_self_service_addon_key ? this.addFreddySelfServiceAddon() : this.addFreddyUltimateAddon(this.agents);
            } else {
              this.removeFreddyAddon();
            }
            this.includeFreddySessionPacks(freddy_session_pack);
          }
        } else {
          var parent = jQuery(this.selected_plan)? "#"+jQuery(this.selected_plan).attr("id") : "#plan-"+button.id.replace("_button", "");
          $(parent).find(".toggle-omni-billing").show();
          var fsm_billing_toggle = $(parent).find(".toggle-fsm-billing");
          if($('#fsm-toggle').is(':checked') && fsm_billing_toggle.length) {
            fsm_billing_toggle.show();
            this.addAddon(this.fsm_addon_key, fsm_addon_value)
          } else {
            this.removeAddon(this.fsm_addon_key);
          }
          if (this.freddy_active) {
            this.initial_freddy_option === this.freddy_self_service_addon_key ?
              this.addFreddySelfServiceAddon() : parent.includes('forest') ? this.addFreddyUltimateAddon($("#agents-text-box").val()) : this.removeFreddyAddon();
          } else {
            this.removeFreddyAddon();
          }
          this.includeFreddySessionPacks((this.initial_freddy_option === this.freddy_self_service_addon_key || parent.includes('forest')) ? this.freddy_session_pack : 0);
        }
        billing_template.addClass("sloading inner-form-hide");
      }
      if(this.current_active_plan_flag){
        this.original_data = $(".subscribed-plan-details").html();
        $(".subscribed-plan-details").html($("#billing-template").show());
        billing_template.find(".billing-cancel").show();
      }
      else {
        billing_template.detach().appendTo(this.selected_plan).show();
        billing_template.find(".billing-cancel").hide();
        if (this.original_data != null) {
          $(".omni-billing-edit").hide();
          var data_content = this.original_data
          $(".subscribed-plan-details").html(data_content);
          this.original_data = null;
        }
      }
      this.calculateCost(null);
    },
    calculateCost: function (planID) {
      var $this = this
      if(this.calculate_request)
        this.calculate_request.abort();

      $("#billing-template").find(".billing-submit").attr("disabled", "disabled");
      var plan_id = planID || this.currentPlanId();
      var omni_downgraded = (this.omni_disabled && (this.current_plan_name.indexOf('omni') > 0));

      var omni_no_change = this.omni_disabled === null || ((this.omni_disabled == true) === !(this.is_omni_plan));

      var fsm_removed = (this.fsm_active && this.fsm_disabled && this.field_agents_count > 0);

      var fsm_no_change = this.initial_fsm_state === this.fsm_disabled;

      var freddy_removed = this.freddy_active && this.freddy_disabled;
      var freddy_downgraded = freddy_removed || (this.initial_freddy_option === this.freddy_ultimate_addon_key && this.freddy_option === this.freddy_self_service_addon_key);

      var freddy_no_change = (this.initial_freddy_state === this.freddy_disabled) && (this.initial_freddy_option === this.freddy_option);

      var request_change = ((this.subscription_state === 'active') && (this.current_agent_limit > this.free_agent_count) && (this.current_plan_name.indexOf('sprout') <= 0)) ? (this.downgrade_launched ? (omni_downgraded || this.agent_reduced || this.field_agent_reduced || fsm_removed || this.billing_cycle_downgraded || freddy_downgraded || this.freddy_session_pack_reduced) : false) : false;

      var plan_changed = this.currentPlanId() ? this.currentPlanId() != $this.subscribed_plan_id : false;

      var should_disabled_update = (omni_no_change && fsm_no_change && freddy_no_change && !this.freddy_session_pack_changed  && !(this.plan_changed) && !(this.agent_changed) && !(this.billing_cycle_changed)) && (!this.fsm_disabled ? !(this.field_agent_changed) : true);

      this.calculate_request = $.post( "/subscription/calculate_amount",
        {
          "billing_cycle": this.billing_cycle,
          "agent_limit" : this.agents,
          "addons" : this.addons,
          "plan_id" : plan_id,
          "currency" : this.currency,
          "request_change": request_change
        },
        function(data) {
          var billing_template = $("#billing-template");
          var billing_actions = $(".billing-actions");
          var billing_toggle = $(".omni-billing-edit .toggle-button");
          billing_template.removeClass("sloading inner-form-hide").html(data);
          $this.initializeAutoRechargeTooltip();
          $this.freddy_auto_recharge_launched ? $this.setFreddyAutorecharge() : '';
          if($this.subscription_state === 'trial' || $this.subscription_state === 'suspended' || (!$this.editBilling && !should_disabled_update) || plan_changed) {
            $(".billing-submit").removeAttr("disabled");
          } else {
            $(".billing-submit").attr("disabled", "disabled");
          }
          $this.editBilling = false;
          $("#plan_id").val(plan_id);
          if($this.current_active_plan_flag) {
            if($(".subscribed-plan-details .billing-info-divider:visible").length <= 0) {
              $(".features-billing-edit").removeClass('hide');
            }
            billing_template.find(".billing-cancel").show();
            var submitText = request_change ? I18n.t('downgrade_policy.change_request') : I18n.t('common_js_translations.update_plan');
            billing_template.find(".billing-submit").val(submitText).addClass('btn-primary');
            billing_template.find(".billing-submit").html(submitText).addClass('btn-primary');
            if(request_change){
              $('.upgrade-same-plan').css('display','none');
              $('.upgrade-same-plan-header').css('display','block');
            }
            if($this.omni_disabled) {
              billing_actions.find(".submit-confirm").show();
              billing_actions.find("#commit").hide();
            } else if($("#omni-billing-edit .toggle-button").hasClass("active")) {
              billing_actions.find(".submit-confirm").hide();
              billing_actions.find("#commit").show();
              $this.omni_disabled = null;
              this.omni_disabled = null;
            }
            if(document.contains($("#edit-billing-freddy-ss-toggle")[0])) {
              $('#edit-billing-freddy-ss-toggle').is(':checked') ? $this.enableFreddy($this.freddy_self_service_addon_key) : $this.disableFreddy();
            } else {
              $('#edit-billing-freddy-toggle').is(':checked') ? $this.enableFreddy($this.freddy_option) : $this.disableFreddy();
            }
            $('#edit-billing-fsm-toggle').is(':checked') ? $this.enableFSMandShowFieldAgents() : $this.disableFSMandHideFieldAgents();
          }
          else {
            if(request_change) {
              billing_template.find(".billing-submit").val(I18n.t('downgrade_policy.change_request'));
              billing_template.find(".billing-submit").html(I18n.t('downgrade_policy.change_request'));
              $('.upgrade-same-plan').css('display','none');
              $('.upgrade-same-plan-header').css('display','block');
            }
            billing_template.find(".billing-cancel").hide();
            billing_template.find(".billing-submit").removeClass('btn-primary');
            var curren_plan_id = $this.selected_plan.attr("id");
            if(curren_plan_id) {
              var fsm_toggle = '#' + curren_plan_id + ' .toggle-fsm-billing';
              $("#"+curren_plan_id + " .toggle-omni-billing").removeClass("hide");
              $(fsm_toggle + ':visible').length && $(fsm_toggle + ' .toggle-button').hasClass('active') ?
                $this.enableFSMandShowFieldAgents()
                : $this.disableFSMandHideFieldAgents();

              if ($this.freddy_active) {
                $this.initial_freddy_option === $this.freddy_self_service_addon_key ?
                  $this.enableFreddy($this.freddy_self_service_addon_key) :
                  curren_plan_id.includes('forest') ?
                    $this.enableFreddy($this.freddy_ultimate_addon_key) : $this.disableFreddy();
              } else {
                $this.disableFreddy();
              }
              $('.freddy_auto_recharge_section').hide();
            }
          }
          $this.perMonthCost();
        }
      );
    },
    perMonthCost: function() {
      var total_cost = $("#total-cost-currency-value").text().trim();
      var agent_count = $("#agents-text-box").val();
      var currency_symbol = total_cost.indexOf("R$") >= 0 ? total_cost.substr(0,2) : total_cost.charAt(0);
      var no_of_months = parseInt(jQuery("#number-of-months").text());
      var per_month_amount  = Math.floor(this.currencyToNumber(total_cost) / no_of_months);
      var per_month_cost = this.currencyToNumber($("#cost-per-month-value").val());
      var per_month_discounted_cost = this.currencyToNumber($("#discounted-cost-per-month-value").val());
      var savings_amount = ((per_month_cost - per_month_discounted_cost) * 12 * agent_count);
      var you_save = currency_symbol+""+savings_amount.toLocaleString();
      var per_month_charges = $(".per-month-charges");

      $(".you-save-amount").text(you_save);
      per_month_charges.find(".symbol").text(currency_symbol);
      per_month_charges.find(".amount").text(per_month_amount);
    },

    currencyToNumber: function(currency_val) {
      return parseInt(currency_val.replace(/^.|,|\$/g, ""));
    },

    destroy: function(){
      $(document).off(this.namespace());
    },

    initializeAutoRechargeTooltip: function() {
      var popover_target = $('.auto-recharge-tooltip');
      if(popover_target){
        popover_target.popover({
          html: true,
          trigger: 'manual',
          placement: 'right',
          reloadContent: false,
          template: "<div class='arrow'></div><div class='inner'><div class='content auto-recharge-content'><p></p></div></div>",
          content: function(){
            return "<div>" +popover_target.attr("data-content") + "</div>"
          }
        }).hover(function(){
          $(this).popover("show");
        })
      }
      this.closePopover();
    },

    closePopover: function() {
      $(document).on('click', function(e){
        if($('.popover').is(':visible')){
          $('.popover').remove();
        }
      })
    }
  };


}(window.jQuery));
