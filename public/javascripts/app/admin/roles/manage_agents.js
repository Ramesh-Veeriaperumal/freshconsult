
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
		});
	}

	function _showModal(id, name, agentcount, isaccadmin){

		// initial set of loading here 
		var agent_url = jQuery("#group_agents_list_url").val() || jQuery("#edit_group_agents_list_url").val();
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
				var admin_role_url = "/admin/roles/users_list";
				_getAgentDetails(id,admin_role_url).success(function(data){
					var constructedData = _constructObject(data, _select2Data);
					if(isaccadmin && jQuery("#is-accadmin").val() === "false"){
						constructedData['admin'] = true;
					}else{
						constructedData['admin'] = false;
					}

					var agentGroupData = JST["app/admin/roles/templates/group_user_list"]({
						data: constructedData
					});
					
					var agentData = JST["app/admin/roles/templates/user_list"]({
						data: constructedData
					});

					_populateSelect2(constructedData.select2data);
					agent_url ? jQuery("#manage-agents .agent-list-wrapper").html(agentGroupData) : jQuery("#manage-agents .agent-list-wrapper").html(agentData);
					jQuery("#manage-agents .agent-list-wrapper").removeClass('sloading');
					Select2Handler.updateCount( constructedData.user.length );
				});
			}
		}else{ // Create new roles
			if(SubmitHandler.data.select2.length === 0){
				var noAgentTemplate = "<div class='no-agent-info'>"+I18n.t('admin.roles.no_agent_added')+"</div>";
				jQuery(".agent-list-wrapper").html(noAgentTemplate);
				var constructedData = _constructNewRoleData()
				_populateSelect2(constructedData.select2data);
				Select2Handler.updateCount( SubmitHandler.data.user.length );
			}else{
				_getDataFromStore();
			}

		}
	}

	function _getDataFromStore(){
		var agent_url = jQuery("#group_agents_list_url").val() || jQuery("#edit_group_agents_list_url").val();
        console.log(agent_url);
		SubmitHandler.data.local = true;
		var localAgent = JST["app/admin/roles/templates/user_list"]({
			data: SubmitHandler.data
		});

		var localGroupAgent = JST["app/admin/roles/templates/group_user_list"]({
			data: SubmitHandler.data
		});

		_populateSelect2(SubmitHandler.data.select2);
		agent_url? jQuery("#manage-agents .agent-list-wrapper").html(localGroupAgent) : jQuery("#manage-agents .agent-list-wrapper").html(localAgent);
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

	function _populateSelect2(data){
		var options = [];
		data.each(function(data, index){
			if(!data.is_account_admin && (data.id !== DataStore.get('current_user').currentData.user.id)){
				options.push(jQuery('<option>').text(data.name).val(data.id));
			}
			
		});
		jQuery('#manage-agents [data-action="add-agent"]').select2('destroy').html("").html(options).select2();
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
				rolesObj[data[len].user_id] =  data[len].role_ids? data[len].role_ids : data[len].group_ids;
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

	function _getAgentDetails(id , admin_role_url){
			// pass the url dynamically depending on whether its coming from roles or groups page
       		var agent_url = jQuery("#group_agents_list_url").val() || jQuery("#edit_group_agents_list_url").val();
       		var url = agent_url? agent_url : admin_role_url;
		return $.ajax({
			url: url,
			type: "GET",
			data: {'id' : id}
		});
	}

	function _initmodal(name, agentcount){
		var titleTemplate = '';
		if(App.namespace === 'admin/roles/index' || App.namespace === 'groups/index'){
			titleTemplate = '<p class="modal-title modal-roles-title muted"></p>'
		}
		var params =  {
			templateHeader	: '<div class="modal-header">' +
								'<p class="ellipsis modal-roles-header"><span>Agents</span> (<span id="roles-count">'+agentcount+'</span>)</p>' +
							titleTemplate+
							'</div>',
			targetId		: "#manage-agents",
			title			: name ? name : I18n.t('admin.roles.new'),
			width			: "400",
			templateFooter 	: false,
			showClose		: true,
			keyboard		: true

		}

		 $.freshdialog(params);
	}

})(jQuery);
