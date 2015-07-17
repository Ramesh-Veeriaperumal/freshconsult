
/**
 * @author venom
 */

function postProcessCondition(filter, id){
	if(filter && filter.domtype === 'autocompelete'){
		new bsn.AutoSuggest(id, {
			script: filter.data_url+"?",
			varname: "q",
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

function getFilterInOptgroupFormat(filter){
	var _filter_group = [], _filter_children = []
	jQuery.each(filter, function(i, item){
		if(i == 0){
			_filter_group.push([item.name, item.value])
			return
		}
		if(item.name == -1 || i == filter.length){
			_filter_group.push(["------------------", _filter_children])
			_filter_children = []
		}else{
			_filter_children.push([item.name, escapeHtml(item.value), item['unique_action']])
		} 
	});
	_filter_group.push(["------------------", _filter_children]);
	return _filter_group;
};

function disableOtherSelectValue(item, container){
	var $this = jQuery(item.element[0]).parent(),
			target_name = { from : 'to', to : 'from' }[$this.prop('name')],
			target = $this.siblings('select[name="'+target_name+'"]').find("option:selected")
			target_value = target.val(),
			target_text = target.text();
			
	if(target_text == item.text && target_value != '--') jQuery(container).hide()

	return escapeHtml(item.text)
};

var selectedOptionList = $H();

function disableSingleSelectOnly(item, container){
	if(selectedOptionList.get(item.id)){
		jQuery(container).hide()
	}
	return item.text
}

function removeIfConditionMatches(elementVal, checkValue, 
															DOMToBeRemovedIfTrue, DOMToBeRemovedIfFalse){
	if(elementVal==checkValue){
		DOMToBeRemovedIfTrue.remove();
	}else{
		if(DOMToBeRemovedIfFalse)
			DOMToBeRemovedIfFalse.remove();
	}
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
			criteria 		   : "ticket",
			is_requester	   : false,
			orig_filter_data   : filter_data,
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
								.append("<i class=\"rounded-minus-icon delete\"></i>")
								.append("<span class='sort_handle'></span>")
								.append(inner)
								.append("<input type=\"hidden\" name=\""+name+"\" value=\"end\" />");
				jQuery.data(outer, "inner", inner);
				return outer;
			},
		dom_size: 0,
		add_dom: 
			function(){
				if(setting.is_requester) {
					setting.criteria = 'ticket';
					filter_data = $A(setting.orig_filter_data[setting.criteria]);
				}
				// Adding a new Filter DOM element to the Filter Container
				var r_dom = domUtil.getContainer(name);
				var filterList = [];
				if(setting.delete_last){
					var selected_quest = jQuery("input[name='quest[category]']:checked").val();
					//var criteria_list = quest_criteria_types[selected_quest];
					filterList = setting.change_filter_data(filter_data[0][setting.selectListArr[selected_quest]]) || [];
				} else {
					filterList = filter_data;
				}

				$filter_select_list = FactoryUI.optgroup(getFilterInOptgroupFormat(filterList), "name", "ruCls_"+name+' select2', 
					  										{'minimumResultsForSearch':'10', 'specialFormatting': true}).data('dropdownCssClass', "align_options")
				if(parentDom=='#actionDOM')
					jQuery($filter_select_list).data('formatResult', disableSingleSelectOnly);

				if(setting.is_requester && parentDom=='#filterDOM'){
					jQuery.data(r_dom, "inner").append('<div class="btn-group condn-group-selection">'
															+ '<a href="#" class="ficon-ticket btn active tooltip" data-criteria="ticket" title="Ticket Fields"></a>'
															+ '<a href="#" class="ficon-user btn tooltip" data-criteria="requester" title="Contact Fields"></a>'
															+ '<a href="#" class="ficon-company btn tooltip" data-criteria="company" title="Company Fields"></a>'
														+ '</div>'
														+ '<input type="hidden" name="evaluate_on" value="ticket" />');
				}

				jQuery.data(r_dom, "inner")
					  .append($filter_select_list)
					  .append("<div />");

				list_C = jQuery(parentDom).find(setting.rule_dom);
				r_dom.appendTo(list_C);

				this.dom_size++;
				this.populateEmpty();
			},
		// To manage unmigrated data
		format_old_data:
			function(rule) {
				if(rule['name'] == 'contact_name') {
      				rule['name'] = 'name';
      				rule['evaluate_on'] = 'requester';
      			}
      			else if(rule['name'] == 'company_name') {
      				rule['name'] = 'name';
      				rule['evaluate_on'] = 'company';
      			}else{
      				rule['evaluate_on'] = rule['evaluate_on'] || 'ticket';                  				
      			}
			},
		// Used to Edit pre-population
		feed_data:

         function(dataFeed){	
            dataFeed.each(function(rule){            	
             try{
                  var r_dom	= domUtil.getContainer(name);
                  var inner	= jQuery("<div class = 'dependent' />");
                  var data_id = rule.name + itemManager.get();

                  if(rule.operator){	
                  	try{
                  		if(setting.is_requester) {
                  			// To manage unmigrated data
                  			domUtil.format_old_data(rule);

                  			filter_data = $A(setting.orig_filter_data[rule.evaluate_on]);
                  			domUtil.add_to_hash(filter_data);
                  		}
                     	opType = hg_data.get(rule.name).operatortype;
                     	inner.append(FactoryUI.dropdown(operator_types.get(opType), "operator", 'operator select2', {'minimumResultsForSearch':'10'}).val(rule.operator));
                    }catch(e){}
                  }	
                  if(rule.name == "set_nested_fields"){
                  	rule.name = rule.category_name;
                  }

                  if(name == "event"){
	                  switch (hg_data.get(rule.name).type)
	                  {
	                 	case 1:
	                  	if(hg_data.get(rule.name).valuelabel)
                  			inner.append(FactoryUI.label(hg_data.get(rule.name).valuelabel, 'fromto_text'));	

	                  	inner.append(conditional_dom(hg_data.get(rule.name), data_id, name, rule, "value", 'select2 test_value_field ', {'minimumResultsForSearch':'10'}));
	                  	break;
	                  case 2:
	                  	from_select = conditional_dom(hg_data.get(rule.name), data_id, name, rule, "from", 'select2 test_from_field', {'minimumResultsForSearch':'10', 'formatResult':disableOtherSelectValue});
	                  	to_select = conditional_dom(hg_data.get(rule.name), data_id, name, rule, "to", 'select2 test_to_field', {'minimumResultsForSearch':'10', 'formatResult':disableOtherSelectValue});
	                  	
	                  	inner.append(FactoryUI.label(event_lang['from'], 'fromto_text'))
	                  				.append(from_select)
                  					.append(FactoryUI.label(event_lang['to'], 'fromto_text'))
                  					.append(to_select);
		                  break;
	                 	}
                	}else{
                		dom = conditional_dom(hg_data.get(rule.name), data_id, name, rule, "value", 'select2', {'minimumResultsForSearch':'10'});
                		inner.append(dom);
                		//invokeRedactor("paragraph-redactor","cnt-fwd","class");
                	}

					var filterList = [];
					if(setting.delete_last){
						var selected_quest = jQuery("input[name='quest[category]']:checked").val();
						//var criteria_list = quest_criteria_types[selected_quest];
						filterList = setting.change_filter_data(filter_data[0][setting.selectListArr[selected_quest]]);
					} else {
						filterList = filter_data;
					}				
									$filter_list_select = FactoryUI.optgroup(getFilterInOptgroupFormat(filterList), "name", "ruCls_"+name+' select2', 
                     											{'minimumResultsForSearch':'10', 'specialFormatting': true})
																					.val(rule.name).data('dropdownCssClass', "align_options");
									if(parentDom=='#actionDOM')
										jQuery($filter_list_select).data('formatResult', disableSingleSelectOnly);


									if($filter_list_select.find(":selected").data("unique_action") == true) {
											selectedOptionList.set(rule.name, true)
											$filter_list_select.data("prevValue", rule.name);
									}

									if(setting.is_requester && parentDom=='#filterDOM'){
										jQuery.data(r_dom, "inner").append('<div class="btn-group condn-group-selection">' 
																				+ '<a href="#" class="ficon-ticket tooltip btn" data-criteria="ticket" title="Ticket Fields"></a>'
																				+ '<a href="#" class="ficon-user tooltip btn" data-criteria="requester" title="Contact Fields"></a>'
																				+ '<a href="#" class="ficon-company tooltip btn" data-criteria="company" title="Company Fields"></a>'
																			+'</div>')
																	.append('<input type="hidden" name="evaluate_on" value="' + rule.evaluate_on + '" />');
										jQuery(r_dom).find('.btn[data-criteria='+rule.evaluate_on+']').addClass('active');
									}

                  jQuery.data(r_dom, "inner")
                     .append($filter_list_select)
                     .append(inner);	

                  list_C = jQuery(parentDom).find(setting.rule_dom);
                  r_dom.appendTo(list_C);
                  postProcessCondition(hg_data.get(rule.name), data_id);
             }catch(e){}
            });
			this.dom_size = dataFeed.size()+1;
    },

    	refresh_item: 
    		function($element){
				filter_data = $A(setting.orig_filter_data[setting.criteria]);
				filterList = setting.change_filter_data(filter_data);

				var $controls = $element.parents('.controls'),
					$select = $controls.find('select');

				$select.select2('destroy').remove();
				$filter_list_select = FactoryUI.optgroup(getFilterInOptgroupFormat(filterList), "name", "ruCls_filter"+' select2', 
                     											{'minimumResultsForSearch':'10', 'specialFormatting': true})
																	.data('dropdownCssClass', "align_options");
				$controls.find('.dependent').empty();
				$controls.find('input[name=evaluate_on]').after($filter_list_select);
				domUtil.add_to_hash(filter_data);
    	},
        populateEmpty: 
        	function(){
				jQuery(parentDom).find(setting.empty_dom).toggle(this.dom_size < 1);
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
							
						if(item.value == 'start'){
							tempConstruct = $H();
							flag = true;
						}
						else if (item.value == 'end'){
						  if(tempConstruct.size() && !(tempConstruct.size() == 1 && (typeof tempConstruct.get('evaluate_on') != 'undefined')))
							  serialHash.get(name).push(tempConstruct.toObject());

							flag = false;
						}
						//st_survey_rating and customer_feedback => check for surveys with disagree(-1) condition
						else if(item.value != -1 || tempConstruct.get('name') == 'st_survey_rating' ||
								tempConstruct.get('name') == 'customer_feedback'){
							split_words = item.name.match(/(.*)\[(.*)\]/m)
							if(split_words!=null){
								hash_name = split_words[1]
								hash_key = split_words[2]
								currentHash = tempConstruct.get(hash_name) || {}
								currentHash[hash_key] = item.value
								tempConstruct.set(hash_name, currentHash)
							}else if(item.name!='name' //Hack for set_nested_fields
								&& tempConstruct.get(item.name)){
               	group_item = tempConstruct.get(item.name)
	              if(group_item instanceof Array)
	                group_item.push(item.value)
	              else
	                group_item = [group_item, item.value]
	              
	              tempConstruct.set(item.name, group_item);
         			}else{
                tempConstruct.set(item.name, item.value);
         			}
						}
					}
				});
				var current_filter = [],
				    save_data	    = [];
				
				current_filter = serialHash.get(name);

				if( current_filter && current_filter.length != 0 ){

					if(current_filter[0]['email_body'] != undefined)
					current_filter[0]['email_body'] = current_filter[0]['email_body'].replace(/(\r\n|\n|\r)/gm," ");

					save_data = (type != 'json') ? current_filter.toObject() : current_filter.toJSON();
				}

				hidden_.val(save_data);

				this.populateEmpty && this.populateEmpty();

				return save_data;
			},
		init: 
			function(){
				filter_data = $A(setting.orig_filter_data);
				if(setting.is_requester) {
					filter_data = $A(setting.orig_filter_data[setting.criteria]);
				}

				filter_data.each(function(item){
					if(item.value != undefined){
						item.value = unescapeHtml(item.value)
					}
					else{
						jQuery.each(item, function(i, game_category){
							jQuery.each(game_category, function(j, game_option){
								game_option.value = unescapeHtml(game_option.value)
							})
						})
					}	
				})

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
				if(parentDom=='#actionDOM'){
					removeIfConditionMatches(jQuery("input[name=need_authentication]:checked").val(), undefined, jQuery(".credentials"));
					removeIfConditionMatches(jQuery("input[name='content_layout']:checked").val(), 1, jQuery(".edit2"), jQuery(".edit1"));
					removeIfConditionMatches(jQuery("select[name=request_type]").val(), 1, jQuery('.request_content'));
					removeIfConditionMatches(jQuery("select[name=request_type]").val(), 5, jQuery('.request_content'));
					removeIfConditionMatches(jQuery(".api_webhook").attr("style"), "display: none;", jQuery('.api_webhook'), jQuery('.user_pass_webhook'));
				}
						
				jQuery.each(jQuery('.paragraph-redactor'), function(i, item) { 
					var $redactor = jQuery(item).data("redactor"); 
					if($redactor != "undefined") { 
						$redactor.deleteCursor(); 
						$redactor.changesInTextarea();
					} 
				});

				domUtil.get_filter_list('json', this);
				// return false;
			});

			jQuery('.l_placeholder').die('click').live("click", function(ev){
				ev.preventDefault();
				// active_email_body = jQuery(this).prev();

				jQuery('#place-dialog').slideDown('fast', function(){
					jQuery(this).groupPlaceholders({'truncateItems': false});
				});
			});

			// Binding Events to Containers
			// Filter on change action 
			
			jQuery(parentDom+' .'+"ruCls_"+name)
				.live("change", 
						function(){ 
							var rule_drop = jQuery(this).next().empty().addClass('dependent'),
									$this = jQuery(this);

							if(this.value !== -1){
								var hg_item = hg_data.get(this.value);
								var data_id = hg_item.name + itemManager.get();

								if(hg_item.operatortype){
									rule_drop.append(FactoryUI.dropdown(operator_types.get(hg_item.operatortype), "operator", 'operator select2', {'minimumResultsForSearch':'10'}));
								}

								if($this.find(":selected").data("unique_action") == true) selectedOptionList.set($this.val(), true)
								if($this.data("prevValue") != $this.val()) selectedOptionList.set($this.data("prevValue"), false)
								
								$this.data("prevValue", $this.val());

								if( name == "event"){
                  switch (hg_item.type)
                  {
                 	case 1:
                  	if(hg_item.valuelabel)
              				rule_drop.append(FactoryUI.label(hg_item.valuelabel, 'fromto_text'));

                  	rule_drop.append(conditional_dom(hg_item, data_id, name, {value:'--'}, "value", 'select2 test_value_field ', {'minimumResultsForSearch':'10'}));
                  	break;
                  case 2:
                  	// console.log(hg_item)
                  	from_select = conditional_dom(hg_item, data_id, name, {from:'--'}, "from", 'select2 test_from_field', {'minimumResultsForSearch':'10', 'formatResult':disableOtherSelectValue});
                  	to_select = conditional_dom(hg_item, data_id, name, {to:'--'}, "to", 'select2 test_to_field', {'minimumResultsForSearch':'10', 'formatResult':disableOtherSelectValue});

                  	rule_drop.append(FactoryUI.label(event_lang['from'], 'fromto_text'))
                							.append(from_select)
                  						.append(FactoryUI.label(event_lang['to'], 'fromto_text'))
                  						.append(to_select);
                  	break;
                 	}
                }else{
                	var default_value = (hg_item.domtype == "nested_field") ?  {value:'--'} : null
                	dom = conditional_dom(hg_item, data_id, name, default_value, "value", 'select2', {'minimumResultsForSearch':'10'} );
                  rule_drop.append(dom);
                  //New Action
      			  		invokeRedactor("paragraph-redactor","cnt-fwd","class");
                }
								postProcessCondition(hg_item, data_id);
							}
						});

			jQuery(parentDom).find('.webhook select[name=request_type]')
				.live("change", function(){
					var request_content = jQuery(this).parent().parent().find('.request_content');
					if(jQuery(this).val()==1 || jQuery(this).val()==5)
						request_content.slideUp('slow');
					else
						request_content.slideDown('slow');
				});

			jQuery(parentDom).find('.webhook input[name=need_authentication]')
				.live("change", function(){	jQuery(this).parent().parent().parent().find('.credentials').slideToggle();	});

			jQuery(parentDom).find('.webhook .credentials_toggle')
				.live("click", function(){
					current_credential = jQuery(this).parent();
					current_credential.hide();
					current_credential.siblings().show();
				});

			jQuery(parentDom).find('.webhook input[name=content_layout]')
				.live("change", function(){
					divs = jQuery(this).parent().parent().find('.edit1,.edit2')
					divs[1].toggle();
					divs[0].toggle();
				});

			jQuery(parentDom).find('.webhook .params_div .checkbox').live("change", function() {
				if(this.checked) {
			  	jQuery(this).parent().addClass('highlighted');
				}else{
					jQuery(this).parent().removeClass('highlighted');
				}
			});

			jQuery(parentDom).find('.webhook input[name=content_type]').live("change", function(){
				advanced_rb = jQuery(this).parent().parent().parent().find('input[name=content_layout][value=2]').first();
				if(jQuery(this).val()==3){
					advanced_rb.attr("disabled", true);
					jQuery('label[for='+advanced_rb.attr("id")+']').addClass('muted');
					jQuery(this).parent().parent().parent().find('input[name=content_layout][value=1]').click();
				}else{
					advanced_rb.enable();
					jQuery('label[for='+advanced_rb.attr("id")+']').removeClass('muted');
				}
			});

			jQuery(parentDom).find('.webhook a[href=#change_password]').live("click", function(){
				jQuery(this).hide();
				jQuery(this).parent().find('.password').show();
			});
			
			jQuery(parentDom).find('select, :text')
				.live("change",function(){
					var formObj = jQuery(parentDom).parents('form:first');
					setting.onRuleSelect.apply(this,[this,domUtil.get_filter_list('json', formObj),formObj])
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

							selectedOptionList.set(filter.find("select.ruCls_filter, select.ruCls_action, select.ruCls_event").val(), false)
							if(setting.delete_last || (filter.parent().children().size() != 1)){
								filter.remove();
								domUtil.dom_size--;
							}

							var formObj = jQuery(parentDom).parents('form:first');
							setting.onRuleSelect.apply(this,[this,domUtil.get_filter_list('json', formObj),formObj]);
						});
			jQuery(parentDom+' .condn-group-selection .btn')
				.live('click',
						function(e) {
							e.preventDefault();
							var $this = jQuery(this);
							setting.criteria = $this.data('criteria');
							$this.parent().siblings('input[name=evaluate_on]').val(setting.criteria);
							$this.siblings().removeClass('active');
							$this.addClass('active');
							domUtil.refresh_item($this);
						});
			domUtil.init();
			invokeRedactor("paragraph-redactor","cnt-fwd","class");
		}init();

		return pub_Methods;
	};

