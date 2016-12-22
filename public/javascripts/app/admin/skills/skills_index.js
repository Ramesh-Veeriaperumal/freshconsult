/*jslint browser:true */
/*global App */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
window.App.Admin.Skills = window.App.Admin.Skills || {};

(function($) {
  'use strict';

  App.Admin.Skills.Index = {

    onFirstVisit: function(data) {
      this.onVisit(data);
    },

    onVisit: function(data) {
      this.init();
    },

    init: function() {
      this.bindEvents();
    },

    //Initial Construct modal with current agents

    getExistingList: function(idofSkill) {
      var _this = this;
      var Skill_id = idofSkill;

      $.ajax({
        url: '/admin/skills/' + Skill_id + '/users.json',
        type: 'GET',
        dataType: 'json',
        success: function(data) {
          _this.getFields(data);
        },
        error: function(xhr) {
          console.log(xhr);
        }
      });

    },

    //getFields obj receives the current users from getExistingList and populate the modal
    getFields: function(arrayObj) {

      var temp_obj = {};
      for (var i = 0; i < arrayObj.length; ++i) {
        temp_obj[arrayObj[i].id] = arrayObj[i];
      }
      this.selected_agents = $.extend({}, this.selected_agents, temp_obj);
      var listOfIds = (_.keys(this.selected_agents)).toJSON();
      $('#user_ids').val(listOfIds);
      var localData = JSON.parse(localStorage.getItem('currentSelection'));
      this.showPopup(localData.skillid, localData.title, localData.agentcount);
      $('#agents-count').text(_.keys(this.selected_agents).length);
    },

    flushSelect2: function() {
      $('.addAgentHiddenInput').select2('destroy');
      $('#manage-agents').modal('hide');
      $('.roles-agent-list').remove();
    },

    bindEvents: function() {
      var _this = this;
      var $doc = $(document);
      //hack for fixing position of shared reorder template
      $('div#va_rules_sort').css('margin-top', '-10px');

      //on-modal-shown event listener
      $doc.on('shown.skills', '#manage-agents', function() {
        _this.elasticSearchAgents();
        _this.agentTemplate(_.values(_this.selected_agents));
        _this.checkifNoAgents();
        _this.clone_selected_agents = $.extend({}, _this.selected_agents);

      });


      $doc.on('click.skills', 'a.item_info', function() {
        $(this).addClass("disabled").css('color','#06c');
        _this.skillidofCurrent = {};
        var data = Browser.stringify($(this).data());
        localStorage.setItem('currentSelection', data);
        _this.skillidofCurrent[0] = $(this).data('skillid');
        _this.getExistingList(_this.skillidofCurrent[0]);
      });

      // on-modal-hidden event listener
      $doc.on('hidden.skills', '#manage-agents', function() {

        var skillid = JSON.parse(localStorage.getItem('currentSelection')).skillid;
        $('[data-skillid='+ skillid +']').removeClass("disabled");
        $('.addAgentHiddenInput').select2('destroy');
        $('#manage-agents').modal('hide');
        $('.roles-agent-list').remove();
        $('#manage-agents').modal('destroy');
      });


      // cancel-modal event listener
      $doc.on('click.skills', '[data-action="cancelmodal"], .modal-backdrop, .close', function() {
        _this.flushSelect2();
        _this.selected_agents = {};
        _this.temp_agents = {};
        $('#agents-count').text(_.keys(_this.selected_agents).length);

      });

      //esc key event listner
      $doc.keyup(function(e) {
        if (e.keyCode === 27) {
          _this.flushSelect2();
        }
      });

      // submit-modal event listener
      $doc.on('click.skills', '[data-action="submitmodal"]', function() {

        _this.clone_selected_agents = _this.selected_agents;
        _this.UpdateAgentCount();
        _this.printCountInMarkup(_this.skillidofCurrent[0]);
        _this.selected_agents = $.extend({}, _this.selected_agents, _this.temp_agents);
        _this.temp_agents = {};
        _this.flushSelect2();
        // posting updated agent info. to controller
        var listOfIds = (_.keys(_this.selected_agents)).toJSON();
        var Skill_id = _this.skillidofCurrent[0];
        $.ajax({
          url: '/admin/skills/' + Skill_id + '.json',
          type: 'PUT',
          dataType: 'json',
          async: 'true',
          data: { user_ids: listOfIds },
          error: function() {}
        });

        _this.selected_agents = {};
        $('#manage-agents').modal('destroy');
        $('.addAgentHiddenInput').select2('destroy');

      });


      $doc.on('change', '.addAgentHiddenInput', function() {

        var obj = $('input.addAgentHiddenInput').select2('data');
        _this._handleIdAddRemove(($('.addAgentHiddenInput').select2('val').last()), 'add', obj);
        _this.agentTemplate(obj);
        var total_length = _.keys(_this.selected_agents).length + _.keys(_this.temp_agents).length;
        $('#agents-count').text(total_length);
        _this.UpdateAgentCount();
        _this.checkifNoAgents();
      });


      // remove-agent event listener
      $doc.on('click.skills', '[data-action="remove-agent"]', function() {
        var _thisId = $(this);
        _this._removeAgent(_thisId);
      });
    },


    //  * [showPopup Displays the Popup Modal for Add Agents]
    //  * @param  {[int]} id         [skill id]
    //  * @param  {[string]} name    [skill name]
    //  * @param  {[int]} agentcount [total agents in the skill]


    showPopup: function(id, name, agentcount) {
      var _this = this;
      _this._appendContent(name, agentcount, _this._initmodal);
      var $agentSelectBox = $('#manage-agents-content .add-agent-box, #manage-agents-content .button-container');
      $agentSelectBox.show();
      _this.temp_agents = {};
    },

    content: function() {
      var popupContent = $('#popup-content').html();
      $('#popup-content').remove();
      return popupContent;

    },

    //show the popover
    _appendContent: function(name, agentcount, cbforInitModal) {
      var _this = this;
      $('#manage-agents').html(_this.content);
      cbforInitModal(name, agentcount);
    },

    _initmodal: function(name, agentcount) {
      var params = {
        templateHeader: '<div class="modal-header">' +
          '<p class="ellipsis modal-roles-header"><span>Agents</span> (<span id="agents-count">' + agentcount + '</span>)</p><span class="muted">' + name + '</span></div>',
        targetId: '#manage-agents',
        title: name ? name : I18n.t('new'),
        width: '400',
        templateFooter: false,
        showClose: true,
        keyboard: true
      };
      $.freshdialog(params);
    },


    elasticSearchAgents: function() {
      var _this = this;
      $('.addAgentHiddenInput').select2({
        minimumInputLength: 2,
        multiple: true,
        placeholder: 'Add Agent',
        allowClear: true,
        ajax: {
          url: '/search/autocomplete/agents',
          dataType: 'json',
          delay: 250,
          data: function(term, page) {
            var searchText = term;
            return {
              q: term, // search term
            };
          },
          results: function(data, params) {
            var results = [];
            $.each(data.results, function(index, item) {
              var selected_agents_arr = _.keys($.extend({}, _this.selected_agents, _this.temp_agents));
              if ($.inArray(item.user_id + "", selected_agents_arr) == -1) {
                results.push({
                  id: item.user_id,
                  text: item.value,
                  profile_img: item.profile_img
                });
              }
            });

            return {
              results: results
            };
          },
          cache: true
        }
      });
    },

    agentTemplate: function(obj) {
      var _this = this;
      var newObj = _.sortBy(obj, 'forSort');
      var list = JST['app/admin/skills/templates/add_user']({
        data: newObj,
        userLen: newObj.length
      });
      $('#manage-agents .agent-list-wrapper').append(list);
      $('.addAgentHiddenInput').select2('val', "");
      _this.UpdateAgentCount();
    },

    UpdateAgentCount: function() {
      var _this = this;

      var total_length = _.keys(_this.selected_agents).length + _.keys(_this.temp_agents).length;
      var updatedCount = total_length;
      $("[data-skillid=" + _this.skillidofCurrent[0] + "]").data('agentcount', updatedCount);
      $('#agents-count').html(updatedCount);
      $('.modal-body').css("max-height", "none");
      var agentListWrapperHeight = (updatedCount * 52) + "px";
      $('.agent-list-wrapper').height(agentListWrapperHeight);
      $('.agent-list-wrapper').animate({ scrollTop: $('.agent-list-wrapper').height() }, 800);

      _this.checkifNoAgents();

    },

    _removeAgent: function($domobj) {
      var _this = this;
      var _id = $domobj.parents('.roles-agent-list').attr('id');
      $domobj.parents('.roles-agent-list').remove();
      _this._handleIdAddRemove((_id), "remove");
      var total_length = _.keys(_this.selected_agents).length + _.keys(_this.temp_agents).length;
      $("#agents-count").text(total_length);
      _this.UpdateAgentCount();
    },

    _handleIdAddRemove: function(lastId, choice, data_source) {
      var _this = this;

      if (choice === 'add') {
        _this.temp_agents[lastId] = data_source[0];
      } else {
        delete _this.temp_agents[lastId];
        delete _this.selected_agents[lastId];
      }

    },
    selected_agents: {},
    clone_selected_agents: {},

    printCountInMarkup: function(skill_id) {
      var _this = this;
      var updatedCount = _.keys(_this.selected_agents).length + _.keys(_this.temp_agents).length;

      if (updatedCount == 1) {
        $("[data-skillid=" + skill_id + "]").html(updatedCount + " Agent");
      } else if (updatedCount > 1) {
        $("[data-skillid=" + skill_id + "]").html(updatedCount + " Agents");
      } else {
        $("[data-skillid=" + skill_id + "]").html(updatedCount + " Agent");
      }
    },

    checkifNoAgents: function() {
      var Template = '<div class=\'no-agent-info\'>' + 'No agent added' + '</div>';
      var len = $('.agent-list-wrapper').children('.roles-agent-list').length;
      var $agentListWrapper = $('.agent-list-wrapper');
      if (len === 0) {
        $agentListWrapper.html(Template);
      } else {
        $agentListWrapper.find('.no-agent-info').remove();
      }
    },

    onLeave: function() {
      $(document).off('.skills');
    }
  };
}(window.jQuery));
