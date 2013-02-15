/**
 * @author venom
 */

var _from, _to, _updated, _confirm_message, _any_present;
var from_to = { from : 'to', to : 'from' }

var set_observer_keywords = function(from, to, updated, confirm_message){
	_from = from;
	_to = to;
	_updated = updated;
	_confirm_message = confirm_message;
};

var ensure_performed_by = function(){ 
	var element = jQuery(this);
	// Couldn't get the last added element in chozen.. Hence used _any_present
	if(element.val() == null)
	{
		element.val(" ").trigger("liszt:updated");
		_any_present = true;
	}	
	else if (_any_present)
	{
		element.val(element.val().splice(1,1)).trigger("liszt:updated");
		_any_present = false;
	}
	else if (element.val().first() == " " && element.val().length > 1)
	{
		if (confirm(_confirm_message))
		{			
			element.val(" ").trigger("liszt:updated");
			_any_present = true;
		}
		else 
		{
			value = element.val();
			value.splice(0,1);
			element.val(value).trigger("liszt:updated");
			_any_present = false;
		}	
	}
};

var disableOtherSelectValue = function(){
	selection = jQuery(this).val();
	target = from_to[jQuery(this).prop('name')];
	// Enable all options for the nearby select
	jQuery(this).siblings('select[name="'+target+'"]').find('option').each( function(){
		jQuery(this).prop('disabled', false);
	});
	// Disable the only option
	if (selection != ' ')
	{ jQuery(this).siblings('select[name="'+target+'"]').find('option[value="'+selection+'"]').prop('disabled',true); }
	return this;
}

var hideEmptySelectBoxes = function(){
	if (this.options.length == 1 && this.options[0].value == " ")
	{	jQuery(this).prev().css('display','none');
		jQuery(this).css('display','none');	}
	else
	{	jQuery(this).prev().css('display','block');
		jQuery(this).css('display','block');	}
	return this;
}

var performed_by_change = function(){ 
	if ( jQuery( this ).val() == "agent")
 	  // { jQuery("#va_rule_performed_by_chzn, #va_rule_performed_by_chzn > ul ").slideDown('slow'); }
 	  	{ 
 	  		jQuery("#va_rule_performed_by_chzn > ul").slideDown('slow');
 	  		jQuery("#va_rule_performed_by_chzn, #va_rule_performed_by_chzn > ul ").slideDown('fast'); }
 	else
	  { 
	  	jQuery("#va_rule_performed_by_chzn, #va_rule_performed_by_chzn > ul ").slideUp('fast'); 
			jQuery("#va_rule_performed_by_chzn ").slideUp('slow'); 
			// jQuery("#va_rule_performed_by_chzn > ul").fadeOut('slow'); 
		}
};

