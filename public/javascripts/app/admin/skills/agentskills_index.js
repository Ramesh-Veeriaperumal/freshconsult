/*jslint browser:true */
/*global App */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
window.App.Admin.AgentSkills = window.App.Admin.AgentSkills || {};

(function($) {
  'use strict';

  App.Admin.AgentSkills.Index = {

    onFirstVisit: function(data) {
      this.onVisit(data);
    },

    onVisit: function(data) {
      this.init();
    },

    init: function() {
      this.bindEvents();
    },

    getExistingList: function(userid) {
      var _this = this;
      $.ajax({
        url: "/admin/agent_skills/" + userid,
        type: "GET",
        dataType: 'json',
        success: function(data) {
          _this.existing_list = data;
          var currentAgentArray = _this.formattedObject(data);
          _this.agentTemplate(currentAgentArray);
          _this.innitiateSelect2();
          _this.enableSelectable();
          _this.partialHideOnPermissions();
          _this.customResizeModal();
          _this.checkifNoSkills();
        }
      });
    },

    enableSelectable: function() {
      $('.agent-list-wrapper').sortable({
        containment: "parent",
        tolerance: "pointer",
        forcePlaceholderSize: true,
        placeholder: 'placeholderForSortable'
      });
    },

    formattedObject: function(arrayOfObj) {

      return arrayOfObj.map(function(skill) {
        return {
          row_id: skill.id,
          rank: skill.rank,
          text: skill.name,
          skill_id: skill.skill_id
        };
      });


    },

    bindEvents: function() {
      var _this = this;

      _this.allSkillsObj = App.exports.allSkills.toJSON();
      var $doc = $(document);

      //binding on-click events
      $doc.on('shown.agentskills', ".modal", function() {
        $('.agent-list-wrapper').addClass("selectableitems");
        document.activeElement.blur();
      });

      $doc.on('click.agentskills', 'a.manageSkills', function() {

        var data = $(this).data();

        var localdata = Browser.stringify(data);
        localStorage.setItem('currentUserDataAttrib', localdata);

        localStorage.currentUserID = data.userid;
        _this.getExistingList(data.userid);
        _this.appendContent(data.username, data.skillcount, _this.initmodal);

      });

      $doc.on('click.agentskills', '#group_selector', function(e) {
        e.stopPropagation();
        $('.user_skill_dropdown').toggle();
      });

      $doc.on('click.agentskills', function() {
        $('.user_skill_dropdown').hide();
      });


      // on-modal-hide event listener
      $doc.on("hidden.agentskills", '#manage-agents', function() {
        $('.roles-agent-list').remove();
        $(".addAgentHiddenInput").select2('destroy');
        $("#manage-agents").modal('destroy');
        _this.customResizeModal();

      });

      // cancel-modal event listener
      $doc.on('click.agentskills', '[data-action="cancelmodal"], .modal-backdrop, .close', function() {
        $("#manage-agents").modal('hide');
        _this.deletedItems = [];
        _this.addAndUpdateItems = [];
      });


      // submit-modal event listener
      $doc.on('click.agentskills', '[data-action="submitmodal"]', function() {

        _this.recreateRank();
        var finalArray = (_this.deletedItems).concat(_this.addAndUpdateItems);
        finalArray = finalArray.toJSON();
        $.ajax({
          url: "/admin/agent_skills/" + localStorage.currentUserID,
          type: "PUT",
          data: { user_skills_attributes: finalArray },
          error: function() {
            console.log("couldnt submit data");
          }
        }).fail(function(data) {
          console.log('ajax failed: ', data);
        });
        _this.printSkillsInMarkup(_this.finalAgentArray);
        $("#manage-agents").modal('hide');
        _this.deletedItems = [];
        _this.addAndUpdateItems = [];
        _this.finalAgentArray = [];


      });

      // remove-agent event listener
      $doc.on('click.agentskills', '[data-action="remove-agent"]', function() {
         if (App.exports.is_admin) { 
            _this.removeAgent($(this));
            _this.deletedArray($(this));
         } 
      });


      $doc.on('change.agentskills', '.addAgentHiddenInput', function() {

        var obj = $('input.addAgentHiddenInput').select2('data');
        var HEIGHT_OF_EACH_ROW = 52;
        var addedSkillCount = $('.agent-list-wrapper').children().length;
        var scrollDownHeightforModal = addedSkillCount * HEIGHT_OF_EACH_ROW;
        _this.existing_list.push(obj[0]);
        _this.agentTemplate(obj);
        _this.customResizeModal();
        $('.agent-list-wrapper').animate({ scrollTop: scrollDownHeightforModal }, 800);
        setTimeout(function() { _this.innitiateSelect2(); }, 0);
        _this.checkifNoSkills();

      });


    },

    partialHideOnPermissions: function() {
      var $agentSelectBox = $('.add-agent-box, .agent-delete-icon.pull-left');
      if (App.exports.is_admin === false) {
        $agentSelectBox.hide();
      } else {
        $agentSelectBox.show();
      }
    },

    printSkillsInMarkup: function(arr) {
      var $currentUserRow = $("#" + localStorage.currentUserID);
      var tempString, finalString, i;
      var skillCount = arr.length,
        doubleSpace = "&nbsp;&nbsp;";

      if (skillCount === 0) {
        finalString = "";
        $('[data-userid=' + localStorage.currentUserID + '].skillsModalLink').html("Add Skills");
      } else {
        if (skillCount == 1) {
          finalString = arr[0];

        } else if (skillCount <= 5) {
          finalString = arr[0];
          for (i = 1; i < skillCount; i += 1) {
            tempString = doubleSpace + "|" + doubleSpace + arr[i];
            finalString = finalString.concat(tempString);
          }
        } else {
          finalString = arr[0];
          for (i = 1; i < 5; i += 1) {
            tempString = doubleSpace + "|" + doubleSpace + arr[i];
            finalString = finalString.concat(tempString);
          }
          var remainingCount = skillCount - 5;
          var localData = JSON.parse(localStorage.getItem('currentUserDataAttrib'));
          tempString = doubleSpace + "|" + doubleSpace + "<a href=\"#\" " + 'data-skillcount=' + localData.skillcount + " " + 'data-userid=' + localData.userid + " " + 'data-username=' + localData.username + " " + "class=\"manageSkills\"> " + remainingCount + " more</a>";
          finalString = finalString.concat(tempString);
        }
        $('[data-userid=' + localStorage.currentUserID + '].skillsModalLink').html("Manage Skills");
      }
      $currentUserRow.html(finalString);
    },

    recreateRank: function() {
      var _this = this,
        i, $query, template;
      var currentSkillCount = $('.agent-list-wrapper').children().length;
      if ($('.agent-list-wrapper').find('.no-agent-info').length !== 0) {
        _this.addAndUpdateItems = [];
        _this.finalAgentArray = [];
      } else {
        var $rolesAgentList = $(".agent-list-wrapper").find(".roles-agent-list");
        $.each($rolesAgentList, function(i) {
          $query = $(this).data();
          template = { id: $query.rowid, skill_id: $query.skillid, rank: i + 1, rank_handled_in_ui: true };
          _this.addAndUpdateItems.push(template);
          _this.finalAgentArray.push($query.name);
        });
      }
    },

    content: function() {
      var $popup = $("#popup-content");
      var popupContent = $popup.html();
      $popup.remove();
      return popupContent;
    },

    appendContent: function(name, skillcount, cbforInitModal) {
      $("#manage-agents").html(this.content);
      cbforInitModal(name, skillcount);
    },

    initmodal: function(name, skillcount) {
      var params = {
        templateHeader: '<div class="modal-header">' +
          '<p class="ellipsis modal-roles-header"><span id="fDialogHeader"></span></p><span class="muted">' + name + '</span></div>',
        targetId: "#manage-agents",
        title: name ? name : I18n.t('new'),
        width: "400",
        templateFooter: false,
        showClose: true,
        keyboard: true
      };
      $.freshdialog(params);
    },

    innitiateSelect2: function() {
      var _this = this;
      var final_list = _this.getSkillOptions(this.existing_list, this.allSkillsObj);
      var $SelectBox = $('.addAgentHiddenInput');
      $SelectBox.select2('destroy')
        .off('change')
        .select2({
          multiple: true,
          placeholder: "Add Skill",
          allowClear: true,
          data: final_list
        });
      if (!App.exports.is_admin) {$('.addAgentHiddenInput').modal('destroy');}
    },

    getSkillOptions: function(existing_list, all_availble) {
      var id = [];
      var options = [];
      $.each(existing_list, function(i, el) {
        id.push(el.skill_id);
      });

      $.each(JSON.parse(this.allSkillsObj), function(i, el) {
        var obj = {
          id: 0,
          text: el.name,
          skill_id: el.skill_id,
          rank: el.rank
        };

        if ($.inArray(el.skill_id, id) == -1) {
          options.push(obj);
        }
      });
      return options;
    },

    agentTemplate: function(obj) {
      var _this = this;
      var newObj = _.sortBy(obj, 'rank');
      var list = JST["app/admin/skills/templates/add_skill"]({
        data: newObj,
        skillLen: newObj.length
      });
      $("#manage-agents .agent-list-wrapper").append(list);

      if (obj.length == 1) {

        //handling if item was deleted then added
        var flag = _this.deletedItems.filter(function(flag) {
          return flag.skill_id === obj[0].skill_id;
        })[0];
        if (typeof flag != 'undefined') {
          $('[data-skillid= ' + obj[0].skill_id + ']').attr('data-rowid', flag.id);
        }
      }

      $('.addAgentHiddenInput').select2("val", "");
      $('.modal-body').css("max-height", "none");
      _this.customResizeModal();
    },


    customResizeModal: function() {
      var HEIGHT_OF_EACH_ROW = 52;
      var updatedCount = $('.roles-agent-list').length;
      var agentListWrapperHeight = (updatedCount * HEIGHT_OF_EACH_ROW) + "px";
      $('.agent-list-wrapper').height(agentListWrapperHeight);
    },

    removeAgent: function(domobj) {

      var _this = this;
      var skillid = domobj.parents('.roles-agent-list').data('skillid');
      domobj.parents('.roles-agent-list').remove();
      _this.customResizeModal();

      _this.existing_list = _this.existing_list.filter(function(item) {
        return item.skill_id != skillid;
      });

      $('.addAgentHiddenInput').select2('destroy');
      _this.getSkillOptions(_this.existing_list, _this.allSkillsObj);
      _this.innitiateSelect2();
      _this.checkifNoSkills();
    },

    deletedArray: function(domobj) {
      var rowData = domobj.parents('.roles-agent-list').data();
      var template = { "id": rowData.rowid, "_destroy": true, "rank_handled_in_ui": true };
      this.deletedItems.push(template);

    },

    deletedItems: [],
    addAndUpdateItems: [],
    finalAgentArray: [],
    allSkillsObj: {},

    onLeave: function() {
          //flushing modal & select2 so that modal works after user
          //goes to some page and visits back without reloading assets
          $('body').select2('destroy');
          $('#manage-agents').modal('destroy');
      $(document).off(".agentskills");
    },

    checkifNoSkills: function() {
      var TOTAL_SKILLS_PER_AGENT = 35;
      var Template = "<div class='no-agent-info'>" + "No skill added" + "</div>";
      var $agentListWrapper = $(".agent-list-wrapper");
      var len = $agentListWrapper.children('.roles-agent-list').length;
      if (len === 0) {
        $agentListWrapper.html(Template);
        $('#fDialogHeader').text('Add Skill');
      } else {
              if(len >= TOTAL_SKILLS_PER_AGENT)
                {$('.add-agent-box').hide();}
              else
                {$('.add-agent-box').show();}
        $agentListWrapper.find('.no-agent-info').remove();
        $('#fDialogHeader').text('Manage Skill');
      }
    }
  };


}(window.jQuery));
