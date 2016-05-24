
/**
 * SubmitHandler - Updated roles data will be send to backend from this Factory function
 */

var SubmitHandler = SubmitHandler || (function(){
	var submitObj = {};

	submitObj.changes = {
		added_agent: [],
		removed_agent: []
	}

	submitObj.data = {
		user: [],
		roles: [],
		select2: []
	}

	// NOTE - it is need to expose outside ??
	submitObj.syncData = function(modifiedData){
		var updatedSelect2 = _syncSelect2(modifiedData);
		var updatedUser = _syncUser(modifiedData);
		submitObj.data.user = updatedUser;
		submitObj.data.select2 = updatedSelect2;
	}

	submitObj.resetData = function(){
		submitObj.data = {
			user: [],
			roles: [],
			select2: []
		}
	}

	submitObj.resetChanges = function(){
		submitObj.changes = {
			added_agent: [],
			removed_agent: []
		}
	}

	submitObj.triggerSave = function(){
		var text = jQuery('[data-action="submitmodal"]').data().loading;
		jQuery('[data-action="submitmodal"]').text(text).addClass('disabled');
	}

	/**
	 * [Final submit handler for modifying roles data in the db]
	 * @param  {[Object]}   modifiedData [Added and Removed agents in the select2]
	 * @param  {[Integer]}   roleid      [Role ID]
	 * @param  {Integer} cb           	 [Decides form submit(1) or ajax submit(0) ]
	 * @param  {[string]}   label 		 [Label handler input]
	 * @return {[void]}
	 */

	submitObj.modifyAndSubmit = function(modifiedData, roleid, cb, label){

		submitObj.syncData(modifiedData);

		var checkModified = {
			added_agent: submitObj.changes.added_agent.concat(modifiedData.added_agent),
			removed_agent : submitObj.changes.removed_agent.concat(modifiedData.removed_agent)
		}

		var submitVal = _checkCurrentModified(checkModified);

		submitObj.changes = {
			added_agent: submitVal.added_agent,
			removed_agent : submitVal.removed_agent
		}

		var callFunction = [ajaxSubmit, formSubmit];
		callFunction[cb](submitObj.changes, roleid, label);
	}

	return submitObj; // Public exposed functions

	// PRIVATE

	function _checkCurrentModified(data){
		// Check both and remove dulicate from both array
		var _added = data.added_agent.length === 0 ? [] : data.added_agent.slice(),
			_removed = data.removed_agent.length === 0 ? [] : data.removed_agent.slice();

		var added = _added.filter(function(val, i){
			return (data.removed_agent.indexOf(val) === -1);
		});

		var removed = _removed.filter(function(val, i){
			return ( data.added_agent.indexOf(val) === -1);
		});

		return {
			added_agent: added,
			removed_agent: removed
		}
	}

	function _syncUser(data){
		var index;
		data.removed_agent.each(function(val,i){
			index = submitObj.data.user.indexOf(val);
			if(index !== -1){
				submitObj.data.user.splice(index, 1);
			}
		});
		return submitObj.data.user.concat(data.added_agent);
	}

	function _syncSelect2(data){

		var select2Keys = submitObj.data.select2.pluck('id'),
		result = submitObj.data.select2.filter(function(val) {
			return data.added_agent.indexOf(String(val.id)) === -1;
		});

		submitObj.data.select2 = result;

		// Add removed agent into select2 here with name
		var removedAgentArr = [], instanceObj;
		data.removed_agent.each(function(data, index){
			instanceObj = {id: data, name: DataStore.get('agent').findById(parseInt(data)).name}
			removedAgentArr.push(instanceObj);
		});
		return submitObj.data.select2.concat(removedAgentArr);
	}

	function ajaxSubmit(data, id, label){
		jQuery.ajax({
			url: "/admin/roles/update_agents",
			type: "POST",
			data: { add_user_ids: data.added_agent, delete_user_ids: data.removed_agent, id: id }
		}).success(function(result){
			if(result.status){
				var updatedCount = jQuery("#manage-agents .agent-list-wrapper").children('.roles-agent-list').length;
				jQuery("#manage-agents").modal('hide');
				SubmitHandler.resetChanges();
				window['LabelHandler'][label](id, updatedCount);
			}
		}).error(function(err){
			// NOTE - ERROR handling should be done here
			console.log(err);
		});
	}

	function formSubmit(data){
		jQuery("#add_user_ids").val('').val(uniqueArray(data.added_agent));
		jQuery("#delete_user_ids").val('').val(uniqueArray(data.removed_agent));
	}

})();

/******************************************* End of Submit handler **************************************/

/**
 * Select2Handler - Adding and removing data in the agent list
 * 					Enabling and disabling submit button.
 */

