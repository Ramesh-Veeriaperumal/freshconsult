/**
 * @author venom
 */

// Condition Parsing 
// This template contains the dom population information 
var conditional_dom = function(filter){
	var type = filter.domtype;
	// Conditional Dom created based on the options available
	c_dom = "";
	switch (type){
		case 'autocompelete':
			c_dom = FactoryUI.autocompelete("url..", "value");
			break;					
		case 'text':
			c_dom = FactoryUI.text("", "value");
			break;
		case 'dropdown':
			var choices = [];
			filter.choices.each(function(arrayItem){
				choices.push({
					name: arrayItem[0],
					value: arrayItem[1]
				});					
			});				 
			c_dom = FactoryUI.dropdown(choices, "value");
			break;
		case 'comment':
			c_dom = jQuery("<span />")
						.append(FactoryUI.paragraph("", "comment"))
				 		.append(FactoryUI.checkbox("Make this a Private Comment", "private"));							
			break;
		case 'paragraph':
			c_dom = FactoryUI.paragraph("", "value");
			break;
		case 'text_dropdown':
			c_dom = FactoryUI.text("", "value");
			break;
		case 'number':
			if(operator && operator == 'between')
				c_dom = jQuery("<span />")
							.append(FactoryUI.text("", "value"))
							.append(FactoryUI.text("", "value"));
			else
				c_dom = FactoryUI.text("", "value");
		default:
			c_dom = "<em>Conditional dom "+type+" Not defined</em>";
	}			
	return c_dom;
}

var preProcessCondition = function(types, list){
	types = $H(types); 
	types.each(function(item){
		var listDrop = $A();
		$A(item.value).each(function(pair){
			var value = {name : pair,  
						 value: list[pair]};
			listDrop.push(value);
		})
		types.set(item.key, listDrop);
	});	
	return types;
};

// Base rule function for managing multiple rule based UI components
// used in Virtual Agents [filters and actions], Senario automation

rules_filter = function(name, filter_data, parentDom, options){
	var setting = {
			init_feed	 : [],
			add_dom		 : ".addchoice",
			rule_dom	 : ".rule_list",
			rem_dom		 : ".delete",
			operators	 : false,
			onRuleSelect : function(){
												
			} 
		};
	if ( options ) { 
        jQuery.extend( setting, options );
     }
	
	// Setting initial data elements	
	var hg_data			= $H(),
		parentDom		= parentDom,
		operator_types	= setting.operators,
		name			= name || "default",
		hidden_			= null;
	// Setting initial dom elements		
		RULE_DOM		= parentDom + " " + setting.rule_dom,
		ADD_DOM			= parentDom + " " + setting.add_dom;
		
	
	// Private Methods
	var domUtil = {
		add_to_hash:
			function(h_data){
				// Hash list for dropdown
				h_data.each(function(option){
					hg_data.set(option.name, option);					
				});							
			},
		getContainer:
			function(name){
				var inner = jQuery("<div class='controls' />");
				var outer = jQuery("<fieldset />")
								.append("<input type=\"hidden\" name=\""+name+"\" value=\"start\" />")
								.append("<span class='sort_handle'></span>")
								.append("<img class=\"delete\" src=\"/images/delete.png\" />")
								.append(inner)											 
								.append("<input type=\"hidden\" name=\""+name+"\" value=\"end\" />");
				jQuery.data(outer, "inner", inner);
				return outer;								
			},
		add_dom: 
			function(){
				// Adding a new Filter DOM element to the Filter Container				
				var r_dom = domUtil.getContainer(name);			
				jQuery.data(r_dom, "inner")
					  .append(FactoryUI.dropdown(filter_data, "name", "ruCls_"+name))
					  .append("<div />");
					 
				list_C = jQuery(parentDom).find(setting.rule_dom);
				r_dom.appendTo(list_C);								
			},
		feed_data:
			function(dataFeed){
				dataFeed.each(function(rule){
					var r_dom 	= domUtil.getContainer(name);			
					var inner 	= jQuery("<div />");
										
					if(rule.operator){	
						opType = hg_data.get(rule.name).operatortype;
						inner.append(FactoryUI.dropdown(operator_types.get(opType), "operator").val(rule.operator));
					}	
					inner.append(conditional_dom(hg_data.get(rule.name)).val(rule.value));
									
					jQuery.data(r_dom, "inner")
						  .append(FactoryUI.dropdown(filter_data, "name", "rule_dropdown").val(rule.name))					  	
						  .append(inner);	
								
					list_C = jQuery(parentDom).find(setting.rule_dom);
					r_dom.appendTo(list_C);
				});				
			},
		
		get_filter_list:
			function(type, c_form){				
			
				var serialArray   = jQuery(c_form).serializeArray(),
					serialHash    = $H(),
					setValue 	  = [],
				    tempConstruct = $H(),
					type		  = type || "object";
					flag		  = false;		
				
				serialArray.each(function(item){					
					if(item.name == name || flag){
						if(!serialHash.get(name)) 
							serialHash.set(name, $A());	
							
						if (item.value == 'start') {
							tempConstruct = $H();
							flag = true;
						}
						else if (item.value == 'end') {
							serialHash.get(name).push(tempConstruct.toObject());
							flag = false;
						}
						else {
							tempConstruct.set(item.name, item.value);
						}			
					}
				});		
				var current_filter = serialHash.get(name);
				save_data = (type != 'json') ? current_filter.toObject() : current_filter.toJSON();
				hidden_.val(save_data);				
				return save_data;			
			},
		init: 
			function(){				
				domUtil.add_to_hash(filter_data);
				console.log(setting.init_feed.size());
				if(setting.init_feed.size())
					domUtil.feed_data(setting.init_feed);
				else
					domUtil.add_dom();	
			}
		};
	
	// Public Methods and Attributes
	var pub_Methods = {		
		add_filter:domUtil.add_new_filter,
		get_filter_list:domUtil.get_filter_list
	};	 
	
	// Applying Events and on Window ready initialization
	jQuery(document).ready(function(){	
		// Init Constructor
		var init = function(){			
			hidden_ = jQuery('<input type="hidden" name="'+name+'_data" value="" />')
							.prependTo(parentDom);	
			
			jQuery(parentDom).find(setting.rule_dom)
							 .sortable({ items: "fieldset", containment: "parent", tolerance: "pointer", handle:"span.sort_handle"});
			
			
			jQuery(parentDom).parents('form:first').submit(function(e){
				domUtil.get_filter_list('json', this);
				//console.log(hidden_.val());
				//return false;
			});
				
			// Binding Events to Containers
			// Filter on change action 
			jQuery(parentDom+' .'+"ruCls_"+name)
				.live("change", 
						function(){ 
							var rule_drop = jQuery(this).next().empty();
															
							if(this.value != 0){
								hg_item = hg_data.get(this.value);
								if(hg_item.operatortype)
								 	rule_drop.append(FactoryUI.dropdown(operator_types.get(hg_item.operatortype), "operator"))
								 
								rule_drop.append(conditional_dom(hg_item));
							}										
						});
						
			jQuery(ADD_DOM)
				.bind("click",
						function(){
							domUtil.add_dom();
						});
						
			// Delete button action
			jQuery(parentDom+' .delete')
				.live("click", 
						function(){
							filter = jQuery(this).parent();
							if(filter.parent().children().size() != 1)
								filter.remove();										
						});
						
			domUtil.init();		
		};
		init();			
	});
	
	return pub_Methods;
}
