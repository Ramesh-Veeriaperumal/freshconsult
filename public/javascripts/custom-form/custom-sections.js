(function($) {
	window.customSections = function(options) {
		var defaults = {
			type_id: 							{},
			secCurrentData: 			{},
			sectionContainer: 		".section-container",
			sectionWrapper: 			".section-wrapper",
			new_btn: 							".new-section",
			newSectionDisabled: 	"new-section-disabled",
			formContainer: 				'#custom-field-form',
			customPropsModal: 		'#CustomPropsModal',
			dialogContainer: 			'#CustomFieldsPropsDialog',
			sectionSubmitBtn: 		'#sectionSubmitBtn',
			sectionPropertiesForm:'#sectionProperties',
			sectionFieldValues: 	'#section_field_values',
			sectionEdit: 					'.section-title',
			sectionDelete: 				'.section-delete',
			sectionCancel:  			'#sectionCancelBtn',
			sectionConfirmModal: 	'#sectionConfirmModal',
			confirmFieldSubmit: 	'#confirmFieldSubmit', 
			confirmFieldCancel: 	'#confirmFieldCancel',
			copyHelper: 					'',
			types: 								{},
			ui: 									{},
			selectedPicklistIds: 	{},
			parent_id: 						'',
			section_finder: 			'li.section',
			sortingConnectors: 		[options.formContainer, '.section-body'].join(','), 
		}
		this.options 						= $.extend({}, defaults, options);
		this.section_data 			= {},
		this.all_section_fields	= $A(),
		this.convertHash();
		this.init();
	};
	customSections.prototype = {
		convertHash: function(){
			var data = this.options.secCurrentData;
			if(typeof data != 'undefined' && data != null){
				for(var i=0; i< data.length; i++){
					this.section_data[data[i].id] = $.extend({}, data[i]);
					this.section_data[data[i].id].section_fields = {}
					if (data[i].section_fields && data[i].section_fields.length) {
						for(var j=0; j< data[i].section_fields.length; j++){
							this.section_data[data[i].id]
								.section_fields[data[i].section_fields[j].ticket_field_id] = $.extend(
									{}, data[i].section_fields[j]
								);
						}
					}
				}
			}
		},

		init: function(){
			this.editSectionDialogue();
			this.deleteSectionDialogue();
			this.sectionValidateOptions();

			$(document).on('mouseover', this.options.sectionWrapper, function(e) {
				var parent_field = $( this ).parents('li.custom-field');
				parent_field.find('.options-wrapper').first().hide();
				parent_field.addClass('remove-select');
			});

			$(this.options.formContainer).on('mouseout', this.options.sectionWrapper, function(e) {
				$( this ).parents('li.custom-field').removeClass('remove-select');
			});

			$(this.options.formContainer).on('click', this.options.new_btn, $.proxy(function(e) {
				e.stopPropagation();
				if(!$(this.options.new_btn).hasClass(this.options.newSectionDisabled)) {
					this.options.parent_id = $(e.currentTarget).closest("li.custom-field").attr("data-id");
					this.showSectionDialogue();
				}
				return false;
			}, this) );
			
			$(document).on('click', this.options.sectionCancel, $.proxy(function(e) {
				e.stopPropagation();
				this.hideDialog( this.options.customPropsModal );
			}, this) );

			$(this.options.formContainer).on('click', this.options.sectionWrapper, $.proxy(function(e){
				e.stopPropagation();
			},this));

			$(document).on('click', this.options.sectionSubmitBtn, $.proxy(function(){
				$(this.options.sectionPropertiesForm).submit();
			},this));

			$(document).on('click', this.options.confirmFieldSubmit, $.proxy(function(e) { 

				e.stopPropagation();
				var radioValue = $('input[name=moveField]:checked').val();

				switch($('#confirmType').val()){

					case 'move':
						if(radioValue == 'true') {
							this.sectionFieldMove('copy')
						}else{ 
							this.sectionFieldMove('cut') //cut
						}
						break;

					case 'deleteSecField':
					case 'confirmDeleteField':
						if(radioValue == 'true') { 
							this.deleteSecField(true); //single section
						}else{ 
							this.deleteSecField(false); //multiple section
						}
						break;

					case 'secToForm':
						this.sectionToForm(this.options.ui.item.data('id'));
						break;

					case 'deleteSection':
						this.deleteSection();
						break;

					case 'available':
						break;

					default:
						break;

				}
				this.options.ui = {};
				$(this.options.sectionConfirmModal).data('isSubmited', true);
				$('.options-wrapper').hide(); //UI Fix
				this.hideDialog( this.options.sectionConfirmModal );
			},this));

			$(document).on('click', this.options.confirmFieldCancel, $.proxy(function(e) { 

				e.stopPropagation();
				this.cancelSorting();
				this.hideDialog( this.options.sectionConfirmModal );

			},this));

			$(document).on('hidden', this.options.sectionConfirmModal, $.proxy(function (ev) {

				var a = $(ev.currentTarget).data('isSubmited');
				if(!a) this.cancelSorting();

			},this));
		},

		cancelSorting: function(){
			$(this.options.copyHelper).remove();
			$(this.options.ui.sender).sortable('cancel');
			this.options.ui= {};
			this.options.copyHelper = null;
		},

		sortEventsBind: function(){

			$(document).on('sortstop',this.options.formContainer, $.proxy(function(ev, ui) {
			
				var sender 					= this.options.builder_instance.sortSender,
						current_field 	= ui.item.parents('li');
						ui.sender 			= sender;

				if(sender.hasClass('section-body')){

					(current_field.hasClass('section')) ? this.sectionToSectionDialogue(ui) : this.sectionToFormDialogue(ui);

				}else{
					var id 					= $(ui.item).data('id');
					if(id){
						var	def_check 	= (/^default/.test(this.options.builder_instance.data.get(id).field_type)),
								target 			= ev.target || ev.srcElement;
								
						if(!target.hasClassName('field') && current_field.hasClass('section') )
							(def_check) ? $(ui.sender).sortable('cancel') : this.formToSection(ui);
					}
				}

			}, this));
		},

    initSectionSorting: function(element){
    	var self = this;
    	$(element).smoothSort({
				revert: true,
				helper: function (ev, ui) {
				  self.options.copyHelper = ui.clone(true).insertAfter(ui).hide();
				  return ui.clone().data('parent', $(this));
				},

				start: function(ev, ui) {    
					self.options.builder_instance.sortSender = ui.item.parents().first();
				},

				stop: function(ev, ui) {  
					self.options.builder_instance.setNewField(ui.item);
				},

			});
			$(this.options.formContainer).sortable('option', 'connectWith', this.options.sortingConnectors);
  		$( element ).sortable('option', 'connectWith', this.options.sortingConnectors);
    },
// --------------------------------  Function Based on Section Delete --------------------------------
		deleteSectionDialogue: function(){
			$(this.options.formContainer).on('click', this.options.sectionDelete, $.proxy(function(e) {
				
				var section 			= this.currentSection(e),
						confirm_type 	= 'deleteSection';
						
				if($("li[data-section-id="+section.id+"] .section-body").children('.custom-field:visible').length > 0) 
					confirm_type = 'deleteError';
				
				$(this.options.dialogContainer).html(JST['custom-form/template/section_confirm']({
	        		'confirm_type':confirm_type, 'section_id': section.id
		        }));
				$(this.options.sectionConfirmModal).modal('show');
				return false;

			}, this) ); 
		},

		deleteSection: function(){

			var section_id 	= $(this.options.dialogContainer+" input[name=confirm-section-id]").val(),
					dom 				= $(this.options.formContainer).find("[data-section-id='" + section_id + "']");

			if(dom.data('section-fresh')){
			
				dom.remove();
				delete this.section_data[section_id];

			}else{
				
				dom.hide();
				this.section_data[section_id].picklist_ids = [];
				this.section_data[section_id].action = "delete";

			}
			this.disableNewSection();
		},

		deleteSecFieldsdialog: function(field, id){
    	this.options.ui 		= field; //Field or ui.item
    	var no_of_existence = $(this.options.formContainer).find("[data-id = '"+id+"']").length,
    			confirm_type 		= (no_of_existence == 1) ? 'confirmDeleteField' : 'deleteSecField';

			$(this.options.dialogContainer).html(JST['custom-form/template/section_confirm']({
        		'confirm_type':confirm_type
        }));
			$(this.options.sectionConfirmModal).modal('show');
		},
// --------------------------------  Function Based on Section Edit   --------------------------------
		showSectionDialogue: function(sectionData){
			if ($.isEmptyObject(sectionData)) {
				sectionData = {
					'label': 									"",
					'picklist_ids': 					[], 
					'id': 										"", 
					'parent_ticket_field_id': this.options.parent_id
				}
			}
			$(this.options.dialogContainer).html(
				JST['custom-form/template/section_dialogue'](
					{
						obj:sectionData,
						types: this.mergePicklistSelected(sectionData)
					}
				)
			);

			$(this.options.sectionPropertiesForm).validate(this.options.validateOptions);
			$(this.options.customPropsModal).modal('show');
		},

		editSectionDialogue: function(){
			$(this.options.formContainer).on('click', this.options.sectionEdit, $.proxy(function(e) {

				var sectionData = this.currentSection(e);
				this.options.parent_id = $(e.currentTarget).closest("li.custom-field").attr("data-id");
				this.showSectionDialogue(sectionData);
				$(e.currentTarget).find('.tooltip').twipsy('hide');
				return false;

			}, this) );
		},

		sectionValidateOptions: function(){
			$.validator.addMethod("uniqueSectionNames", $.proxy(function(value, element, param) {
				var _condition 	= true,
						sec_id 			= $("input[name = 'section-id']").val();
				$.each( this.section_data, $.proxy(function( key, data ) {
					if(data.label.toLowerCase() == escapeHtml(value).toLowerCase() && data.id != sec_id)
						_condition = false;
      	}, this) );
      	
				return _condition;
			}, this), translate.get('unique_section_name') );  

			this.options.validateOptions = {
				submitHandler: $.proxy(function(form){
					this.setSectionData();
					this.hideDialog( this.options.customPropsModal );
				}, this),
				rules: {
					"section-label": {
						"required": true,
						"uniqueSectionNames": true,
					},
				},
				messages: {},
				onkeyup: false,
				onclick: false
		 	};
		},

		setSectionData: function(){
    	var type = $(this.options.dialogContainer+" select[name=section-type]").val(),
    		sec_id = $(this.options.dialogContainer+" input[name=section-id]").val(),
    		picklist_ids =[];

			for (i = 0; i < type.length; i++) {
				picklist_value_ids = {};
				picklist_value_ids['picklist_value_id'] = type[i];
				picklist_ids.push(picklist_value_ids);
			}

			var new_data = {
				'label': 					escapeHtml($(this.options.dialogContainer+" input[name=section-label]").val()),
				'picklist_ids': 					picklist_ids,
				'action': 								'save',
				'parent_ticket_field_id': this.options.parent_id, 
			}

			if(sec_id == "" || sec_id == null ){ //New
				
				new_data.id = this.options.builder_instance.uniqId() 
				new_data.section_fields = {};
				this.newSectionData(new_data);

			}else{
				new_data.id = sec_id
				this.editSectionData(new_data);
			}
			this.disableNewSection();
		},
		disableNewSection: function(){
			if(this.selectedPicklist(this.options.parent_id) < 1) {
				$(this.options.new_btn).addClass(this.options.newSectionDisabled);
			}else{
				$(this.options.new_btn).removeClass(this.options.newSectionDisabled);
			}
		},
    newSectionData: function(new_data){

    	var dom = this.constructSection(new_data);
			this.section_data[new_data.id] = $.extend({}, new_data);

			$("[data-id='" + this.options.parent_id + "']")
				.find(this.options.sectionContainer)
				.prepend(dom);

			$(dom).attr("data-section-fresh",true);
			this.initSectionSorting( $(dom).find( ".section-body" ));
    },

		checkDeleteIcon: function(section_id, container, data_from){
			container = (container) ? container : this.options.formContainer;
			container = (data_from) ? $(container) : $(container+' [data-section-id=' + section_id + ']');

			var find_selector		= (data_from) ? 'li.custom-field' : 'li.custom-field:visible',
					no_of_fields 		= $(container).find(find_selector);
					delete_enabled 	= "ficon-trash-o section-delete",
					delete_disabled = "ficon-trash-strike-thru tooltip section-disabled-delete",
					icon_dom 				= $(container).find('.section-header > .section-icon');

			icon_dom.removeClass(delete_enabled + " " + delete_disabled);
			
			if( no_of_fields.length < 1){
				icon_dom.addClass(delete_enabled)
									.prop('title', '');
			}else{
				icon_dom.addClass(delete_disabled)
								.prop('title', translate.get('section_has_fields'));
			}

		},

    editSectionData: function(new_data){
  		$.extend(
  			this.section_data[new_data.id], 
  			new_data
  		);

			var vElement = $(this.options.sectionContainer).find("[data-section-id='" + new_data.id + "'] .section-header");
			$(vElement).html(JST['custom-form/template/section_header']({
					obj:new_data,
					types:this.options.types[this.options.parent_id]
				})
			);
			this.checkDeleteIcon(new_data.id);
    },	
// -------------------------------------  Section Field moving function -------------------------------------
    sectionToSectionDialogue: function(ui){
    	
    	this.options.ui = ui;
    	var parent 	= $(ui.item).closest('ul'),
    			id 			= $(ui.item).data('id');
    	//position change
			if( parent.parents('li').data('section-id') != ui.sender.parents('li').data('section-id')){

				if (ui.sender && ui.sender.hasClass('section-body') 
							&& parent.find('li[data-id=' + id + ']:visible').length <= 1 ) {

					$(this.options.dialogContainer).html(JST['custom-form/template/section_confirm']({
						'confirm_type':'move'
					}));
					$(this.options.sectionConfirmModal).modal('show');

				} else {

					this.cancelSorting();
					$(this.options.dialogContainer).html(JST['custom-form/template/section_confirm']({
						'confirm_type':'available'
					}));
					$(this.options.sectionConfirmModal).modal('show');

				}
			}else{
				$(this.options.copyHelper).remove();
				this.options.copyHelper = null;
			}
    },

    sectionFieldMove: function(field_action){
    
			var sec_to_move_id	= $(this.options.ui.item).parents('li').data('section-id'),
					section_from 		= $(this.options.ui.sender).closest('li').data('section-id'),
					field_id 			= this.options.ui.item.data('id');

			if(!this.section_data[sec_to_move_id].section_fields) 
					this.section_data[sec_to_move_id].section_fields = {};

			this.section_data[sec_to_move_id].action = 'save'; 

			//Check Hidden field(Deleted)
			if(this.section_data[sec_to_move_id].section_fields[field_id]){
				
				$("li[data-section-id = "+sec_to_move_id +"]")
						.find("[data-id ="+ field_id +" ]:hidden").remove();
				delete this.section_data[sec_to_move_id].section_fields[field_id].action;
				

			}else{

				this.section_data[sec_to_move_id].section_fields[field_id] = $.extend(
						{}, this.section_data[section_from].section_fields[field_id]
					);
				delete this.section_data[sec_to_move_id].section_fields[field_id].id;
			}

			if(field_action == 'copy'){

				$(this.options.copyHelper).show();

			}else{ //Cut
				this.deleteSectionFieldDom($(this.options.copyHelper));
				this.deleteSectionField(this.section_data[section_from], field_id);
				this.checkDeleteIcon(section_from);
			}

			this.checkDeleteIcon(sec_to_move_id);
			this.options.copyHelper = null;
    },
    
    sectionToFormDialogue: function(ui){
    	this.options.ui = ui;
    	var parent = $(ui.item).closest('ul');

			if (parent.hasClass('section-body')) {
				return;
			}

      if (ui.sender && ui.sender.hasClass('section-body')) {

      	$(this.options.dialogContainer).html(JST['custom-form/template/section_confirm']({
      		'confirm_type':'secToForm'
      	}));
      	$(this.options.sectionConfirmModal).modal('show');

      }
    },

    formToSection: function(ui){

    	this.options.ui 			= ui;
    	var sec_to_move_id 		= $(ui.item).parents('li').first().data('section-id'),
    			data 							= this.options.builder_instance.data.get(ui.item.data('id')),
    			new_data 					= {
																'ticket_field_id': data.id, 
																'ticket_field_name': data.label,
																'parent_ticket_field_id': this.options.parent_id, //Have to check
															};
			data.field_options['section'] = true;
			
			this.options.builder_instance.setAction(
    			this.options.builder_instance.data.get(data.id), 
    			"update"
    		);
    	
    	if(!this.section_data[sec_to_move_id].section_fields)
    		this.section_data[sec_to_move_id].section_fields = {};

    	this.section_data[sec_to_move_id].section_fields[data.id] = $.extend( {}, new_data );
    	this.section_data[sec_to_move_id].action = 'save';

    	this.checkDeleteIcon(sec_to_move_id);
    },
// ----------------------------- Delete Sections Fields ------------------------------------
    deleteSecField: function(value){
    	var field 	= this.options.ui,
    			id 	 		= field.data('id'),
    			sec_id 	= $(field).parents(this.options.section_finder).data('section-id'),
    			field_dom = $('ul.section-body li[data-id=' + id + ']');	
    	if(value){ //single section

  			if(!$.isEmptyObject(this.section_data[sec_id].section_fields[id])){
					this.deleteSectionField(this.section_data[sec_id], id)
					this.deleteSectionFieldDom($(field))
					this.checkDeleteIcon(sec_id);
  			}
    	}else{
    		
    		this.removeFromOtherSections(id, true);

    	}
    	//Deleting Field
			if(field_dom.length == 1) this.options.builder_instance.deleteFormField(field_dom, id);
    },

    sectionToForm: function(id){

    	delete this.options.builder_instance.data.get(id).field_options.section;
    	this.options.builder_instance.setAction(
    			this.options.builder_instance.data.get(id), 
    			"update"
    		);
    	this.removeFromOtherSections(id, false);
    },

    removeFromOtherSections: function (id, fieldDelete) {
    	var field = $('ul.section-body li[data-id=' + id + ']');
  		
  		//Delete field from section
      $.each( this.section_data, $.proxy(function( key, value ) {
      	if(value.section_fields[id]) this.deleteSectionField(value, id)
      }, this) );

      //Checking delete icon for section
	    $.each(field, $.proxy(function(index, field_dom){ 
	    	var sec_id 	= $(field_dom).parents(this.options.section_finder).data('section-id');
	    	this.deleteSectionFieldDom($(field_dom))
	    	this.checkDeleteIcon(sec_id);
	    }, this) );

      //Deleting Field
      if(fieldDelete) {
      	this.options.builder_instance.deleteFormField(field, id);
	    }
	    
    },

    deleteSectionField: function(value, id){
    	var sec_field     = value.section_fields[id],
					field         = this.options.builder_instance.data.get(id);

			if($(this.options.ui.item).attr('data-fresh')){
				delete value.section_fields[id]
			}else{
				value.section_fields[id].action = 'delete';
				if(value.action != 'delete') value.action = 'save';
			}
		},

		deleteSectionFieldDom: function(element){
			(element.attr('data-fresh')) ? element.remove() : element.hide();
		},
// -------------------------------------  Saving Sections -------------------------------------
		saveSection: function(){
			var self = this;
			$.each(this.section_data, function(id, value){
				
				var sectionDom = $(self.options.sectionContainer).find("[data-section-id='" + id + "']"),
					fresh_section = $(sectionDom).attr('data-section-fresh') ? true : false,
					data = self.section_data[id];
					data = $.extend(
						true, 
						self.getSectionFields(sectionDom, data, id), 
						{fresh_section: fresh_section}
					)

					self.deleteSectionData(data);
					self.all_section_fields.push(data);
			});
			
			$(this.options.sectionFieldValues).val(this.all_section_fields.toJSON());
			
		},
		deleteSectionData: function(data){
			if(data.fresh_section) delete data.id;
			delete data.parent_ticket_field_id;
			delete data.fresh_section;
		},
		getSectionFields: function(sectionDom, data, sectionId){
			var fieldData = $A(),
				position	= 1;
			$(sectionDom).find('li.custom-field').each($.proxy(function(index, domLi){
				var id 			= $(domLi).data("id"),
					fresh_field = $(domLi).attr('data-fresh') ? true : false,
					sec_field 	= data.section_fields[id];

				    if( sec_field.position != position ) {
				    	sec_field.position = position;
				    	if(data.action != 'delete') data.action = 'save';
				    }

				    position = ( sec_field.action == 'delete') ? position : position + 1;
				    
				    if(fresh_field) delete sec_field.ticket_field_id;

				    fieldData.push(sec_field);

			}, this) );

			data.section_fields = fieldData;
			return data;
		},
// -------------------------------------  Common function -------------------------------------
		currentSection: function(e){
			var target 	= $((e.currentTarget) ? e.currentTarget : e.srcElement).closest('li'),
				id  	= target.data('section-id');
			return this.section_data[id];
		},

		storedSectionData: function(parentFieldId,types,builderDom){
			var data_dom = [],
				self = this;
			this.options.types[parentFieldId] = types;
			this.options.parent_id = parentFieldId;

			$.each(this.section_data, function(key, sec) {

				if(sec.parent_ticket_field_id == parentFieldId) {
					
					data_dom[key] 	= self.constructSection(sec);
					var arrayFields = $.map(sec.section_fields, function(value, index) {
														    return [value];
														});	
					$.each(arrayFields.sort(function(obj1, obj2) {return obj1.position - obj2.position;}), function(j, fields) {
						var clone = builderDom[fields.ticket_field_id].clone(true);
						data_dom[key].find('.section-body').append(clone);
					});
					self.checkDeleteIcon( sec.id, data_dom[key], 'stored' );
				}

			});
			return data_dom
		},

		arrayOfPicklistId: function(data){
			return data.map(
								function(item) {
									return parseInt(item.picklist_value_id, 10);
								}
							);
		},
		//Currently Selected Picklist Id Array
		selectedPicklist: function(parentId){
			var selected_ids = [];
			$.each(this.section_data, $.proxy(function(key, section){

				if(parentId == section.parent_ticket_field_id)
					$.merge(selected_ids, this.arrayOfPicklistId(section.picklist_ids));

			}, this));

			return this.options.types[parentId].filter( 
												function(item){ 
													return (selected_ids.indexOf(item.id) < 0 ) 
												});
		},
		
		mergePicklistSelected: function(section){
			var parent_id 			= this.options.parent_id,
					current_values 	= this.arrayOfPicklistId(section.picklist_ids);

			return $.merge( 
								this.selectedPicklist(parent_id),  
								this.options.types[parent_id].filter( function(item){
										return (current_values.indexOf(item.id) >= 0)
									})
							);

		},

		constructSection: function(data, container) {
      	var container = container || jQuery('<li/>');
      	container.empty()
      					.addClass('section')
	  						.attr("data-section-id", data.id)
      					.html(JST['custom-form/template/section'](
      						{
      							obj:data, 
      							types:this.options.types[data.parent_ticket_field_id], 
      						})
      					);
		return container;
    },

    newSectionFields: function(data,element){ // function call from custom-form-bulder.js
    	var id 				= element.parents('li').data('section-id'),
    			new_data 	= {
												'ticket_field_id': data.id, 
												'ticket_field_name': data.label,
												'parent_ticket_field_id': this.options.parent_id,
								    	};
			
			if($.isEmptyObject(this.section_data[id].section_fields)) 
				this.section_data[id].section_fields = {};

			this.section_data[id].section_fields[data.id] = $.extend({}, new_data);
			this.checkDeleteIcon( id );
    },
    updateSectionFields: function(data, sectionDom){
    	var sec_id = sectionDom.data('section-id');
    	this.section_data[sec_id]
    				.section_fields[data.id].ticket_field_name = data.label;
    },
    hideDialog: function( modal_selector ){ 
			$(modal_selector).modal('hide');
		},

	};

})(jQuery);