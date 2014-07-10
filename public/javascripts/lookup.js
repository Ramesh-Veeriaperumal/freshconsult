window['lookups'] = {
	scenario_execution_search : function(input_value,text_node){
		var i, len, q;
		var value_query = input_value.toLowerCase().split(/\s+/);
		var match = true;
		for (i = 0, len = value_query.length; i < len; i++) {
			q = value_query[i];
			match && (match = text_node.indexOf(q) >= 0);
	  }
		return match;
	}
}