/*jslint browser:true */
/*global App */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
window.App.Admin.Skills = window.App.Admin.Skills || {};

(function($) {
  'use strict';

  App.Admin.Skills.New = {

    onFirstVisit: function(data) {
      this.onVisit(data);
    },

    onVisit: function(data) {
      this.init();
    },

    init: function() {
      this.bindEvents();
    },


    flushSelect2: function() {
      $('.addAgentHiddenInput').select2('destroy');
      $('#manage-agents').modal('hide');
      $('.roles-agent-list').remove();
    },

    bindEvents: function() {
      var _this = this;
      var $doc = $(document);
      //binding on-click events
      $doc.on('shown.skills', '.modal', function() {
        $('.addAgentHiddenInput').select2('destroy');
        _this.UpdateAgentCount();
        _this.elasticSearchAgents();
        _this.agentTemplate(_.values(_this.selected_agents));
        _this.checkifNoAgents();
        _this.clone_selected_agents = $.extend({}, _this.selected_agents);


      });

      $doc.on('click.skills', 'a.popup', function() {
        var data = $(this).data();
        _this.showPopup(data.skillid, data.title, data.agentcount, data.isaccadmin);
        $('#agents-count').text(_.keys(_this.selected_agents).length);
      });

      // on-modal-hide event listener
      $doc.on('hidden.skills', '#manage-agents', function() {

        $('.addAgentHiddenInput').select2('destroy');
        $('#manage-agents').modal('hide');
        $('.roles-agent-list').remove();
        $('#manage-agents').modal('destroy');
      });

      // cancel-modal event listener
      $doc.on('click.skills', '[data-action="cancelmodal"], .modal-backdrop, .close', function() {
        _this.selected_agents = _this.clone_selected_agents;
        _this.flushSelect2();
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
        _this.printCountInMarkup();
        _this.flushSelect2();
        _this.selected_agents = $.extend({}, _this.selected_agents, _this.temp_agents);
        _this.temp_agents = {};

        // setting array of agent id's into hidden input tag
        var listOfIds = (_.keys(_this.selected_agents)).toJSON();
        $('#user_ids').val(listOfIds);
        $('#manage-agents').modal('hide');
        $('.addAgentHiddenInput').select2('destroy');
      });

      // remove-agent event listener
      $doc.on('click.skills', '[data-action="remove-agent"]', function() {
        var _thisId = $(this);
        _this.removeAgent(_thisId);
      });

      $doc.on('change.skills', '.addAgentHiddenInput', function() {

        var obj = $('input.addAgentHiddenInput').select2('data');
        _this._handleIdAddRemove(($('.addAgentHiddenInput').select2('val').last()), 'add', obj);
        _this.agentTemplate(obj);
        var total_length = _.keys(_this.selected_agents).length + _.keys(_this.temp_agents).length;
        $('#agents-count').text(total_length);
        _this.UpdateAgentCount();
        _this.checkifNoAgents();


      });

    },

    //  * [showPopup Displays the Popup Modal for Add Agents]
    //  * @param  {[int]} id         [skill id]
    //  * @param  {[string]} name    [skill name]
    //  * @param  {[int]} agentcount [total agents in the skill]
    //  * @param  {[bool]} isaccadmin[returns 1 or 0 based on current user permission]

    showPopup: function(id, name, agentcount, isaccadmin) {
      var _this = this;
      _this.appendContent(name, agentcount, _this.initmodal);
      var $agentSelectBox = $('#manage-agents-content .add-agent-box, #manage-agents-content .button-container');
      if (isaccadmin && $('#is-accadmin').val() === 'false') {
        $agentSelectBox.hide();
      } else {
        $agentSelectBox.show();
      }
      _this.temp_agents = {};
    },

    content: function() {
      var popupContent = $('#popup-content').html();
      $('#popup-content').remove();
      return popupContent;

    },

    //show the popover
    appendContent: function(name, agentcount, cbforInitModal) {
      var _this = this;
      $('#manage-agents').html(_this.content);
      cbforInitModal(name, agentcount);
    },

    initmodal: function(name, agentcount) {
      var titleTemplate = '';
      var params = {
        templateHeader: '<div class="modal-header">' +
          '<p class="ellipsis modal-roles-header"><span>Agents</span> (<span id="agents-count">' + agentcount + '</span>)</p>' +
          titleTemplate +
          '</div>',
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
          url: "/search/autocomplete/agents",
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
              if ($.inArray(item.user_id + '', selected_agents_arr) == -1) {
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

      var newObj = _.sortBy(obj, 'forSort');
      var list = JST['app/admin/skills/templates/add_user']({
        data: newObj,
        userLen: newObj.length
      });
      $('#manage-agents .agent-list-wrapper').append(list);
      $('.addAgentHiddenInput').select2('val', '');
    },

    UpdateAgentCount: function() {

      var total_length = _.keys(this.selected_agents).length + _.keys(this.temp_agents).length;
      var updatedCount = total_length;
      var $agentListWrapper = $('.agent-list-wrapper');
      $('.modal-body').css('max-height', 'none');
      $('a.popup').data('agentcount', updatedCount);
      $('#agents-count').html(updatedCount);
      var agentListWrapperHeight = (updatedCount * 52) + 'px';
      $agentListWrapper.height(agentListWrapperHeight);
      $agentListWrapper.animate({ scrollTop: $('.agent-list-wrapper').height() }, 800);

      this.checkifNoAgents();

    },

    removeAgent: function($domobj) {

      var _id = $domobj.parents('.roles-agent-list').attr('id');
      $domobj.parents('.roles-agent-list').remove();
      this._handleIdAddRemove((_id), 'remove');
      var total_length = _.keys(this.selected_agents).length + _.keys(this.temp_agents).length;
      $('#agents-count').text(total_length);
      this.UpdateAgentCount();
    },

    _handleIdAddRemove: function(lastId, choice, data_source) {

      if (choice === 'add') {
        this.temp_agents[lastId] = data_source[0];
      } else {
        delete this.temp_agents[lastId];
        delete this.selected_agents[lastId];
      }

    },

    selected_agents: {},
    clone_selected_agents: {},

    printCountInMarkup: function() {
      var total_length = _.keys(this.selected_agents).length + _.keys(this.temp_agents).length;
      var updatedCount = total_length;
      var $agentCountString = $('a.popup [data-changecount]');
      var $addorManageText = $('a.popup [data-addmanage]');

      if (updatedCount == 1) {
        $agentCountString.html(updatedCount + ' Agent');
        $addorManageText.html('<b>Manage</b>');
      } else if (updatedCount > 1) {
        $agentCountString.html(updatedCount + ' Agents');
        $addorManageText.html('<b>Manage</b>');
      } else {
        $agentCountString.html('No Agent');
        $addorManageText.html('<b>Add</b>');
      }
    },


    onLeave: function() {
      $(document).off('.skills');
    },


    checkifNoAgents: function() {
      var Template = "<div class='no-agent-info'>" + "No agent added" + "</div>";
      var len = $('.agent-list-wrapper').children('.roles-agent-list').length;
      var $agentListWrapper = $('.agent-list-wrapper');
      if (len === 0) {
        $agentListWrapper.html(Template);
      } else {
        $agentListWrapper.find('.no-agent-info').remove();
      }
    }
  };
}(window.jQuery));
