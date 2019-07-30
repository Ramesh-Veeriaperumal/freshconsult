
/**
 *
 * Manage Agent - Factory function to init popup and data
 * 				  construction for select2 box and agent list
 */

var ManageAgents = ManageAgents || (function($){

	var ACCOUNT_ADMIN_TITLE = "Account Administrator",
			agentObj = {};

	agentObj.init = function(){
		_bindEvents();
	}

	return agentObj;

	// PRIVATE

	function _bindEvents(){
		$(document).on('click', 'a.popup', function(){
			var data = $(this).data();
			$("#roleid").val(data.roleid);
			_showModal(data.roleid, data.title, data.agentcount, data.isaccadmin);
			$('.select2-input').focus();
			jQuery('.modal-body').css("max-height", "none");
			elasticSearchAgents();
		});
	}

	function _showModal(id, name, agentcount, isaccadmin){

		// initial set of loading here 
		_appendContent(name, agentcount, _initmodal);
		_resetPopup();
		var $agentSelectBox = jQuery('#manage-agents-content .add-agent-box, #manage-agents-content .button-container');
		if(isaccadmin && jQuery("#is-accadmin").val() === "false"){
			$agentSelectBox.hide();
		}else{
			$agentSelectBox.show();
		}
		if(id){ // Roles already created
			jQuery("#manage-agents .agent-list-wrapper").addClass('sloading');
			if(SubmitHandler.data.user.length !== 0 || SubmitHandler.data.select2.length !== 0){
				_getDataFromStore();
				jQuery("#manage-agents .agent-list-wrapper").removeClass('sloading');
			}else{
				_getAgentDetails(id).success(function(data){
					var constructedData = _constructObject(data, _select2Data);
					if(isaccadmin && jQuery("#is-accadmin").val() === "false"){
						constructedData['admin'] = true;
					}else{
						constructedData['admin'] = false;
					}
					var agentData = JST["app/admin/roles/templates/user_list"]({
						data: constructedData
					});
					jQuery("#manage-agents .agent-list-wrapper").html(agentData);
					jQuery("#manage-agents .agent-list-wrapper").removeClass('sloading');
					Select2Handler.updateCount( constructedData.user.length );
				});
			}
		}else{ // Create new roles
			if(SubmitHandler.data.select2.length === 0){
				var noAgentTemplate = "<div class='no-agent-info'>"+I18n.t('admin.roles.no_agent_added')+"</div>";
				jQuery(".agent-list-wrapper").html(noAgentTemplate);
				var constructedData = _constructNewRoleData()
				Select2Handler.updateCount( SubmitHandler.data.user.length );
			}else{
				_getDataFromStore();
			}

		}
	}

	function _getDataFromStore(){
		SubmitHandler.data.local = true;
		var localAgent = JST["app/admin/roles/templates/user_list"]({
			data: SubmitHandler.data
		});
		jQuery("#manage-agents .agent-list-wrapper").html(localAgent);
		Select2Handler.updateCount( SubmitHandler.data.user.length );
	}

	// Get all agents incase of create new roles :)
	function _allAgents(){
		var options = DataStore.get('agent').all().map(function(data, index){
			return jQuery('<option>').text(data.name).val(data.id);
		})
		return options;
	}

	function _resetPopup(){
		var data = jQuery('[data-action="submitmodal"]').data();
		jQuery("#manage-agents .agent-list-wrapper").find('.no-agent-info').remove();
		jQuery('[data-action="submitmodal"]').text(data.label);
	}

	function _constructNewRoleData(cb){
		SubmitHandler.data = {
			user: [],
			roles: [],
			select2: DataStore.get('agent').all()
		}
		return {
			user: [],
			roles: [],
			select2data: DataStore.get('agent').all()
		}
	}

	function elasticSearchAgents(){
		$('#manage-agents input.addAgentHiddenInput').select2('destroy');
		$('#manage-agents .addAgentHiddenInput').select2({
			minimumInputLength: 2,
			multiple: true,
			placeholder: I18n.t('common_js_translations.skills.add_agent'),
			allowClear: true,
			ajax: {
				url: '/search/autocomplete/agents',
				dataType: 'json',
				delay: 250,
				data: function(term, page) {
					return {
						q: term
					};
				},
				results: function(data, params) {
					var filteredData = {
						results: []
					}
					var selectedAgents = Select2Handler.agent.added_agent.concat(SubmitHandler.data.user).filter(function(agent, index){
						return Select2Handler.agent.removed_agent.indexOf(agent) == -1;
					});
					var currentUserId = DataStore.get('current_user').currentData.user.id;
					var accountAdmins = DataStore.get('agent').all().filter(function(agent){ return agent.is_account_admin }).pluck('id').map(function(id){ return String(id); });
					var filteredAgents = selectedAgents.concat(accountAdmins, [String(currentUserId)]);
					$.each(data.results, function(index, item) {
						if ( filteredAgents.indexOf(String(item.user_id)) == -1 ) {
							filteredData.results.push({
								id: item.user_id,
								text: item.value,
								profile_img: item.profile_img
							});
						}
					});
					return filteredData;
				},
				cache: true
			}
		});
	}

	function _appendContent(name, agentcount, cb){
		var content = jQuery("#popup-content").html();
		jQuery("#manage-agents").html(content);
		jQuery('#manage-agents [data-action="add-agent"]').select2();
		cb(name, agentcount);
	}

	function _select2Data(userArray){
		var select2data = DataStore.get('agent').all().filter(function(val, index) {
			return userArray.indexOf(String(val.id)) == -1;
		});
		return select2data;
	}

	function _constructObject(data, cb){
		var len = data.length;
		var rolesObj = {};
		var users_temp = [];
		while(len--) {
			if(data[len].user_id){
				rolesObj[data[len].user_id] =  data[len].role_ids;
				users_temp.push(data[len].user_id + '');
			}
		}
		var users = users_temp.reverse();
		var select2data = cb(users);
		SubmitHandler.data = {
			user: users,
			roles: rolesObj,
			select2: select2data
		}

		return {
			user: users,
			roles: rolesObj,
			select2data: select2data
		}
	}

	// NOTE - Remove since data schema changed
	function constructObject(data, cb){
		var roleObj = {};
		var len = data.length;
		while(len--) {
			var sHash = data[len].user.toString();
			if (typeof(roleObj[sHash]) == "undefined")
			roleObj[sHash] = [];
			roleObj[sHash].push(data[len].role);
		}
		var users = Object.keys(roleObj);
		var select2data = cb(users);

		return {
			user: users,
			roles: roleObj,
			select2: select2data
		}
	}

	function _populateData(agentData, cb){
		$("#manage-agents").html(agentData);
		cb();
	}

	function _getAgentDetails(id){
		return $.ajax({
			url: "/admin/roles/users_list",
			type: "GET",
			data: {'id' : id}
		});
	}

	function _initmodal(name, agentcount){
		var titleTemplate = '';
		if(App.namespace === 'admin/roles/index'){
			titleTemplate = '<p class="modal-title modal-roles-title muted"></p>'
		}
		var params =  {
			templateHeader	: '<div class="modal-header">' +
								'<p class="ellipsis modal-roles-header"><span>Agents</span> (<span id="roles-count">'+agentcount+'</span>)</p>' +
							titleTemplate+
							'</div>',
			targetId		: "#manage-agents",
			title			: name ? escapeHtml(name) : I18n.t('admin.roles.new'),
			width			: "400",
			templateFooter 	: false,
			showClose		: true,
			keyboard		: true

		}

		 $.freshdialog(params);
	}

})(jQuery);
