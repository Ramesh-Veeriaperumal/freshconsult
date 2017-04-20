/*jslint browser: true, devel: true */
/*global  App:true */
window.App = window.App || {};
window.App.Agents = window.App.Agents || {};

(function($) {
  'use strict';

  App.Agents.Form = {
	onFirstVisit: function(data) {
		this.onVisit(data);
	},

	onVisit: function(data) {
		this.bindHandlers();
	},

	agentSkills: [],
	userName: '',
	roles: {},
	role_details: {},
	groups: {},
	group_details: {},
	repaintSkills: function() {
		return JST["app/admin/agents/templates/reset_skills"]({
			data: this.agentSkills,
			limit: 5
		});
	},
	getCurrentSkills: function(data) {
		App.Admin.AgentSkills.Index.resetManageSkills();
		return data.filter(function(el) {
			return el._destroy == undefined;
		}).map(function(item) {
      return {
				id: item.id,
				skill_id: item.skill_id,
				rank: item.rank,
				name: $(".roles-agent-list[data-skillid = '"+item.skill_id+"'] .agent-details h5").text()
      };
		});
	},
	initializeAgentSkills: function() {
		var _this = this;
		var $doc = $(document);
		$doc.on('click.agentEvents', '[data-action="remove-agent"]', function() {
			$(this).parents('.roles-agent-list').remove();
		});

		$doc.ready(function(){
			_this.agentSkills = App.exports.agent_skills || [];
			$("input[name = 'user[user_skills_attributes]']").val(_this.agentSkills.toJSON());
		});

		$doc.on('click.agentEvents', '[data-action="submitmodal"]', function() {
			var skillParams = App.Admin.AgentSkills.Index.setUpFinalSkills();
			$("input[name = 'user[user_skills_attributes]']").val(skillParams.toJSON());
			_this.agentSkills = _this.getCurrentSkills(skillParams);
      $('.agent_skill_list').html(_this.repaintSkills());
		});

		$doc.on('click.agentEvents', '#add-skill, #view-all-skills', function(){
			var params = {
				templateHeader: '<div class="modal-header">' +
				'<p class="ellipsis modal-roles-header"><span>'+I18n.t('agent.manage_skills')+'</span></p><span class="muted">' + _this.userName + '</span></div>',
				targetId: '#manage-agents',
				title: I18n.t('agent.manage_skills'),
				width: '400',
				templateFooter: false,
				showClose: true,
				keyboard: true
			};
			$("#manage-agents").html($("#popup-content").html());
			$("#popup-content").remove();
			App.Admin.AgentSkills.Index.setUpExistingSkills($.extend([], _this.agentSkills, true));
			$.freshdialog(params);
		});
	},
  bindHandlers: function() {
    this.initializeAgentForm();
		if(App.exports.SkillBasedRRFlag) {
			App.Admin.AgentSkills.Index.bindSkillEvents(true);
			this.initializeAgentSkills();
		}
	},
	initializeAgentForm: function() {
		var $doc = $(document);
		var _this = this;
		$doc.on("click.agent-roles", 'div.icon_remove', function(){
      $('#role_'+$(this).attr('rel')).remove();
      $('.twipsy').remove();
      $("#agent_form").valid();
      _this.roles[$(this).attr('rel')] = false;
		});

		$doc.on("click.agent-roles", '#agent_role ul li input', function(){
		  $(this).parents("li").toggleClass("selected_to_yellow", this.checked);
		});

		$doc.on("click.agent-roles", '#add-role', function(){
		  $("#agent_role ul").children().remove();
		  for(var key in _this.roles){
		    if(!_this.roles[key]){
		      $("#agent_role ul").append(JST["app/admin/agents/templates/item_checkbox"]({
    				type: 'role',
    				key: key,
    				details: _this.role_details[key]
    			}));
		    }
		  }
		});

		$doc.on("click.agent-roles", '#agent-role-container-submit', function() {
			$('#agent_role input:checked').each(function(){
			  var role_id = $(this).attr('rel');
			  _this.roles[role_id] = true;
			  $("#selected-roles ul").append(JST["app/admin/agents/templates/selected_item"]({
					type: 'role',
					key: role_id,
					details: _this.role_details[role_id]
				}));
			});

			$('#agent_role input:unchecked').each(function(){
			  _this.roles[$(this).attr('rel')] = false;
			});

			$("#agent_form").valid();
		});

		$doc.on("click.agent-roles", 'div.group_icon_remove', function(){
		  $('#group_'+$(this).attr('rel')).remove();
		  $('.twipsy').remove();
		  $("#agent_form").valid();
		  _this.groups[$(this).attr('rel')] = false;
		});

		$doc.on("click.agent-roles", '#agent_group ul li input', function(){
		  $(this).parents("li").toggleClass("selected_to_yellow", this.checked);
		});

		$doc.on("click.agent-roles", '#add-group', function(){
		  $("#agent_group ul").children().remove();
		  for(var key in _this.groups){
		    if(!_this.groups[key]){
		      $("#agent_group ul").append(JST["app/admin/agents/templates/item_checkbox"]({
    				type: 'group',
    				key: key,
    				details: _this.group_details[key]
    			}));
		    }
		  }
		});

		$doc.on("click.agent-roles", "#agent-group-container-submit", function(){
			$('#agent_group input:checked').each(function(){
			  var group_id = $(this).attr('rel');
			  _this.groups[group_id] = true;
			  $("#selected-groups ul").append(JST["app/admin/agents/templates/selected_item"]({
					type: 'group',
					key: group_id,
					details: _this.group_details[group_id]
				}));
			});

			$('#agent_group input:unchecked').each(function(){
			  _this.groups[$(this).attr('rel')] = false;
			});

			$("#agent_form").valid();
    });

    $('#agent_form').submit(function(ev) {
      if($("#selected-roles").length > 0 && !$("#selected-roles ul li").length > 0) {
        $('<input>').attr({
          type: 'hidden',
          name: 'user[role_ids][]',
        }).appendTo('#agent_form');
      }

      if($("#selected-groups").length > 0 && !$("#selected-groups ul li").length > 0) {
        $('<input>').attr({
          type: 'hidden',
          name: 'agent[group_ids][]',
        }).appendTo('#agent_form');
      }
		});
	},
	onLeave: function(data) {
		var $doc = $(document);
		$doc.off(".agentskills");
      $doc.off(".agent-roles");
    }
  };

}(window.jQuery));
