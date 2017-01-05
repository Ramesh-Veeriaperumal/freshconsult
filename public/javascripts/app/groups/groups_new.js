/*jslint browser: true */
/*global App */

/*
 * groups_new.js
 * author: Rajasegar
 */

window.App = window.App || {};

window.App.Groups = window.App.Groups || {};

(function($){
    'use strict';

    App.Groups.New = {
        bCappingFeature: App.exports ? App.exports.capping_feature_enabled : false,
        onFirstVisit: function(data){
            this.onVisit(data);
        },

        init: function(){
            $('#agent_list').select2({
                multiple: true,
                data:     DataStore.get('agent').all().map(function(agent) {
                          return {
                          id: agent.id,
                          text: agent.name
                          };
                          })

            });

            $('#escalate_to').select2({
                multiple: false,
                data:     DataStore.get('agent').all().map(function(agent) {
                                return {
                                id: agent.id,
                                text: agent.name
                                  };
                                })
                          });
  
        },

        onVisit: function(data){
            this.init();
            this.bindHandlers();
        },

        check_conditions_sbrr: function(){
        /**
         * Conditions for sbrrRules.jst.ejs Template
         */
        var is_admin = App.exports.is_admin;
        var any_skill_in_account = App.exports.account_skills_present;
        var list = JST['app/groups/sbrrRules']({
            pageType:'new',
            account_skills_present: any_skill_in_account,
            is_admin: is_admin
        });
        $('.placeholderForRules').html(list);
        },

        bindHandlers: function(){
                //Listeners
                var _this = this;
                var $bodySelector = $("body");
                $bodySelector.ready(function() {
                        $('.ticketAssignmentCheck').find(".toggle-button").removeClass('active');
                        $("[name='group[ticket_assign_type]']").val(0);
                        $('p.limit.load_based').addClass("ui-helper-hidden");
                        $('p.limit.skill_based').addClass("ui-helper-hidden");

                $bodySelector.on('click.groups', "[name='group[capping_enabled]']", function(){
                 if($('#group_capping_enabled_2').is(':checked')){
                  _this.check_conditions_sbrr();
                 }
                });

                });


                $bodySelector.on('change.groups', '.ticketAssignmentCheck', function() {

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

                $bodySelector.on("change.groups", "#agent_list",function() {
                    var agent_count = 0;
                    var agent_list = $("#agent_list").val();
                    if (agent_list !== '') {
                        agent_count = agent_list.split(",").length;
                    }
                    $("#agents_count").text(agent_count);
                });

                $bodySelector.on('change.groups', "#group_ticket_assign_type",function(event) {
                    if (_this.bCappingFeature) {
                        $("#toggle_availability_container,#toggle_method").slideToggle(300, "easeInCubic");
                    } else {
                        $("#toggle_availability_container").slideToggle(300, "easeInCubic");
                    }
                });

                $bodySelector.on('click.groups', '.helpNoteAnchor', function() {
                     $('#popupTrigger').trigger('click');
                });


                $bodySelector.on('shown.groups', '.modal', function(){
                    $('#setFlagforRedirect').val("true");
                }); 

                $bodySelector.on('hidden.groups', '.modal', function(){
                    $('#setFlagforRedirect').val("false");
                }); 

                $bodySelector.on('click.groups', '#alert_content-submit', function() {
                    if( $('#group_name').val().length === 0 ){
                        $('#alert_content-cancel').trigger('click');
                    }
                    $('#group_submit').trigger('click');
                });


                $bodySelector.on('click.groups', '.p', function() {
                    $('#popupTrigger').trigger('click');
                });


                $bodySelector.on('click.groups', "[name='group[capping_enabled]']",function() {
                    var DEFAULT_CAPPING_VALUE = 5;
                    if (this.value == '1') {
                        //Diff btw load and skill based
                        //
                        $("#capping_count_load").val(DEFAULT_CAPPING_VALUE).change();
                        $(".limit.load_based").removeClass('ui-helper-hidden');
                        $(".limit.skill_based").addClass('ui-helper-hidden');
                        $("[name='group[ticket_assign_type]']").val(1);
                        $('.select_skill').prop('disabled', true);
                        $('.select_load').prop('disabled', false);
                        $('.help_note_skills').hide();

                    } else if (this.value == '2') {
                        $("#capping_count_skill").val(DEFAULT_CAPPING_VALUE).change();
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

                $("#group_form").validate();
        },

        onLeave: function(data){
            $("body").off(".groups");
        }
    };
}(window.jQuery));
