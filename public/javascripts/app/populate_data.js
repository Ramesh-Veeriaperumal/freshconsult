
/**
 * [ Function to populate data from store on page load, if the page is cached.]
 * @param  {[attr]} { id or a class of selectbox in which the data should be populated	}
 * @return {[data]} { group/agent/product }
 */

var PopulateData = PopulateData || (function(){
	var I18n_text = {'me': 'Me', 'unassigned':'Unassigned', 'mygroups':'My Groups' }
	var _GenerateChild = function(array){
		var options = jQuery.map(DataStore.get(array).all(), function(value, i){ 
			return jQuery('<option>', { val: value.id, text: value.name }); 
		});
		return options;
	}

	var fromStore = function(attr, data,ticket_group){
		jQuery(attr).select2('destroy');
		var options = _GenerateChild(data), firstOption;
		if(ticket_group){
			firstOption = jQuery('<option>', {val: 0, text: (data == 'group')?I18n_text.mygroups : I18n_text.me});
			options.push(jQuery('<option>', {val: -1, text: I18n_text.unassigned}));
		}
		else{
			firstOption = jQuery('<option>', {val: "", text: "..."});
		}
		options.unshift(firstOption);
		jQuery(attr).html(options).select2();
	}

	return {
		I18n_text: I18n_text,
		fromStore: fromStore
	}

})();