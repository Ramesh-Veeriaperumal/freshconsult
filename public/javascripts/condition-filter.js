/**
 * @author venom
 */

// Condition Parsing 
// This template contains the dom population information 
var conditional_dom = function(filter){
		var type 		= filter.domtype;
		var operator 	= filter.operator || 0;
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

var operator_types  = {"email"       : ["is", "is_not", "contains", "not_contain"],
                       "text"        : ["is", "is_not", "contains", "not_contain", "starts_with", "ends_with"],
                       "choicelist"  : ["is", "is_not"]};

var operator_list  = {"is"				:"Is", 
					  "is_not" 			:"Is not", 
                      "contains"   		:"Contains", 
					  "not_contain"		:"Does not contain",
					  "starts_with"		:"Starts with", 
					  "ends_with"  		:"Ends with",
					  "between"    		:"Between", 
					  "between_range"   :"Between Range"};

rules_filter = function(name, filter_data, parentDom, options){
	var setting = {
			init_feed	 : [],
			add_dom		 : ".addchoice",
			rule_dom	 : ".rule_list",
			operators	 : false,
			onRuleSelect : function(){
												
			} 
		};
	if ( options ) { 
        $.extend( settings, options );
     }
	
	// Setting initial data elements	
	var hg_data		= $H(),
		name		= name || "default",		
	// Setting initial dom elements		
		RULE_DOM	= parentDom + " " + setting.rule_dom,
		ADD_DOM		= parentDom + " " + setting.add_dom;
	
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
				var inner = jQuery("<div />");
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
					  .append(FactoryUI.dropdown(filter_data, "ru_"+name))
					  .append("<div />");
					 
				
				r_dom.appendTo(RULE_DOM);
								
			},
		init: 
			function(){				
				domUtil.add_to_hash(filter_data);
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
			jQuery(parentDom).prepend('<input type="hidden" name="'+name+'" value="" />');			
			domUtil.init();		
		};
		init();			
	});
	
	return pub_Methods;
}

initRuleList = function(filter_list, condition_list, action_list, Dom, add_filter, ActionDom, add_action, c_form, feed_filter, feed_actions){
	
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
		getContainer:
			function(name){
				var inner = jQuery("<div />");
				var outer = jQuery("<fieldset />")
								.append("<input type=\"hidden\" name=\""+name+"\" value=\"start\" />")
								.append("<span class='sort_handle'></span>")
								.append("<img class=\"delete\" src=\"/images/delete.png\" />")
								.append(inner)											 
								.append("<input type=\"hidden\" name=\""+name+"\" value=\"end\" />");
				jQuery.data(outer, "inner", inner);
				return outer;								
			},
		add_new_action: 
			function(){
				// Adding a new Filter DOM element to the Filter Container
				var filter_dom = domUtil.getContainer("actions");			
				jQuery.data(filter_dom, "inner")
					  .append(FactoryUI.dropdown(action_list, "action", "action_dropdown"))
					  .append("<div />");
					 
				filter_dom.appendTo(ActionDom);				
			},
		add_new_filter:
			function(){
				// Adding a new Action DOM element to the Action Container
				var filter_dom = domUtil.getContainer("conditions");			
				jQuery.data(filter_dom, "inner")
					  .append(FactoryUI.dropdown(filter_list, "critera", "rule_dropdown"))
					  .append("<div />");
					 
				filter_dom.appendTo(Dom);				
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
		feed_filters:function(filter_data){
			filter_data.each(function(rule){
				var filter_dom = domUtil.getContainer("conditions");			
				var inner 	   = jQuery("<div />")
								.append(FactoryUI.dropdown(condition_list, "compare").val(rule.compare))
								.append(conditional_dom(filter_hash.get(rule.critera)).val(rule.value));
								
				jQuery.data(filter_dom, "inner")
					  .append(FactoryUI.dropdown(filter_list, "critera", "rule_dropdown").val(rule.critera))					  	
					  .append(inner);	
							
				filter_dom.appendTo(Dom);		
			});
		},
		feed_actions:function(action_data){
			action_data.each(function(rule){
				var action_dom = domUtil.getContainer("actions");			
				var inner 	   = jQuery("<div />")
								.append(conditional_dom(action_hash.get(rule.action)).val(rule.value));
								
				jQuery.data(action_dom, "inner")
					  .append(FactoryUI.dropdown(action_list, "action", "action_dropdown").val(rule.action))			  	
					  .append(inner);	
							
				action_dom.appendTo(ActionDom);		
			});
		},
		init: 
			function(){
				domUtil.convert_to_dom();
				if(!feed_filter.size())
					domUtil.add_new_filter();
				else
					domUtil.feed_filters(feed_filter);
				
				if(!feed_actions.size())
					domUtil.add_new_action();
				else
					domUtil.feed_actions(feed_actions);		
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