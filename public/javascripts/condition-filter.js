/**
 * @author venom
 */

initRuleList = function(filter_list, condition_list, action_list, Dom, add_filter, ActionDom, add_action, c_form){
	
	// Private JQuery Dom Elements
	var container   	= jQuery("<fieldset />");
	var filter_hash		= $H();
	var condition_hash  = $H();
	var action_hash		= $H();
	
	// Condition Parsing 
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
				c_dom.valid();
				break;
			case 'dropdown':
				c_dom = FactoryUI.dropdown(filter.choices, "value");
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
			default:
				c_dom = "<em>Conditional dom "+type+" Not defined</em>";
		}			
		return c_dom;
	}
												
	// Private Methods
	var domUtil = {
		push_to_hash:
			function(hash, option){
				hash.set(option.name, option);
			},
		convert_to_dom:
			function(){
				// Filter List Dropdown
				filter_list.each(function(rule_option){
					domUtil.push_to_hash(filter_hash, rule_option);					
				});					
				// Condition List Dropdown		
				condition_list.each(function(condition){
					domUtil.push_to_hash(condition_hash, condition);					
				});				
				// Action List Dropdown
				action_list.each(function(action){
					domUtil.push_to_hash(action_hash, action);
				});				
			},			
		add_new_action: 
			function(){
				// Adding a new Filter DOM element to the Filter Container
				jQuery("<fieldset />")
						 .append("<input type=\"hidden\" name=\"actions\" value=\"start\" />")
						 .append("<span class='sort_handle'></span>")
						 .append("<img class=\"delete\" src=\"/images/delete.png\" />")
						 .append(FactoryUI.dropdown(action_list, "action", "action_dropdown"))
						 .append("<div />")						 
						 .append("<input type=\"hidden\" name=\"actions\" value=\"end\" />")
						 .appendTo(ActionDom);				
			},
		add_new_filter:
			function(){
				// Adding a new Action DOM element to the Action Container
				jQuery("<fieldset />")
						 .append("<input type=\"hidden\" name=\"conditions\" value=\"start\" />")
						 .append("<span class='sort_handle'></span>")
						 .append("<img class=\"delete\" src=\"/images/delete.png\" />")
						 .append(FactoryUI.dropdown(filter_list, "critera", "rule_dropdown"))
						 .append("<div />")						 
						 .append("<input type=\"hidden\" name=\"conditions\" value=\"end\" />")
						 .appendTo(Dom);				
			},		
		get_filter_list:
			function(type){				
				var serialArray   = jQuery(c_form).serializeArray(),
					serialHash    = $H(),
					setValue 	  = [],
				    tempConstruct = $H(),
					type		  = type || "object";
				
				serialArray.each(function(item){					
					if(item.name == 'conditions' || item.name == 'actions')
						setValue = item;
						
					switch (setValue.name){
						case 'conditions':
						case 'actions':
							if(!serialHash.get(setValue.name)) 
								serialHash.set(setValue.name, $A());						
						    
							if (item.value == 'start') {
								tempConstruct = $H();
							}								
							if (item.name != setValue.name) {
									tempConstruct.set(item.name, item.value);
							}
							if(item.value == 'end'){
								//tempConstruct.set('va_values', tempValues);						
								serialHash.get(setValue.name).push(tempConstruct.toObject());
							}																
						break;
						default:							
							serialHash.set(item.name, item.value);
						break;
					}					
				});
				returnVar = (type != 'json') ? serialHash.toObject() : serialHash.toJSON();
				return returnVar;			
			},
		init: 
			function(){
				domUtil.convert_to_dom();
				domUtil.add_new_filter();
				domUtil.add_new_action();				
			}
	}	 
	
	// Public Methods and Attributes
	var pub_Methods = {		
		add_filter:domUtil.add_new_filter,
		get_filter_list:domUtil.get_filter_list
	}
	
	// Applying Events and on Window ready initialization
	jQuery(document).ready(function(){	
		// Init Constructor
		var init = function(){
			domUtil.init();	
			
			// Binding Events to Containers
			// Filter on change action
			jQuery(Dom+' .rule_dropdown')
				.live("change", 
						function(){
							var rule_drop = jQuery(this).next().empty();								
							if(this.value != 0){
								 rule_drop.append(FactoryUI.dropdown(condition_list, "compare"))
								 		  .append(conditional_dom(filter_hash.get(this.value)));
							}										
						});
						
			// Action on change action			
			jQuery(ActionDom+' .action_dropdown')
				.live("change",
						function(){
							var action_drop = jQuery(this).next().empty();
							if(this.value != 0){
								action_drop
									//.append("<label> To </lable>")	
									.append(conditional_dom(action_hash.get(this.value)));
							}
						});
			
			// Delete button action
			jQuery(Dom+' .delete, ' + ActionDom+' .delete')
				.live("click", 
						function(){
							filter = jQuery(this).parent();
							if(filter.parent().children().size() != 1)
								filter.remove();										
						});
			
			jQuery(add_filter)
				.bind("click", 
						function(){
							domUtil.add_new_filter();					
						});				
			jQuery(add_action)
				.bind("click", 
						function(){
							domUtil.add_new_action();					
						});
		};
		init();			
	});
	
	return pub_Methods;
 }