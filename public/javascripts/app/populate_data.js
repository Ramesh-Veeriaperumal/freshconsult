
/**
 * [ Function to populate data from store on page load, if the page is cached.]
 * @param  {[attr]} { id or a class of selectbox in which the data should be populated	}
 * @return {[data]} { group/agent/product }
 */

var PopulateData = PopulateData || (function(){

	var _GenerateChild = function(array){
		var emptyOption = jQuery('<option>', {val: "", text: "..."});
		var options = jQuery.map(DataStore.get(array).all(), function(value, i){ 
			return jQuery('<option>', { val: value.id, text: value.name }); 
		});
		options.unshift(emptyOption);
		return options;
	}

	var fromStore = function(attr, data){
		jQuery(attr).select2('destroy');
		var options = _GenerateChild(data);
		jQuery(attr).html(options).select2();
	}

	return {
		fromStore: fromStore
	}

})();