var Select2Handler = Select2Handler || (function(){
	var selectObj = {};

	selectObj.agent = {
		added_agent: [],
		removed_agent: [],
		updated_count: null
	}

	selectObj.resetData = function(){
		selectObj.agent = {
			added_agent: [],
			removed_agent: [],
			updated_count: null
		}
	}

	selectObj.init = function(){
		_bindEvents();
	}

	selectObj.updateCount = function(count){
		_updateRolesCount(count);
	}

	return selectObj; //Public exposed function

	// PRIVATE

	function _bindEvents(){
		jQuery(document).on('change', '[data-action="add-agent"]', function(){
			var _id = jQuery(this).val();
			if(_id){
				jQuery('#manage-agents select.agent-select-list').val('');
				_addAgent(_id[0]);
			}
			_enableButton();
		});

		jQuery(document).on('click', '[data-action="remove-agent"]', function(){
			var _this = jQuery(this);
			_removeAgent(_this);
			_enableButton();
		});
	}

	function _addAgent(id){
		var profileImage = ProfileImage.imageById(parseInt(id)).profile_img;
			name = DataStore.get('agent').findById(parseInt(id, 10)).name;
		jQuery('#manage-agents div.agent-select-list .select2-search-choice').remove();
		jQuery("#manage-agents .agent-select-list option[value='"+id+"']").remove();
		var defaultAdded = _isModifiedNow(id, 'removed');
		_constructTemplate({profileImage: profileImage, name: name, id: id});
		if(!defaultAdded){
			selectObj.agent.added_agent.push(id);
		}
		_updateRolesCount('', 'added');
		_checkNoAgent();
		return;
	}

	function _removeAgent($domobj){
		var _id = $domobj.parents('.roles-agent-list').attr('id');
		$domobj.parents('.roles-agent-list').remove();
		var name = DataStore.get('agent').findById(parseInt(_id, 10)).name;
		var option = jQuery('<option />').text(name).val(_id);
		jQuery('select.agent-select-list').prepend(option);
		var currentAdded = _isModifiedNow(_id, 'added');
		if(!currentAdded){
			selectObj.agent.removed_agent.push(_id);
		}
		_updateRolesCount('', 'removed');
		_checkNoAgent();
		return;
	}

	function _updateRolesCount(count, action){
		if(!action){
			jQuery('#roles-count').html(count);
		}else{
			var savedCount = parseInt(jQuery('#roles-count').text());
			var updatedCount = (action === 'added') ? (savedCount + 1) : (savedCount - 1);
			jQuery('#roles-count').html(updatedCount);
		}
	}

	function _checkNoAgent(){
		var noAgentTemplate = "<div class='no-agent-info'>"+I18n.t('admin.roles.no_agent_added')+"</div>";
		var len = jQuery(".agent-list-wrapper").children('.roles-agent-list').length;
		if(len === 0){
			jQuery(".agent-list-wrapper").html(noAgentTemplate);
		}else{
			jQuery(".agent-list-wrapper").find('.no-agent-info').remove();
		}
	}

	function _enableButton(){
		if(Select2Handler.agent.added_agent.length !== 0 || Select2Handler.agent.removed_agent.length !== 0
			|| SubmitHandler.changes.added_agent.length !== 0 || SubmitHandler.changes.removed_agent.length !== 0){
			jQuery('#manage-agents [data-action="submitmodal"]').removeClass('disabled');
		}else{
			jQuery('#manage-agents [data-action="submitmodal"]').addClass('disabled');
		}
	}

	function _constructTemplate(obj){
		var list = JST["app/admin/roles/templates/user"]({
			data: obj
		});
		jQuery("#manage-agents .agent-list-wrapper").prepend(list);
	}

	function _isModifiedNow(id, action){
		var submitDataIndex = SubmitHandler.changes[action+'_agent'].indexOf(id);
		var select2Index = selectObj.agent[action+'_agent'].indexOf(id);
		if(select2Index === -1){
			return false;
		}else{
			selectObj.agent[action+'_agent'].splice(select2Index,1);
			return true;
		}
	}

})();

/******************************************* End of Select2 handler **************************************/

/**
 * Labelhandler - Factory function which decides the label of Agents in across create, edit and index.
 */

var LabelHandler = LabelHandler || (function(){
	var labelObj = {};

	labelObj.index = function(id, updatedCount){
		// var label = (updatedCount > 1) ? " Agents" : " Agent";
		// var count = (updatedCount === 0) ? "No" : updatedCount;
		// jQuery("[data-changecount='"+id+"']").html(count + label);
		var label = {};
			label['id'] = id;
			label['title'] = jQuery("[data-changecount='"+id+"']").data().title;
			label['count'] = updatedCount;
			labelContent = JST["app/admin/roles/templates/no_agent"]({
				data: label
			});

		jQuery("[data-changecount='"+id+"']").parents('.manage-agent').html(labelContent);
	}

	labelObj.default = function(id, updatedCount){
		var label = (updatedCount > 1) ? I18n.t('admin.roles.agents_label') : I18n.t('admin.roles.agent_label');
		var labelInfo = (updatedCount === 0) ? I18n.t('admin.roles.add_label') : I18n.t('admin.roles.manage_label');
		var count = (updatedCount === 0) ? "No": updatedCount;
		jQuery('.label-info-text').html(labelInfo);
		jQuery("[data-changecount]").html(count +" "+ label);
	}

	return labelObj;
})();

