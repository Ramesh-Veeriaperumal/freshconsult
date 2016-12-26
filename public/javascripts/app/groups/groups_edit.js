/*jslint  browser: true */
/*global App */

/*
 * groups_edit.js
 * author: Rajasegar
 */

window.App = window.App || {};
window.App.Groups = window.App.Groups || {};

(function($) {
  'use strict';

  // VARIOUS TICKET ASSIGNMENT TYPES
  var ASSIGNMENTS = {
    DEFAULT: 0,
    ROUND_ROBIN: 1,
    SKILL_BASED: 2
  };

  var defaultGroup = {
    ticket_assign_type: 0,
    toggle_availability: 0,
    escalate_to: 0
  };


  App.Groups.Edit = {
    _group: (App.exports && App.exports.current_group) ? App.exports.current_group.group : defaultGroup,
    bCappingFeature: App.exports ? App.exports.capping_feature_enabled : false,
    escalationAgent: App.exports ? App.exports.escalation_agent : "",

    onFirstVisit: function(data) {
      this.onVisit(data);
    },

    onVisit: function(data) {
      this.init();
      this.bindHandlers();
    },

    init: function() {
      //Initial population

      var auto_assign_ticket = this._group.ticket_assign_type > 0;

      var toggle_state = this._group.toggle_availability;

      var ticket_assign_type = this._group.ticket_assign_type;


      if (auto_assign_ticket) { //Section opening
        $("#toggle_availability_container,#toggle_method").show();
      }

      var capping_enabled = App.exports.capping_enabled || false;


      if (this.bCappingFeature) { //for this whole acc.
        if (capping_enabled) { //for this group
          switch (ticket_assign_type) {

            case ASSIGNMENTS.ROUND_ROBIN:
              $("#group_capping_enabled_1").prop('checked', true);
              $(".limit.load_based").removeClass('ui-helper-hidden');
              $("[name='group[ticket_assign_type]']").val(ASSIGNMENTS.ROUND_ROBIN);
              break;

            case ASSIGNMENTS.SKILL_BASED:
              $("#group_capping_enabled_2").prop('checked', true);
              $(".limit.skill_based").removeClass('ui-helper-hidden');
              $('.toggle-button').addClass("active");
              $("[name='group[ticket_assign_type]']").val(ASSIGNMENTS.SKILL_BASED);
              break;

            default:
              break;
          }
        } else {
          $("#group_capping_enabled_0").prop('checked', true);
        }
      } else {
        //Default
        $("[name='group[ticket_assign_type]']").val(ASSIGNMENTS.DEFAULT);
        $("[rel=only_round]").removeClass('ui-helper-hidden');
        $("[rel=process_desc]").addClass('ui-helper-hidden');
        $("#toggle_method").hide();
      }

      /* end of ticket assignment related code */


      this.initSelect2();


    },

    initSelect2: function() {
      var _this = this;
      $('#agent_list').select2({

        multiple: true,
        data: DataStore.get('agent').all().map(function(agent) {
              return {
              id: agent.id,
              text: agent.name
          };
        }),
        initSelection: function(element, callback) {
          callback(App.exports.selected_agents);
        }
      });
      $("#agent_list").select2("val", []);

      $("#agent_list").on("change", function() {
        var agent_count = 0;
        var agent_list = $("#agent_list").val();
        if (agent_list !== '') {

          agent_count = agent_list.split(",").length;
        }
        $("#agents_count").text(agent_count);
      });

      var escalateTo = this._group.escalate_to;

      $('#escalate_to').select2({
        multiple: false,
        data:     DataStore.get('agent').all().map(function(agent) {
                  return {
                  id: agent.id,
                  text: agent.name
                    };
                  }),
        initSelection: function(element, callback) {
          var data = {
            id: _this._group.escalate_to,
            text: _this.escalationAgent
          };
          callback(data);
        }
      });


      $("#escalate_to").select2("val", escalateTo);


    },

    check_conditions_sbrr: function(){
    /**
     * Conditions for sbrrRules.jst.ejs Template
     */
    var is_admin = App.exports.is_admin;
    var any_skill_in_account = App.exports.account_skills_present;
    var current_group_id = App.exports.current_group.group.id;
    
          $.ajax({
              url: '/groups/'+current_group_id+'/user_skill_exists',
              type: 'GET',
              async: 'false',
              dataType: 'json',
              })
              .done(function(data) {
                var any_skill_in_current_agents = data.user_skill_exists;
                   var list = JST['app/groups/sbrrRules']({
                    pageType:'edit',
                    account_skills_present: any_skill_in_account,
                    is_admin: is_admin,
                    any_skill_in_current_agents: any_skill_in_current_agents
                  });
                  $('.placeholderForRules').html(list);

              })
              .fail(function() {
                console.log("error in groups_edit js");
              });
    },

    bindHandlers: function() {
      var _this = this;
      var $bodySelector = $("body");
      //Listeners
      
      $bodySelector.ready(function() {
         if($('#group_capping_enabled_2').is(':checked')){
          _this.check_conditions_sbrr();
         }

      $bodySelector.on('click.groups', "[name='group[capping_enabled]']", function(){
         if($('#group_capping_enabled_2').is(':checked')){
          _this.check_conditions_sbrr();
         }
      });


      });


      $bodySelector.on('change.groups', "#group_ticket_assign_type", function(event) {
        if (_this.bCappingFeature) {
          $("#toggle_availability_container,#toggle_method").slideToggle(300, "easeInCubic");
        } else {
          $("#toggle_availability_container").slideToggle(300, "easeInCubic");
        }
      });

      if ($("[name='group[ticket_assign_type]']").val() == 2) {
        $('.help_note_skills').show();
      } else {
        $('.help_note_skills').hide();
      }


      $bodySelector.on('click.groups', '.ticketAssignmentCheck', function() {

        if ($('.ticketAssignmentCheck').find(".toggle-button").hasClass('active')) {
          $("[name='group[ticket_assign_type]']").val(1);
          $("#group_capping_enabled_0").prop('checked', true);
          $('p.limit.load_based').addClass("ui-helper-hidden");
          $('p.limit.skill_based').addClass("ui-helper-hidden");
          $('.help_note_skills').hide();

        } else {
          $("[name='group[ticket_assign_type]']").val(0);
        }
      });


      var origForm = $('#group_form').serialize();
      var bCappingChanged = "false";
      sessionStorage.setItem('cap_value', bCappingChanged);

      $bodySelector.on('change.groups', '#group_form :input', function() {
        bCappingChanged = ($('#group_form').serialize() != origForm) ? "true" : "false";
        // Storing current form state if changed, in session var
        sessionStorage.setItem('cap_value', bCappingChanged);
      });

      $bodySelector.on('shown.groups', '.modal', function() {
        var change_check = sessionStorage.getItem('cap_value');
        $('#setFlagforRedirect').val(change_check);
      });

      $bodySelector.on('hidden.groups', '.modal', function() {
        $('#setFlagforRedirect').val("false");
      });


      //   handling events on helpNoteAnchor class below to check
      //   if any changes were made to form before clicking link
      $bodySelector.on('click.groups', '.helpNoteAnchor', function() {
        var urlTo = $('.helpNoteAnchor').data('path-to');
        if (urlTo == "/admin/agent_skills") {
          urlTo = urlTo + "?group_id=" + App.exports.current_group.group.id;
        }
        var change_check = sessionStorage.getItem('cap_value');


        if (change_check == "false") {
          window.location.href = urlTo;
        } else {
          $('#popupTrigger').trigger('click');
        }
      });


      $bodySelector.on('click.groups', '#alert_content-submit', function() {
        $('#group_submit').trigger('click');
      });


      $bodySelector.on('click.groups', "[name='group[capping_enabled]']", function() {
        var DEFAULT_CAPPING_VALUE = 5;
        if (this.value == '1') {
          //Diff btw load and skill based
          if (_this._group.capping_limit === 0) { $("#capping_count_load").val(DEFAULT_CAPPING_VALUE).change(); } else {
            $("#capping_count_load").val(_this._group.capping_limit).change();
          }
          $(".limit.load_based").removeClass('ui-helper-hidden');
          $(".limit.skill_based").addClass('ui-helper-hidden');
          $("[name='group[ticket_assign_type]']").val(1);
          $('.select_skill').prop('disabled', true);
          $('.select_load').prop('disabled', false);
          $('.help_note_skills').hide();

        } else if (this.value == '2') {
          if (_this._group.capping_limit === 0) { $("#capping_count_skill").val(DEFAULT_CAPPING_VALUE).change(); } else {
            $("#capping_count_skill").val(_this._group.capping_limit).change();
          }
          $(".limit.skill_based").removeClass('ui-helper-hidden');
          $(".limit.load_based").addClass('ui-helper-hidden');
          $("[name='group[ticket_assign_type]']").val(2);
          $('.select_load').prop('disabled', true);
          $('.select_skill').prop('disabled', false);
          $('.help_note_skills').show();

        } else {
          $(".limit").addClass('ui-helper-hidden');
          $("[name='group[ticket_assign_type]']").val(1);
          $('.help_note_skills').hide();
          $('p.limit.load_based').addClass("ui-helper-hidden");
          $('p.limit.skill_based').addClass("ui-helper-hidden");

        }
      }).trigger("change.groups");
    },

    onLeave: function(data) {
      $('body').off('.groups');
    }

  };

}(window.jQuery));
