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
    current_plan_id : null,
    currency : null,
    original_data : null,
    current_active_plan_flag : false,
    billing_cycle : null,
    subscribed_plan_id : null,
    omni_disabled: null,
    initialize: function (currency, billing_cycle, subscribed_plan_id) {
      this.currency = currency;
      this.billing_cycle = billing_cycle;
      this.subscribed_plan_id = subscribed_plan_id;
      this.bindEvents()
    },
    namespace: function(){
      return '.selectplans';
    },
    bindEvents: function(){
      var $this = this
      $(document).on('click'+$this.namespace(),  '.billing-cancel', function(ev){ $this.billingCancel(ev); })
      $(document).on('click'+$this.namespace(),  '.plan-button, .plan-button1', function(ev){ $this.bindPlanChange(ev, this) })
      $(document).on('click'+$this.namespace(),  '.suspended-plan-button', function(ev){ $this.bindSuspendedPlanChange(ev,this) })
      $(document).on('click'+$this.namespace(),  '.downgrade-plan-button', function(){ $this.cloneButton(this) })
      $(document).on('click'+$this.namespace(),  '.downgrade-modal .btn-primary', function(){ $this.closeModal() })
      $(document).on('change'+$this.namespace(), '#agents-text-box', function(ev){ $this.agentChange(ev, this) })
      $(document).on('change'+$this.namespace(), '#billing_cycle', function(){ $this.billingCycleChange(this) })
      $(document).on('click'+$this.namespace(),  '.trial-plan-change', function(){ $this.trialPlanChange(this) })
      $(document).on('click'+$this.namespace(),  '.omni-toggle-holder .toggle-button', function(){ $this.toggleOmniPlans(this) })
      $(document).on('click'+$this.namespace(),  '.omni-billing-edit .toggle-button', function(){ $this.toggleOmniPlans(this) })
      $(document).on('click'+$this.namespace(),  '#omni-disable-confirmation-submit', function(){ $this.submitPlanUpdate(this) })
    },
    billingCancel: function (ev) {
      ev.preventDefault();
      $("#billing-template").detach().appendTo('#Pagearea').hide();
      $(".omni-billing-edit").hide();
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
      var non_omni_plan_id = this.nonOmniId(agent);
      var parent_plan_element = this.parentPlanItem(agent);
      if(this.IsNumeric(agent.value) && agent.value != 0){
        this.agents = Math.abs(agent.value);
        $(".billing-submit").attr("disabled", "true");
        this.callCalculateCost(non_omni_plan_id, parent_plan_element);
      }
      else{
        agent.value = this.agents;
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
      if(jQuery(parent_plan_element).find(".toggle-button").hasClass("active")) {
       non_omni_plan = jQuery(parent_plan_element).prev().attr("data-omni-plan-id").replace(/_/,"_omni_");
       return jQuery(jQuery("[data-omni-plan-id='"+non_omni_plan+"']")[0]).attr("data-plan-id");
      } else {
       non_omni_plan = jQuery(parent_plan_element).prev().attr("data-omni-plan-id").replace("_omni_","_");
       return jQuery(jQuery("[data-omni-plan-id='"+non_omni_plan+"']")[0]).attr("data-plan-id");
      }

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
        jQuery(".billing-actions .submit-confirm").show();
        jQuery(".billing-actions #commit").hide();
      } else if(jQuery(button).hasClass("active")) {
        this.omni_disabled = false;
        jQuery(".billing-actions .submit-confirm").hide();
        jQuery(".billing-actions #commit").show();
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
      $(".toggle-omni-billing").hide();

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
      if(has_free_agents && !this.current_active_plan_flag){
        if(btn.attr('class').indexOf("plan-button1") >= 0)
          $('.active').removeClass("free-plan-options");  
        else
          $('.active').addClass("free-plan-options");
      }else{
        if(button.classList != undefined && button.classList.contains("edit-plan")) {
          $(".toggle-omni-billing:visible").hide();
        } else {
          var parent = jQuery(this.selected_plan)? "#"+jQuery(this.selected_plan).attr("id") : "#plan-"+button.id.replace("_button", "");
          $(parent + " .toggle-omni-billing").show();
        }
        $("#billing-template").addClass("sloading inner-form-hide");
      }
      if(this.current_active_plan_flag){
        
        this.original_data = $(".subscribed-plan-details").html();
        $(".subscribed-plan-details").html($("#billing-template").show());
        $("#billing-template .billing-cancel").show();
      }
      else {
        $("#billing-template").detach().appendTo(this.selected_plan).show();
        $("#billing-template .billing-cancel").hide();
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

      var plan_id = planID || this.currentPlanId();
      this.calculate_request = $.post( "/subscription/calculate_amount",
        { "billing_cycle": this.billing_cycle, "agent_limit" : this.agents, 
          "plan_id" : plan_id, "currency" : this.currency },
        function(data){
          $(".billing-submit").removeAttr("disabled");
          $("#billing-template").removeClass("sloading inner-form-hide");
          $("#billing-template").html(data);
          $("#plan_id").val(plan_id);
          if($this.current_active_plan_flag) {
            if(jQuery(".subscribed-plan-details .billing-info-divider:visible").length <= 0) {
              $(".omni-billing-edit").show();
            }
            $("#billing-template .billing-cancel").show();
            $("#billing-template .billing-submit").val(I18n.t('common_js_translations.update_plan'));
            $("#billing-template .billing-submit").addClass('btn-primary');
            // $("#billing-template .billing-submit").removeClass('btn-flat');
            if($this.omni_disabled) {
              jQuery(".billing-actions .submit-confirm").show();
              jQuery(".billing-actions #commit").hide();
            } else if(jQuery("#omni-billing-edit .toggle-button").hasClass("active")) {
              jQuery(".billing-actions .submit-confirm").hide();
              jQuery(".billing-actions #commit").show();
              $this.omni_disabled = null;
              this.omni_disabled = null;
            }
          } 
          else {
            $("#billing-template .billing-cancel").hide();
            // $("#billing-template .billing-submit").addClass('btn-flat');
            $("#billing-template .billing-submit").removeClass('btn-primary');
            var curren_plan_id = $this.selected_plan.attr("id");
            if(curren_plan_id) {
              $("#"+curren_plan_id+" .toggle-omni-billing").removeClass("hide");              
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
      var you_save = currency_symbol+""+((per_month_cost * 12 * agent_count) - this.currencyToNumber(total_cost));

      $(".you-save-amount").text(you_save);
      $(".per-month-charges .symbol").text(currency_symbol);
      $(".per-month-charges .amount").text(per_month_amount);
    },

    currencyToNumber: function(currency_val) {
      return parseInt(currency_val.replace(/^.|,|\$/g, ""));
    },

    destroy: function(){
      $(document).off(this.namespace());
    }
  };
}(window.jQuery));
