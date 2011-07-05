/**
 * @author venom
 */

function postProcessCondition(filter, id){
	if (filter && filter.domtype === 'autocompelete'){
		new bsn.AutoSuggest(id, {
			script: filter.data_url+"?",
			varname: "v",
			json: true,
			maxresults: 10,
			timeout: 3600000, 
			minchars: 1,
			shownoresults: false,
			id_as_value: true,
			cache: false,
			delay:200
		});
		Form.Element.activate(id);
		jQuery("#"+id).trigger("blur");
	}
}

var preProcessCondition = function(types, list){
	types = $H(types);
	types.each(function(item){
		var listDrop = $A();
		$A(item.value).each(function(pair){
			var value = { name : pair, value : list[pair] };
			listDrop.push(value);
		});
		types.set(item.key, listDrop);
	});
	return types;
};

// Base rule function for managing multiple rule based UI components
// used in Virtual Agents [filters and actions], Senario automation

rules_filter = function(_name, filter_data, parentDom, options){
	var setting = {
			init_feed	 : [],
			add_dom		 : ".addchoice",
			rule_dom	 : ".rule_list",
			rem_dom		 : ".delete",
			operators	 : false,
			onRuleSelect : function(){}
		};
	if ( options ) jQuery.extend( setting, options );
	
	// Setting initial data elements	
	var hg_data			= $H(),
		operator_types	= setting.operators,
		name			= _name || "default",
		hidden_			= null,
		// Setting initial dom elements
		RULE_DOM		= parentDom + " " + setting.rule_dom,
		ADD_DOM			= parentDom + " " + setting.add_dom;

	var itemManager = {
		itemNumber:0,
		get:function(){
			return ++itemManager.itemNumber;
		}
	};
	
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
		// Used to Edit pre-population
      feed_data:
         function(dataFeed){
            dataFeed.each(function(rule){
               try{
                  var r_dom	= domUtil.getContainer(name);
                  var inner	= jQuery("<div />");
                  var data_id = rule.name + itemManager.get();

                  if(rule.operator){	
                     opType = hg_data.get(rule.name).operatortype;
                     inner.append(FactoryUI.dropdown(operator_types.get(opType), "operator").val(rule.operator));
                  }	
                  inner.append(conditional_dom(hg_data.get(rule.name), data_id, name, rule));

                  jQuery.data(r_dom, "inner")
                     .append(FactoryUI.dropdown(filter_data, "name", "ruCls_"+name).val(rule.name))
                     .append(inner);	

                  list_C = jQuery(parentDom).find(setting.rule_dom);
                  r_dom.appendTo(list_C);
                  postProcessCondition(hg_data.get(rule.name), data_id);
               }catch(e){}
            });
         },

		get_filter_list:
			function(_type, c_form){
				var serialArray		= jQuery(c_form).serializeArray(),
					serialHash		= $H(),
					setValue		= [],
					tempConstruct	= $H(),
					type			= _type || "object";
					flag			= false;

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
				var save_data	   = [];
				if( ! (current_filter.length == 1 && current_filter[0].name === 0) ) {
					save_data = (type != 'json') ? current_filter.toObject() : current_filter.toJSON();
				}
				hidden_.val(save_data); 
				return save_data;
			},
		init: 
			function(){				
				domUtil.add_to_hash(filter_data);
				//console.log(setting.init_feed.size());
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
	// Init Constructor
	function init(){			 
			hidden_ = jQuery('<input type="hidden" name="'+name+'_data" value="" />')
							.prependTo(parentDom);	

			jQuery(parentDom)
				.find(setting.rule_dom)
				.sortable({ items: "fieldset", containment: "parent", tolerance: "pointer", handle:"span.sort_handle"});

			jQuery(parentDom).parents('form:first').submit(function(e){
				domUtil.get_filter_list('json', this);
				//console.log(hidden_.val());
				//return true;
			});

			jQuery('.l_placeholder').live("click", function(ev){
					active_email_body = jQuery(this).prev();
					jQuery('#place-dialog').slideDown();
			});

			// Binding Events to Containers
			// Filter on change action 
			jQuery(parentDom+' .'+"ruCls_"+name)
				.live("change", 
						function(){ 
							var rule_drop = jQuery(this).next().empty();

							if(this.value !== 0){
								var hg_item = hg_data.get(this.value);
								var data_id = hg_item.name + itemManager.get();

								if(hg_item.operatortype)
									rule_drop.append(FactoryUI.dropdown(operator_types.get(hg_item.operatortype), "operator"));

								rule_drop.append(conditional_dom(hg_item, data_id, name));
								postProcessCondition(hg_item, data_id);
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
		}init();

		return pub_Methods;
	};
