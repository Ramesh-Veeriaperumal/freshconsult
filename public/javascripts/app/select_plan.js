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
    },
    billingCancel: function (ev) {
      ev.preventDefault();
      $("#billing-template").detach().appendTo('#Pagearea').hide();
      var data_content = this.original_data;
      $(".subscribed-plan-details").html(data_content);
    },
    bindPlanChange: function (ev, button) {
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
      $('.pricelist.active').removeClass('active');
      this.choosePlan(this.clone_button);
    },
    agentChange: function (ev, agent) {
      if(this.IsNumeric(agent.value) && agent.value != 0){
        this.agents = Math.abs(agent.value);
        $(".billing-submit").attr("disabled", "true")
        this.calculateCost();
      }
      else{
        agent.value = this.agents;
      }
    },
    billingCycleChange: function (billing_period) {
      this.billing_cycle = billing_period.value;
      $(".billing-submit").attr("disabled", "true")
      this.calculateCost();
    },
    trialPlanChange: function (button) {
      var $this = $(button),
      to_plan = $this.data('planId'),
      to_plan_name = $this.data('plan');

      if(to_plan == this.subscribed_plan_id || to_plan_name == "Sprout"){
        if($('.pricelist.active .trial-plan-change').hasClass('hide'))
          $('.pricelist.active .trial-plan-change').removeClass('hide').show();
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
    choosePlan: function (button) {
      var btn = $(button),
      current_plan = btn.data("plan"),
      plan_cost = btn.data("planCost"),
      has_free_agents = btn.data("freePlan");

      this.current_active_plan_flag = btn.data("currentPlan");
      if(this.selected_plan != null) this.selected_plan.removeClass('active');

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
          var data_content = this.original_data
          $(".subscribed-plan-details").html(data_content);
          this.original_data = null;
        }
      } 
      this.calculateCost();
    },
    calculateCost: function () { 
      var $this = this    
      if(this.calculate_request)
        this.calculate_request.abort();
      var plan_id = this.currentPlanId()
      this.calculate_request = $.post( "/subscription/calculate_amount",
        { "billing_cycle": this.billing_cycle, "agent_limit" : this.agents, 
          "plan_id" : plan_id, "currency" : this.currency },
        function(data){
          $(".billing-submit").removeAttr("disabled");
          $("#billing-template").removeClass("sloading inner-form-hide");
          $("#billing-template").html(data);
          $("#plan_id").val(plan_id);
          if($this.current_active_plan_flag) {
            $("#billing-template .billing-cancel").show();
            $("#billing-template .billing-submit").val("Update Plan");
          } 
          else {
            $("#billing-template .billing-cancel").hide();
          }
        }
      );
    },
    destroy: function(){
      $(document).off(this.namespace());
    }
  };
}(window.jQuery));