/******************************************* End of Label handler **************************************/


/**
 * Singleton for Roles index page
 */

var AdminRoles = AdminRoles || {};

AdminRoles.index = AdminRoles.index || {
	init: function(){
		ManageAgents.init();
		Select2Handler.init();
		this.bindEvents();
	},

	bindEvents: function(){

		// Destroy if in index page to sync with data
		jQuery(document).on("hidden", '#manage-agents', function(){
			jQuery("#manage-agents").modal('destroy');
			jQuery("#manage-agents").html("");
			Select2Handler.resetData();
			SubmitHandler.resetData();
		});

		jQuery(document).on('click', '[data-action="cancelmodal"]', function(){
			jQuery("#manage-agents").modal('hide');
		});

		jQuery(document).on('click', '[data-action="submitmodal"]', function(){
			var roleid = jQuery("#roleid").val();
			SubmitHandler.triggerSave();
			SubmitHandler.modifyAndSubmit(Select2Handler.agent, roleid, 0, 'index');
		});
	}
}

/******************************************* End of index page  **************************************/


/**
 * Singleton for Roles edit page
 */

AdminRoles.edit = AdminRoles.edit || {
	init: function(){
		ManageAgents.init();
		Select2Handler.init();
		this.bindEvents();
	},

	bindEvents: function(){
		var checkDefault = jQuery("#edit-info").data().isdefault;
		if(checkDefault){
			this.defaultRole();
		}else{
			this.customRole();
		}
	},

	defaultRole: function(){
		jQuery(document).on("hidden", '#manage-agents', function(){
			jQuery("#manage-agents").modal('destroy');
			jQuery("#manage-agents").html("");
			Select2Handler.resetData();
			SubmitHandler.resetData();
		});

		jQuery(document).on('click', '[data-action="cancelmodal"]', function(){
			jQuery("#manage-agents").modal('hide');
		});

		jQuery(document).on('click', '[data-action="submitmodal"]', function(){
			var roleid = jQuery("#roleid").val();
			SubmitHandler.triggerSave();
			UpdateAgentCount();
			SubmitHandler.modifyAndSubmit(Select2Handler.agent, roleid, 0, 'default');
		});
	},

	customRole: function(){
		jQuery(document).on("hidden", '#manage-agents', function(){
			jQuery("#manage-agents").modal('destroy');
			jQuery("#manage-agents").html("");
			Select2Handler.resetData();
		});
		jQuery(document).on('click', '[data-action="cancelmodal"]', function(){
			jQuery("#manage-agents").modal('hide');
		});

		jQuery(document).on('click', '[data-action="submitmodal"]', function(){
			var roleid = jQuery("#roleid").val();
			SubmitHandler.modifyAndSubmit(Select2Handler.agent, roleid, 1, 'index');
			var updatedCount = jQuery("#manage-agents .agent-list-wrapper").children('.roles-agent-list').length;
			LabelHandler.default(roleid, updatedCount);
			UpdateAgentCount();
			jQuery("#manage-agents").modal('hide');
		});
	}
}

/******************************************* End of roles edit **************************************/


/**
 * Singleton for Roles new page
 */

AdminRoles.new = AdminRoles.new || {
	init: function(){
		ManageAgents.init();
		Select2Handler.init();
		this.bindEvents();
	},

	bindEvents: function(){
		jQuery(document).on("hidden", '#manage-agents', function(){
			jQuery("#manage-agents").modal('destroy');
			jQuery("#manage-agents").html("");
			Select2Handler.resetData();
		});
		jQuery(document).on('click', '[data-action="cancelmodal"]', function(){
			jQuery("#manage-agents").modal('hide');
		});

		jQuery(document).on('click', '[data-action="submitmodal"]', function(){
			SubmitHandler.modifyAndSubmit(Select2Handler.agent, '', 1, 'new');
			var roleid = jQuery("#roleid").val();
			var updatedCount = jQuery("#manage-agents .agent-list-wrapper").children('.roles-agent-list').length;
			LabelHandler.default(roleid, updatedCount);
			UpdateAgentCount();
			jQuery("#manage-agents").modal('hide');
		});
	}
}

// Update count for maitaining state
function UpdateAgentCount(){
	var latestCount = jQuery("#roles-count").text();
	jQuery('.popup').data('agentcount', latestCount);
}
