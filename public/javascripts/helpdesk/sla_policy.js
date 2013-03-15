(function($) {
	$(document).ready(function(){
		
		$('[rel=sla_checkbox]').itoggle({
			checkedLabel: 'On',
			uncheckedLabel: 'Off'
		});

		if(!is_default) {
			lookupCompany = function(searchString, suggest) {
				new Ajax.Request(autocomplete_companies_url,
													{ parameters: {name: $.trim(searchString)},
														method: 'GET',
														onSuccess: function(response) {
															suggest(response.responseJSON);
														} 
												});
			}
		
			var cachedBackendCompany = new Autocompleter.Cache(lookupCompany, {choices: 10, searchKey: 0});
			var cachedLookupCompany = cachedBackendCompany.lookup.bind(cachedBackendCompany);
			
			var autocomplete_companies = new Autocompleter.MultiValue("autocomplete_companies", cachedLookupCompany, 
													companies, 
													{placeHolder: placeholder['company'] });

			$('.select2-conditions').select2({
				allowClear: true
			});

			jQuery('.add_new_condition .dropdown-toggle').qtip({ 
				show: {ready: true},
				position: { 
				  my: 'left center',
				  at: 'right center',
				},
				style: { 
					classes:'sla-policy-tooltip',
				 },
				hide: {
				event: false
				},
				show: {
				event: false
				}
			});

		}
		agFormatResult = function(result) {
			var email = result.email;
			if($(email).trim != "")
				email = "  (" + email + ")";	
			
			return "<b>"+ result.value + "</b><br><span class='select2_list_detail'>" + 
							email + "</span>"; 
		}
		
		agFormatSelection = function(result) {
			return result.value;
		}
		$('.agents_id').select2({
			placeholder: placeholder['agent'],
			minimumInputLength: 1,
			multiple: true,
			ajax: {
					url: agent_autocomplete_helpdesk_authorizations_path,
					quietMillis: 1000,
					data: function (term) { 
							return {
								v: term
							};
					},
					results: function (data) {
							var temp;
							$(data.results).each(function(){
								temp = this.id;
								this.id = this.user_id;
								this.email = temp;
							});
							return {results: data.results};
					}
			},
			formatResult: agFormatResult,
			formatSelection: agFormatSelection,
			initSelection: function(element, callback) {
				var data = [];
				var val = $(element).data('value');
				$(element).val("");
				if(val){
					$(val).each(function () {
						agent = agents_hash[this];
						if(agent != undefined)
							data.push({email: agent.email, id: this, value: agent.name});
			    });
				}
				callback(data);
			}
		});
		
		$('.delete').click(function(){
			var current_tr = $(this).parents('tr');
			var table = $(this).parents('table');
			current_tr.find('input.agents_id').select2("val", '');
			current_tr.hide('fast', function() {
				change_levels($(this), $(this).parents('table').data('max-level'), true);
				table.find('.add_next_level .level').html(table.data('max-level') - table.find('tr.escalations:hidden').length + 1);
			});
		});
		
		//Change levels
		change_levels = function(current_tr, set_level, clear_data) {
			if($(current_tr).get(0) == undefined || set_level == undefined)
				return false;
			
			var current_type = $(current_tr).data('type');
			var current_level = $(current_tr).data('level');

			//Recursive call
			change_levels($('#' + current_type + '_level_' + (parseInt(current_level)+1)), current_level);

			$(current_tr).data('level', set_level);
			$(current_tr).find('.lb-number').html(set_level);
			$(current_tr).attr('id', $(current_tr).data('type') + "_level_" + set_level);
			$(current_tr).find('select[rel=' + current_type + '_time]')
				.attr('id', "select_" + current_type + "_time_" + set_level);
			$(current_tr).find('label').attr('for', "select_" + current_type + "_time_" + set_level);

			//clear_data is set only for the tr which is deleted
			if(clear_data) {				
				generate_select($('#select_'+ current_type +'_time_1'));
				var parent_table = current_tr.parents('table');
				parent_table.append(current_tr);
				parent_table.find('.add_next_level').show('fast');	
			}
			return true;
		}

		// Select options created on the fly
		var generate_select = function(current_ele, initialize) {	

			if($(current_ele).get(0) == undefined)
		 		return false;
		 	var val;
		 	var parent_tr = $(current_ele).parents('tr');
		 	var ref = parent_tr.data('level');
		 	var type = parent_tr.data('type');
		 	var previous_ele = parseInt(ref) -1;
		 	var next_ele = parseInt(ref) + 1;

			
			val = (previous_ele) ? $('#select_' + type + '_time_' + previous_ele).val() : -1;
	
			var current_val = $(current_ele).val();

			$(current_ele).html("");
			var max_value = $("#" + type + "_time :last-child").val();
			$("#" + type + "_time").children().each(function(){
				if(parseInt($(this).val()) > val || parseInt($(this).val()) == max_value )
					$(current_ele).append($(this).clone());
			});

			initialize ? $(current_ele).val(time[ref]) : $(current_ele).val(current_val);
			generate_select($('#select_' + type + '_time_' + next_ele), 
											initialize);
		}

		var lastConditionBorder = function() {
			$('.sla_policy_conditions_container .condition.last-child').removeClass('last-child');
			if ($('.sla_policy_conditions_container .condition:visible').length != $('.sla_policy_conditions_container .condition').length)
				$('.sla_policy_conditions_container .condition:visible:last').addClass('last-child');
		}

		// Initialization on page load
		generate_select($('#select_resolution_time_1'), true);
		
		// Changing value recursively if one is changed
		$('[rel=resolution_time]').change(function(){
			generate_select(this);
		});

		//Executed upon click of "Add next level" button
  	$('.add_next_level div').click(function(){
			var parent = $(this).parents('table');
			var next_level = parent.find('tr:hidden');
			
			if(next_level.length) {	
				var element = next_level.first();
				//Add validation class and set next availabe time
				element.find('select').val("");
				//Append add_next_level button to last
				parent.append($(this).parents('tr').first());

				if(next_level.length <= 1)
					$(this).parents('tr').hide();

				element.show('fast',function(){
					parent.find('.add_next_level .level').html(parent.data('max-level') - next_level.length + 2); // Current level	
				});
				
				if($(this).data('type') == 'resolution')
					generate_select($('#select_resolution_time_1'));
			}
  		
  	});

		// Hide if not needed
		$('.add_next_level div').each(function(){
			var table = $(this).parents('table');
			var next_level = table.find('tr.escalations:hidden');
			table.find('.add_next_level .level').html(table.data('max-level') - next_level.length + 1);
			if(next_level.length)
				$(this).parents('tr').show();
		});

  	//Hide "Add conditions" button if not needed
  	if($('div.condition:hidden').length) {
			$('div.add_new_condition').slideDown('fast');
			lastConditionBorder();
  	}
  	
  	if(!$('div.condition:visible').length)
  		$('.add_new_condition .dropdown-toggle').qtip('show');

  	$('div.condition:visible').each(function(){
  		$('.condition_list[data-cond=' + $(this).attr('id') + ']').parent().hide();
  	})

  	//Upon change of conditions select dropdown
		$('.condition_list').live('click', function(ev) {
			ev.preventDefault();
  		var target = $('#' + $(this).data('cond')); //Gives target div
  		
  		$(this).parents('div.add_new_condition').before(target);
  		target.show();
  		if(!$('.condition:hidden').length)
  			$('.add_new_condition').hide();
  		lastConditionBorder();
  		$(this).parent().hide();
  	});
  	$('.btn.dropdown-toggle').click(function(){
  		$('.add_new_condition .dropdown-toggle').qtip('hide');
  	});

  	//Executed upon click of delete button click
  	$('.delete_conditions').click(function(){
			var current_div = $(this).parent();
			var cond = current_div.attr('id');
	
			if(cond != "company_id") {
				current_div.find('select.select2-conditions').val("").change();
			}
			else {
				autocomplete_companies.clear();
			}
			current_div.hide();
			$('.add_new_condition').show();
			$('.condition_list[data-cond=' + cond + ']').parent().show();
			lastConditionBorder();
		});

		// Reconstruct input field on form submit
		$('form.sla_policy_form').validate({
			onkeyup: false,
      focusCleanup: true,
      focusInvalid: false
		});

		$('form.sla_policy_form').on('submit', function(ev) {

			var no_condition = true;
			if(!is_default) {
				$('[name*="helpdesk_sla_policy[conditions]"]').each(function() {
					if($(this).val())
						no_condition = false
				});
			}
			if(no_condition && !is_default) {
				$('label[for=sla_policy_conditions]').addClass('error').show();
				$('.add_new_condition .dropdown-toggle').qtip('hide');
				return false;
			}
			else {
				removeLevel();
				reconstruct();	
			}

		})
		removeLevel = function() {
			$('tr.escalations:visible').each(function(){
				if($.trim($(this).find('input.agents_id').val()) == "" && $(this).is(':visible')) {
					var table = $(this).parents('table');
					$(this).hide();
					change_levels($(this), $(this).parents('table').data('max-level'), true);
					table.find('.add_next_level .level').html(table.data('max-level') - table.find('tr.escalations:hidden').length + 1);
				}
			});
			
		}
  	reconstruct = function() {
  		var visible_levels = $('[rel=reconstruct]:visible');
  		if(visible_levels.length) {
				visible_levels.each(function() {
					var type = $(this).data('type');
					var level = $(this).data('level')
					var name = "helpdesk_sla_policy[escalations][" + type + "][" + 
								level + "]";

					var parent = this;
					$(this).find('input.agents_id, select').each(function() {
						if($(this).hasClass('select2-input'))
							return this;
						if($(this).data('name') == 'agents_id') {
							var input_element = $(this);
							var value = this.value;
							if($.trim(value) != "" ) {
								$.each(value.split(","), function(index, value) {
									$(parent).append($('<input>').attr({type: 'hidden', 
																		name: name + "[agents_id][]", value: value}));
								});
							}
						}
						else {
							this.name =  name + "[" + $(this).data('name') + "]";
						}
					});
				});
			}
			else {
				$('form.sla_policy_form').append($('<input>').attr({type: 'hidden', 
					name: 'helpdesk_sla_policy[escalations][response]', value: ""}));
				$('form.sla_policy_form').append($('<input>').attr({type: 'hidden', 
					name: 'helpdesk_sla_policy[escalations][resolution]', value: ""}));
			}
			
			return true;
  	}

	})
})(jQuery);
