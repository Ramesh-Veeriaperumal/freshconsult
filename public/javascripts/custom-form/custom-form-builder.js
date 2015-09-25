(function($) {
  window.customFieldsForm = function(options) {
    var fieldTemplate = {
      'ticket': {
        label_in_portal:        "", 
        description:            "",
        active:                 true,
        required:               false,
        required_for_closure:   false,
        visible_in_portal:      true,
        editable_in_portal:     true,
        required_in_portal:     false,
        portalcc:               false,
        portalcc_to:            "all",
        custom_form_type:      'ticket'
      },
      'contact': {
        label_in_portal:        "",
        visible_in_portal:      true,
        editable_in_portal:     true,
        editable_in_signup:     false,
        required_in_portal:     false,
        custom_form_type:      'contact'
      },
      'company': {
        custom_form_type:      'company'
      }
    }
    var defaults = {
        formContainer:      '#custom-field-form',
        customFieldItem:    '#custom-fields li',
        fieldValues:        '#field_values',
        submitForm:         '#Updateform',
        customFieldsWrapper:'#custom-fields',
        saveBtn:            '.save-custom-form',
        fieldLabelClass:    '.custom-form-label',
        sectionbody:        '.section-body',
        dialogContainer:    '#CustomFieldsPropsDialog',
        confirmModal:       '#ConfirmModal',
        confirmFieldSubmit:   '#confirmDeleteSubmit',
        confirmFieldCancel:   '#confirmDeleteCancel',
        currentData:        null,
        existingFields:     {},
        disabledByDefault:  [],
        deleteFieldItem:    null,
        deleteFieldId:      null
    }
    this.settings = $.extend({}, defaults, options);
    this.settings.fieldTemplate = fieldTemplate[this.settings.customFormType];
    this.listSortObject = {};
    this.fieldDialog = {};
    this.builder_data = [];
	this.dragField 	= null;
    this.position = 1;
    this.element = null;
    this.data = $H();
    this.section_instance = {};
    this.sortSender = null;
  };
  customFieldsForm.prototype = {
    uniqId: function () {
      return Math.round(new Date().getTime() + (Math.random() * 100));
    },
    // Getting from jsonData
    feedJsonForm: function (existingFields) {
      $(existingFields).each($.proxy(function(index, dataItem){
          if (!dataItem.has_section) {
            this.builder_data[dataItem.id] = this.domCreation(dataItem);  
          } else {
            this.builder_data[dataItem.id] = "";  
          }
      }, this));
    },

    sectionJsonForm: function (existingFields) {
      $(existingFields).each($.proxy(function(index, dataItem){

          if (dataItem.has_section) {
            this.builder_data[dataItem.id] = this.domCreation(dataItem);  
          }

      }, this));
      
    },

    domCreation: function(dataItem){
      var dom = jQuery('<li/>'),
          fieldClass = this.getFieldClass(dataItem.dom_type, dataItem.field_type),
          options = {
                      'currentData' : dataItem,
                      'fieldTemplate' : this.settings.fieldTemplate, 
                      'customMessages': this.settings.customMessages
                    };

      this.addAdditionalProps(dataItem);
      data = new window[fieldClass](dom, options);
      dom.data('customfield', data);
      this.constructFieldDom(data['getProperties'](), dom);
      this.data.set(dataItem.id, data['getProperties']());
      return dom;
    },

    constructFieldDom: function(dataItem, container, cloneItem) {
      var fieldContainer = container || jQuery('<li/>');

      fieldContainer.empty()
                    .removeClass('field')
                    .addClass('custom-field');

      fieldContainer.attr("data-id", dataItem.id);
      fieldContainer.attr('data-drag-info', dataItem.label); //Information for dragging

      this.setTypefield(dataItem);
      fieldContainer.html(
          JST['custom-form/template/dom_field'](dataItem)
        ).addClass(dataItem.dom_type);

      if(dataItem.has_section){
        var section_dom =  this.section_instance
                            .storedSectionData(
                                dataItem.id,dataItem.admin_choices,this.builder_data
                            );

        $.each(section_dom, function(i, element) {
          fieldContainer.find('.section-container').prepend(element);
        });
      }

      return fieldContainer;
    },

    reConstructFieldDom: function(data) {
      var dom_elements      = $(this.settings.formContainer).find('li[data-id="'+data.id + '"]'),
          no_fields_repeat  = dom_elements.length;

      //Repeated field 
      for(var i=0; i < no_fields_repeat; i++ ){
        $(dom_elements[i]).find(this.settings.fieldLabelClass)
                          .first()
                          .html(data.label);

        var private_icon = $(dom_elements[i]).find('.private-symbol').first();
        (data.visible_in_portal) ? private_icon.hide() : private_icon.show();
      } 

    },

    appendDom: function(existingFields){

      $(existingFields).each($.proxy(function(index, dataItem){

        if( !dataItem.field_options.section )
          $(this.settings.formContainer).append(this.builder_data[dataItem.id]);
        if(dataItem.has_section) this.section_instance.disableNewSection();

      }, this));

    },

    addAdditionalProps: function(dataItem) {

      if(this.settings.disabledByDefault[dataItem.field_type]) {

        dataItem.disabled_customer_data = this.settings.disabledByDefault[dataItem.field_type];
      }

      if($.inArray(dataItem.field_type, this.settings.nonEditableFields) >= 0) {
        dataItem.is_editable = false;
      }

      dataItem.custom_form_type = this.settings.customFormType;
    },

    setTypefield: function(dataItem){

      switch(dataItem.dom_type) {

          case 'requester':
             dataItem.type = "text";
          break;

          case 'dropdown_blank':
          case 'nested_field':
             dataItem.type = "dropdown";
          break;

          case 'html_paragraph':
             dataItem.type = "paragraph";
          break;

          default:
             dataItem.type = dataItem.dom_type;
       }
    },

    showFieldDialog: function(element){
      this.element = element;
      var id = $(element).data("id"),
          instance = $(element).data('customfield'),
          selectedPicklistIds = {},
          fieldtype = instance.getProperties()['field_type'];

      if ($.inArray(fieldtype, this.settings.nonEditableFields) == -1) {
        if(id && this.data.get(id).has_section)
          selectedPicklistIds = this.section_instance.selectedPicklist(id);

        this.fieldDialog.show(element, instance.attachEvents, selectedPicklistIds);
      }

    },

    setNewField: function(item, isClicked){
      if(item.data("fresh")){
        field_label   = item.text();
        type          = item.data('type');
        field_type    = item.data('fieldType');
        var fieldContainer;

        if(type) {

          var item_clone = item;

          if(isClicked) {

            item_clone = item.clone();
            $(this.settings.formContainer).prepend(item_clone);
            $('body').animate({
                        scrollTop:0
                      }, '500')
          }

          var fieldClass = this.getFieldClass(type, field_type),
              options = {
                          'fieldTemplate' : this.settings.fieldTemplate, 
                          'customMessages': this.settings.customMessages
                        };

          data = new window[fieldClass](item_clone, options);
          fieldContainer = this.constructFieldDom(data['getProperties'](), item_clone, true);
          fieldContainer.data('customfield', data);

          if(item.closest('ul').hasClass("section-body")){
            fieldContainer.data('section', true);
          }

          this.showFieldDialog(fieldContainer);
        }

      }
    },

    getFieldClass: function(domtype, fieldtype) {
      if (domtype == 'dropdown' || domtype == 'dropdown_blank') {
        if(fieldtype == 'nested_field') return "CustomNestedField";
        return "CustomDropdown";
      } else if (domtype == 'nested_field') {
          return "CustomNestedField";
      }
      return "CustomField";
    },

    deleteField: function(sourcefield){
      var id = sourcefield.data('id');
      this.settings.deleteFieldItem = sourcefield;
      this.settings. deleteFieldId = id;
      this.settings.currentData = $H(this.data.get(id));
      if(/^default/.test(this.settings.currentData.get('field_type'))) {
        return;
      }

      if($(sourcefield).closest('ul').hasClass('section-body')){
        //Section Field
        this.section_instance.deleteSecFieldsdialog(sourcefield, id);

      }else{

        $(this.settings.dialogContainer).html(JST['custom-form/template/section_confirm']({
          'confirm_type': 'deleteNonSecField'
        }));
        $(this.settings.confirmModal).modal('show');

      }
      this.fieldDialog.hideDialog();
    },

    deleteFormField: function(sourcefield, id){

      if($(sourcefield).attr('data-fresh')){
        
        $(sourcefield).remove();
        this.data.unset(id);

      }else{
        
        $(sourcefield).hide();
        this.setAction(this.data.get(id), "delete");

      }
    },

    setAction: function(obj, action){
      
      switch(action){

          case "update":
            if(obj.action != "create") obj.action = action;
          break;

          default: 
            obj.action = action;
          break;
      }

    },
    
    saveCustomFields: function(ev) {
      ev.preventDefault();
      var jsonData = this.getCustomFieldJson();
      $(this.settings.fieldValues).val(jsonData.toJSON());

      this.value = $(this).data("commit");
      $(this.settings.saveBtn).prop("disabled", true);
      $(this.settings.submitForm).trigger("submit");
    },

    getCustomFieldJson: function(){
      var allfields     = $A(),
          increment     = 0,
          save_section  = false;

      $(this.settings.formContainer+" li.custom-field").each($.proxy(function(index, domLi){

        var id                = $(domLi).data("id"),
            fresh_field       = $(domLi).attr('data-fresh') ? true : false,
            can_push          = this.data.get(id).canpush, 
            data              = $.extend({},this.data.get(id));
        if(typeof can_push === 'undefined'){ //Checking Repeated Fields
          
          this.data.get(id).canpush = true;
          if(data.has_section) save_section = true;

          data = $.extend(true, data, {fresh_field: fresh_field})
          data = this.findFieldPosition(data, domLi);
          this.deletePostData(data);

          allfields.push(data);
          delete allfields[increment].canpush;
          increment = increment + 1;
        }

      }, this) );

      if(save_section) this.section_instance.saveSection();

      return allfields;
    },
    findFieldPosition: function(data, domLi){
      if( data.position != this.position && data.action != 'delete') {
        data.position = this.position;
        if(!data.fresh_field) data.action = 'edit';
      }
      this.position = ( data.action == 'delete') ? this.position : this.position + 1;
      return data;
    },

    deletePostData: function(data) {    

      data.custom_field_choices_attributes = data.admin_choices;
      if(data.fresh_field) delete data.id;
      if(data.field_options){
        if( !data.field_options.section ) delete data.field_options.section;
        if(data.field_options.length < 1) delete data.field_options;
      }
      if(data.column_name == 'default') {
        delete data.custom_field_choices_attributes;
      }

      delete data.admin_choices;
      delete data.fresh_field
      delete data.dom_type;
      delete data.validate_using_regex;
      delete data.disabled_customer_data;
      delete data.custom_form_type;
      delete data.is_editable;
      delete data.has_section;
      return data;
    },

    initializeDragDropSortElements: function() {

      $(this.settings.customFieldsWrapper).find('.field')
        .draggable({
          connectToSortable: this.settings.formContainer,
          helper: function() {
            var clone = $(this).clone();
            clone.find('.dom-icon').removeAttr('title').removeAttr('data-original-title').removeClass('tooltip');
            return clone;
          },
          stack:  this.settings.customFieldsWrapper + " li",
          revert: "invalid",
          appendTo: 'body'
      });
      this.initSortableElements();
      this.section_instance.initSectionSorting( $('.section-container').find( this.settings.sectionbody ));
      this.section_instance.sortEventsBind();
    },

    initSortableElements: function () {
        $(this.settings.formContainer)
          .smoothSort({
            revert: true,
            distance: 5,
            start: $.proxy(function (ev, ui) {
                this.sortSender	= ui.item.parents().first();
				if (!ui.item.data('fresh'))	this.dragField = ui.item;
            }, this),
			sort: $.proxy(function (ev, ui) {
				if (this.dragField !== null) {
                	this.section_instance.doWhileDrag(this.data.get(this.dragField.data('id')));
				}
            }, this),
            stop: $.proxy(function (ev, ui) {
				this.setNewField(ui.item);
				this.dragField = null; //Reset
				$('.default-error-wrap').hide();
            }, this),

          });
    },

    initialize: function () {
      // Populating fields
      this.feedJsonForm(this.settings.existingFields);
      this.section_instance = new customSections({
        builder_instance:   this,
        formContainer:      this.settings.formContainer,
        secCurrentData:     this.settings.customSection
      });
      this.sectionJsonForm(this.settings.existingFields);
      this.appendDom(this.settings.existingFields);
      this.initializeDragDropSortElements();

      //Adding New fields
      $(document).on('click.custom-fields', this.settings.customFieldItem, $.proxy(function(e) {
        this.setNewField($(e.currentTarget), true);
        return false;
      }, this) );

      $(this.settings.formContainer).on('mouseover', 'li.custom-field', $.proxy(function(e) {
          if(!$(this.settings.formContainer).hasClass('sort-started'))
            $(e.currentTarget).find('.options-wrapper').first().show();
      }, this));

      $(this.settings.formContainer).on('mouseout', 'li.custom-field', function(e) {
          $( this ).find('.options-wrapper').first().hide();
      });

      $(this.settings.formContainer).on('click', '.custom-field', $.proxy(function(e) {
        if(!$(e.currentTarget).hasClass('ui-sortable-helper')) { // to ignore if its being dragged
          this.showFieldDialog($(e.currentTarget));
        }
        return false;
      }, this));

      //Delete Field
      $(this.settings.formContainer).on('click', '.delete-field', $.proxy(function(e) {
        e.stopPropagation();
        this.deleteField($(e.currentTarget).closest('.custom-field'));
        return false;
      }, this));

      $(document).on('click', this.settings.confirmFieldSubmit, $.proxy(function (e) {
        e.stopPropagation();
        this.deleteFormField(this.settings.deleteFieldItem, this.settings.deleteFieldId);
        this.settings.deleteFieldItem = null;
        this.settings.deleteField = null;
        $('.options-wrapper').hide(); //UI Fix
        $(this.settings.confirmModal).modal('hide');
        $('.twipsy :visible').hide(); // tooltip fix

      }, this));

      $(document).keypress(this.settings.confirmModal, $.proxy(function(e) {
        e.stopPropagation();
        var keyCode = e.which || e.keyCode || e.charCode;
        if(keyCode == 13) {
          $(this.settings.confirmFieldSubmit).click();
        }
      }, this));

      $(document).on('click', this.settings.confirmFieldCancel, $.proxy(function(e) { 

        e.stopPropagation();
        $(this.settings.confirmModal).modal('hide');

      },this));

      //Save Form
      $(this.settings.saveBtn).on('click', $.proxy(function(e) {
          this.saveCustomFields(e);
          return false;
      }, this) );

      $(document).on('show', '.custom-fields-props-dialog.modal', function () {
        setTimeout(function(){
          $('.modal-body input[type=text]:visible:enabled:first').select().focus();
        },500)
      });

      //Form Submit
      //It will trigger for editing fields
      $(document).on('customDataChange', $.proxy(function(ev, data){
        var vElement = $(this.element);
        if(!data.id){  //New Field
          data.id = this.uniqId(); 
          if(vElement.data('section')){
            if(!data.field_options) data.field_options = {}
            data.field_options['section'] = true;
            this.section_instance.newSectionFields(data, vElement);
          } 
          this.builder_data[data.id] = this.constructFieldDom(data, vElement);
        }else{ //Edit Field
          if(data.has_section || data.field_type == 'default_priority' || 
                data.field_type == "default_agent" || data.field_type == "default_group" || 
                data.field_type == "default_product"){
              this.reConstructFieldDom(data);
          }else{
            var parent_dom = vElement.parents('li:first')
            if(parent_dom.hasClass('section')){

              if(!data.field_options) data.field_options = {}
              data.field_options['section'] = true;
            
              if(vElement.attr('data-fresh')) //Update Label for new Section Fields
                this.section_instance.updateSectionFields(data, parent_dom);
            } 
            this.builder_data[data.id] = this.constructFieldDom(data, vElement);
          }
        }
        this.data.set(data.id, data);
        return false;

      }, this) );
      
      this.fieldDialog = new CustomFieldDialog();
    }
  };

})(jQuery);