var selectPerformedBy = function(){
	if ( jQuery( 'input[name="va_rule[performed_by]"]:checked' ).val() == null )
		jQuery( 'input[name="va_rule[performed_by]"][value = "agent"]' ).attr("checked","checked");
	performed_by_change.call(jQuery( 'input[name="va_rule[performed_by]"]:checked' ));
	ensure_performed_by.call(jQuery( '#va_rule_performed_by' ));
};

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
};


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
			init_feed	       : [],
			add_dom		       : ".addchoice",
			rule_dom	       : ".rule_list",
			rem_dom		       : ".delete",
			operators	       : false,
			delete_last        : false,
			selectListArr      : [],
			empty_dom 	 	   : ".empty_choice",
			onRuleSelect       : function(){},
			change_filter_data : function(_filter_data){return _filter_data}
		};
	if ( options ) jQuery.extend( setting, options );

	// Setting initial data elements	
	var hg_data			= $H(),
		operator_types	= setting.operators,
		//quest_criteria_types = setting.quest_criteria_types;
		name			= _name || "default",
		hidden_			= null,
		// Setting initial dom elements
		RULE_DOM	   	= parentDom + " " + setting.rule_dom,
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
				if(setting.delete_last){
					h_data = h_data[0]['ticket'].concat(h_data[0]['forum'],h_data[0]['solution']);
				}
				h_data.each(function(option){
					hg_data.set(option.name, option);
				});
			},
		getContainer:
			function(name){
				var inner = jQuery("<div class='controls' />");
				var outer = jQuery("<fieldset />")
								.append("<input type=\"hidden\" name=\""+name+"\" value=\"start\" />")
								.append("<img class=\"delete\" src=\"/images/delete.png\" />")
								.append("<span class='sort_handle'></span>")
								.append(inner)
								.append("<input type=\"hidden\" name=\""+name+"\" value=\"end\" />");
				jQuery.data(outer, "inner", inner);
				return outer;
			},
		dom_size: 0,
		add_dom: 
			function(){
				// Adding a new Filter DOM element to the Filter Container
				var r_dom = domUtil.getContainer(name);
				var filterList = [];
				if(setting.delete_last) {
					var selected_quest = jQuery("input[name=quest[category]]:checked").val();
					//var criteria_list = quest_criteria_types[selected_quest];
					filterList = setting.change_filter_data(filter_data[0][setting.selectListArr[selected_quest]]);
				} else {
					filterList = filter_data;
				}

				jQuery.data(r_dom, "inner")
					  .append(FactoryUI.dropdown(filterList, "name", "ruCls_"+name))
					  .append("<div />");

				list_C = jQuery(parentDom).find(setting.rule_dom);
				r_dom.appendTo(list_C);

				this.dom_size++;
				this.populateEmpty();
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
                  	try{
                     	opType = hg_data.get(rule.name).operatortype;
                     	inner.append(FactoryUI.dropdown(operator_types.get(opType), "operator").val(rule.operator));
                    }catch(e){}
                  }	
                  if(rule.name == "set_nested_fields")
                  {
                  	rule.name = rule.category_name;
                  }

                  if( name == "event"){
	                  switch (hg_data.get(rule.name).type)
	                  {
	                	case 0:
	              			inner.append(FactoryUI.label(hg_data.get(rule.name).postlabel, 'rule_label'));
	                  	break;
	                 	case 1:
	                  	inner.append(FactoryUI.label(hg_data.get(rule.name).postlabel, 'rule_label')).append(conditional_dom(hg_data.get(rule.name), data_id, name, "value", rule));
	                  	break;
	                  case 2:
	                  	hg_data.get(rule.name).postlabel = _updated;
	                  	from_select = conditional_dom(hg_data.get(rule.name), data_id, name, "from", rule);
	                  	to_select = conditional_dom(hg_data.get(rule.name), data_id, name, "to", rule);
		                  from_select.find('option[value="'+to_select.val()+'"]').prop('disabled',true);
		                  to_select.find('option[value="'+from_select.val()+'"]').prop('disabled',true);
	                  	inner.append(FactoryUI.label(hg_data.get(rule.name).postlabel, 'rule_label')).append(FactoryUI.label(_from, 'rule_label')).append(from_select).append(FactoryUI.label(_to, 'rule_label')).append(to_select);
	                  	if (rule.nested_rule)
		                  {
		                  	hideEmptySelectBoxes.apply(from_select.find('select')[1]);
		                  	hideEmptySelectBoxes.apply(from_select.find('select')[2]);
		                  	hideEmptySelectBoxes.apply(to_select.find('select')[1]);
		                  	hideEmptySelectBoxes.apply(to_select.find('select')[2]);
		                  }
		                  break;
	                 	}
                	}else{
                  	inner.append(conditional_dom(hg_data.get(rule.name), data_id, name, "value", rule));
                	}

					var filterList = [];
					if(setting.delete_last) {
						var selected_quest = jQuery("input[name=quest[category]]:checked").val();
						//var criteria_list = quest_criteria_types[selected_quest];
						filterList = setting.change_filter_data(filter_data[0][setting.selectListArr[selected_quest]]);
					} else {
						filterList = filter_data;
					}

                  jQuery.data(r_dom, "inner")
                     .append(FactoryUI.dropdown(filterList, "name", "ruCls_"+name).val(rule.name))
                     .append(inner);	

                  list_C = jQuery(parentDom).find(setting.rule_dom);
                  r_dom.appendTo(list_C);
                  postProcessCondition(hg_data.get(rule.name), data_id);
             }catch(e){}
            });
			this.dom_size = dataFeed.size()+1;
         },

        populateEmpty: 
        	function(){
				jQuery(parentDom).find(setting.empty_dom).toggle(this.dom_size <= 1);
		},

		refresh_list:
			function(){
				jQuery(parentDom).find(setting.rule_dom).empty();
				hidden_.val("");
				this.dom_size = 1;
		},

		get_filter_list:
			function(_type, c_form){
				var serialArray	= jQuery(c_form).serializeArray(),
					serialHash		= $H(),
				 	setValue		= [],
				    tempConstruct	= $H(),
					type			   = _type || "object";
				  	flag			   = false;

				serialArray.each(function(item){				   
					if(item.name == name || flag){
						if(!serialHash.get(name)) 
							serialHash.set(name, $A());	
							
						if (item.value == 'start') {
							tempConstruct = $H();
							flag = true;
						}
						else if (item.value == 'end') {
						   if(tempConstruct.size())
							   serialHash.get(name).push(tempConstruct.toObject());

							flag = false;
						}
						else if(item.value != -1) { 
							tempConstruct.set(item.name, item.value);
						}
					}
				});
				var current_filter = [],
				    save_data	    = [];
				
				current_filter = serialHash.get(name);

				if( current_filter && current_filter.length != 0 )
					save_data = (type != 'json') ? current_filter.toObject() : current_filter.toJSON();

				hidden_.val(save_data);

				this.populateEmpty && this.populateEmpty();

				return save_data;
			},
		init: 
			function(){
				domUtil.add_to_hash(filter_data);
				if(setting.init_feed.size())
					domUtil.feed_data(setting.init_feed);
				else
					domUtil.add_dom();	
					
				this.populateEmpty();
			}
		};
	
	// Public Methods and Attributes
	var pub_Methods = {		
		add_filter:domUtil.add_new_filter,
		get_filter_list:domUtil.get_filter_list,
		get_size: (domUtil.dom_size - 1),
		refresh_list: domUtil.refresh_list
	};	 
	
	// Applying Events, filters and actions on Window ready initialization	
	// Init Constructor
	function init(){			 
			hidden_ = jQuery('<input type="hidden" name="'+name+'_data' +'" value="" />')
							.prependTo(parentDom);	

			jQuery(parentDom)
				.find(setting.rule_dom)
				.sortable({ items: "fieldset", containment: "parent", tolerance: "pointer", handle:"span.sort_handle"});

			jQuery(parentDom).parents('form:first').submit(function(e){
			  domUtil.get_filter_list('json', this);	
			   // return false;
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

							if(this.value !== -1){
								var hg_item = hg_data.get(this.value);
								var data_id = hg_item.name + itemManager.get();

								if(hg_item.operatortype) {
									rule_drop.append(FactoryUI.dropdown(operator_types.get(hg_item.operatortype), "operator"));
								}

								if( name == "event"){
									var entity_label = $H({domtype: "label", label: hg_item.postlabel})
                  switch (hg_item.type)
                  {
                	case 0:
              			rule_drop.append(FactoryUI.label(hg_item.postlabel, 'rule_label'));
                  	break;
                 	case 1:
                  	rule_drop.append(FactoryUI.label(hg_item.postlabel, 'rule_label')).append(conditional_dom(hg_item, data_id, name, "value"));
                  	break;
                  case 2:
                  	hg_item.postlabel = _updated;
                  	from_select = conditional_dom(hg_item, data_id, name, "from");
                  	to_select = conditional_dom(hg_item, data_id, name, "to");
                  	rule_drop.append(FactoryUI.label(hg_item.postlabel, 'rule_label')).append(FactoryUI.label(_from, 'rule_label')).append(from_select).append(FactoryUI.label(_to, 'rule_label')).append(to_select);
                  	if (from_select.find('select').length)
	                  {
	                  	hideEmptySelectBoxes.apply(from_select.find('select')[1]);
	                  	hideEmptySelectBoxes.apply(from_select.find('select')[2]);
	                  	hideEmptySelectBoxes.apply(to_select.find('select')[1]);
	                  	hideEmptySelectBoxes.apply(to_select.find('select')[2]);
	                  }
                  	break;
                 	}
                }else{
                  rule_drop.append(conditional_dom(hg_item, data_id, name, "value"));
                }
								postProcessCondition(hg_item, data_id);
							}
						});
			
			jQuery(parentDom).find('select, :text')
				.live("change",function(){
					var formObj = jQuery(parentDom).parents('form:first');
					setting.onRuleSelect.apply(this,[this,domUtil.get_filter_list('json', formObj),formObj])
				});

			jQuery(parentDom).find('#EventList select[name="from"]:not("div .event_nested_field > select")')
				.live("change", disableOtherSelectValue);

			jQuery(parentDom).find('#EventList select[name="to"]:not("div .event_nested_field > select")')
				.live("change", disableOtherSelectValue);

			jQuery(parentDom).find('#EventList div .event_nested_field > select')
				.live("change", hideEmptySelectBoxes);

			jQuery(ADD_DOM)
				.bind("click",
						function(){
							domUtil.add_dom();							
						});

			jQuery('#VirtualAgent').submit(function(e){			
				var performed_by = jQuery('input[name=va_rule[performed_by]]:checked').val();
				if ( performed_by != "agent")
				{	
					{ jQuery('#va_rule_performed_by').remove(); }
				}
				else
				{ 
					if ( jQuery('#va_rule_performed_by').val().length == 1 && jQuery('#va_rule_performed_by').val().first() == " " ) 
					{	jQuery('#va_rule_performed_by').remove(); }
					else
					{	jQuery('input[name="va_rule[performed_by]"]').remove(); }
				}
			});

			jQuery('input[name = "va_rule[performed_by]"]').bind ( "change", performed_by_change	);
			jQuery("#va_rule_performed_by").bind ( "change", ensure_performed_by );


			// Delete button action
			jQuery(parentDom+' .delete')
				.live("click", 
						function(){
							filter = jQuery(this).parent();
							if(setting.delete_last || (filter.parent().children().size() != 1)){
								filter.remove();
								domUtil.dom_size--;
							}

							var formObj = jQuery(parentDom).parents('form:first');
							setting.onRuleSelect.apply(this,[this,domUtil.get_filter_list('json', formObj),formObj]);
						});
			domUtil.init();
		}init();

		return pub_Methods;
	};

