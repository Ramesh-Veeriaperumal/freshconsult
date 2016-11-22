/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
(function ($) {
	"use strict";
	var inherit_parent=[],newValues={},oldValues={},element;
	jQuery('#helpdesk_ticket_template_name').focus();

	App.Parentchildtemplates = {
		current_module: '',

		onFirstVisit: function (data) {
			this.onVisit(data);
		},

		onVisit: function (data) {
			this.setSubModule();
			if (this.current_module !== '') {
				this[this.current_module].onVisit();
			}
			this.bindEvents();
		},

		setSubModule: function() {
			switch (App.namespace) {
				case 'helpdesk/ticket_templates/index':
					this.current_module = "Index"
					break;
				case 'helpdesk/ticket_templates/create':
				case 'helpdesk/ticket_templates/new_child':
					this.current_module = "NewChild"
					break;
				case 'helpdesk/ticket_templates/update':
				case 'helpdesk/ticket_templates/edit':
					this.current_module = "Edit"
					break;
				case 'helpdesk/ticket_templates/edit_child':
					this.current_module = "EditChild"
					break;
				case 'helpdesk/ticket_templates/clone':
					this.current_module = "Clone"
					break;
			}
		},

		onLeave: function (data) {
			if (this.current_module !== '') {
				this.current_module = '';
				this.unBindData();
			}
		},

		initializeChildModel : function(){ // intialize child modal
			this.requester();
			var $labelEl,$parentEl,className,dropdownReg=/dropdown/,nestedReg=/main_field/,tagReg=/default_tags/,desReg=/paragraph/,checkboxReg=/checkbox/,requesterReg=/requester-email/;
			$('#p_id').val(customMessages.parentId)
			$('input[type=text],textarea').addClass('insert-placeholder-target');
			$("#template_data_ticket_body_attributes_description_html").addClass('desc_info');
			$('.template-ticket-fields li.field label').each(function(index,ele){
				$labelEl= $(ele),$parentEl=$labelEl.parent();
				if(!$labelEl.hasClass('select2-offscreen') && typeof $labelEl.attr('class') !== typeof undefined && $labelEl.attr('class') !== false || $labelEl.attr('for') === 'template_data_tags'){
					className=$parentEl.attr('class')
					element="<div class='options-wrapper' style='display: none;'><div class='opt-inner-wrap'><div class='options'><span class='parent-icon-wrapper'><i class='ficon-inherit-parent parent-btn tooltip fsize-18' twipsy-content-set='true' data-placement='right' data-original-title='"+customMessages.inherit_tooltip+"'></i></span></div></div></div>";
					$labelEl.after(element);
					switch(true){
						case dropdownReg.test(className):
							$parentEl.find('.opt-inner-wrap').addClass('dropdown_option');
							break;
						case nestedReg.test(className):
							$parentEl.find('.opt-inner-wrap').addClass('main_field_option');
							break;
						case tagReg.test(className):
							$parentEl.find('.opt-inner-wrap').addClass('default_tags_option');
							break;
						case desReg.test(className):
							$parentEl.css('border-radius','0 5px 5px 5px')
							break;
						case requesterReg.test(className):
							$parentEl.find('.opt-inner-wrap').addClass('email_requester_option');
							break;
						case checkboxReg.test(className):
							$parentEl.find('.options-wrapper').addClass('checkbox_option');
							break;
						default:
							break;
					}
				}
			});
			if(customMessages.existing && this.localStorageProcess('get',customMessages.existing,'')){
				$("#child_template_existing").prop('checked','checked');
				$('#helpdesk_ticket_template_name').attr('disabled',true)
				this.childExistingChange(true,$('#helpdesk_ticket_template_name').val());
				if($('.attachmentTrigger').is(':visible'))
					$('.attachmentTrigger').hide()
				if($('.attachment').length>0 && window.location.pathname.indexOf('new')!=-1)
					$('.attachment').addClass('hide');
			}
		},
		initializeEditModel : function(modalName){ //intialize edit modal
			$('body').append($('#' + modalName));
			$('#' + modalName).modal('hide');
			if($('#edit-unlink').length > 0){
				$('body').append($('#edit-unlink'));
				$('#edit-unlink').modal('hide');
			}
		},
		intializeUnsavedModel: function(){ // intialize unsaved modal pop up 
			$('body').append($('#toggle-confirm'));
			$('#toggle-confirm').modal('hide');
		},
		loadAllChildTemplate: function(event){ // load all child template
			var loadParams = "",
				searchUrl = "/helpdesk/ticket_templates/search_children",
	        	loadUrl = '/helpdesk/ticket_templates/all_children',
	        	searchString = $("#filter-template").val(),
	        	searchParams,
	        	params,
	        	endpoint,self=this;;
		    loadParams = {child_ids: customMessages.child_ids};

		    if(event === "keypress" && searchString !== ""){
		    	loadParams.search_string=searchString
		    }
	        endpoint = ((event === 'keypress' && searchString !== "") ? searchUrl : loadUrl),
	      $.ajax({
				url: endpoint,
				type: "GET",
				dataType: 'json',
				data:loadParams,
				beforeSend: function(){
					$("#template-loading").show();
        		$("#template-items").hide();
        		if(event !== 'keypress'){
            	self.hideSearchBox();
            }
        },
        success: function(data){
        	$("#template-loading").hide();
        	$("#template-items").show();
        	if(event === 'keypress'){
        	 	data["event"] = 'search';
        	 }
        	var len = data.all_children.length;
        	var tmpl = JST["app/template/child_ticket_template"]({
        		data: data
        	});

        	$("#template-items").removeClass('sloading').html(tmpl);
        	if(len >= 10 && event !=='keypress' ){
        		self.showSearchBox();
        	}
        	self.enablePicklist();
        },
        error: function(){
        	console.log(err);
        }
			});
		},
		getOldValues: function(){ //get form old value
			oldValues = this.getData();
			var self = this;
			if(customMessages.edit && oldValues.template_data.inherit_parent === 'all'){
				setTimeout(function(){
					oldValues=self.getData();
				},1000)
			}
		},
		requester: function(){ // intialize requester field
      var req_metaobj = $("#meta-req").data(),_partial_list;

      function req_lookup(searchString, callback) {
      		$('#template_data_requester_id').val('');
          new Ajax.Request(req_metaobj.url + '?q=' + encodeURIComponent(searchString),{
              method:'GET',
              onSuccess:  function(response) {
              var choices = $A();
              response.responseJSON.results
              .each(function(item){ 
              choices.push(item.details);
              });  

             _partial_list = $("#template_data_email").data("partialRequesterList") || []
              $("#template_data_email").data("partialRequesterList", _partial_list.concat(response.responseJSON.results))
              callback(choices);
              }
          });
      }

      var req_cachedBackend = new Autocompleter.Cache(req_lookup, {choices: 20});
      var req_cachedLookup = req_cachedBackend.lookup.bind(req_cachedBackend); 

      new Autocompleter.Json(req_metaobj.obj+"_email", req_metaobj.obj+"_email_choices", req_cachedLookup, {
        afterUpdateElement: function(element, choice){  
          _partial_list = $("#template_data_email").data("partialRequesterList");
          if(_partial_list){
          	_partial_list.each(function(item){    
            if(element.value == item.details){
              $('#template_data_requester_id').val(item.id);
              $('#template_data_email').blur().focus();
            }
          });
          }
        }
      });

      $("body").on("keyup.template_form", "#template_data_email", function(){
        $(this).data("requesterCheck", false);
      });
		},
		initializeEditInheritFeild: function(inheritFields){ // intialize edit inherit fields
			var parentElement,self=this,ele;
			if(inheritFields && inheritFields.length>0){
				if(inheritFields.indexOf('all') === -1){
					inherit_parent = inheritFields.slice();
					inheritFields.each(function(value,index){
						ele = $('#ticket_template').find("[name*='"+ value+"']");
						parentElement=ele.closest('li');
						switch(value){
							case 'description_html':
								self.redactorEnableOrDisable(true);
								break;
							case 'requester_id':
								$('#template_data_email').prop('disabled','disabled');
								break;
						}
						ele.prop('disabled','disabled');
						if(ele.parent().prop('class').indexOf('date')!== -1){
							ele.parent().prop('disabled','disabled');
						}
						parentElement.find('.parent-btn').removeClass('ficon-inherit-parent').addClass('ficon-undo-inherit').parent().addClass('parent-change');
					})
				}else{
					this.inheritAllParent();
				}
			}
		},
		inheritAllParent:function(){
			inherit_parent=[];
			var self=this;
			if($('#inherit-parent').length === 0){
				self.appendHiddenField($('#ticket_template'),'template_data[inherit_parent]','all','inherit-parent');
			}else
				$('#inherit-parent').val('all')
			self.clearData();
			$('.inherit_parent').attr({'data-inherit-all':true,'data-original-title':customMessages.undoParentInherit})
				.removeClass('ficon-inherit-parent').addClass('ficon-undo-inherit').parent().addClass('parent-change');
			$('.inherit_parent_label').text(customMessages.undoParentInherit);
			this.enableDisableAllFields(true);
			$('.insert_placeholder').attr('disabled',true)
			if($('input[name="child_template"]').length != 0) {
				$('input[name="child_template"]').attr('disabled',true)
			}
			$('.parent-btn').removeClass('ficon-inherit-parent').addClass('ficon-undo-inherit parent-disabled').prop('disabled',true).parent().addClass('parent-change');
		},
		enableDisableAllFields: function(status){
			setTimeout(function(){
				$('.template-ticket-fields li').find('input,select,textarea').prop('disabled',status);
			},100)
			this.redactorEnableOrDisable(status);
		},
		compareData: function(){ // compare form oldvalues and new values and set form changed flag
			newValues=this.getData();
			if(!(_.isEqual(oldValues, newValues))){
				$('#ticket_template.ticket_template_form').data('formChanged', true);
			}else{
				$('#ticket_template.ticket_template_form').data('formChanged', false);
			}	
		},
		childExistingChange: function(status,value){// enable or disable all buttons based on status
			var self=this;
			$('.parent-btn').removeClass('ficon-undo-inherit').addClass('ficon-inherit-parent').prop('disabled',status).parent().removeClass('parent-change');
			if(status){
				$('.parent-btn').addClass('parent-disabled')
				$('.inherit_parent').addClass('parent-disabled')
			}
			else{
				$('.parent-btn').removeClass('parent-disabled')
				$('.inherit_parent').removeClass('parent-disabled')
			}
			$('.insert_placeholder').prop('disabled',status)
			$('.inherit_parent').prop('disabled',status)
			$('.parent-li ul li:last-child').html("<span class='child edit'><i class='ficon-pencil'></i>"+(value ? value : customMessages.noName )+"</span>");
			this.enableDisableAllFields(status);
			if(value){
				$('.child-existing-select').html('( '+ value+' )').removeClass('hide');
			}else{
				$('.child-existing-select').html('');
				if(!$('.child-existing-select').hasClass('hide')){
					$('.child-existing-select').addClass('hide')
				}
			}
		},
		unBindData: function(){ // unbind all events
			$('body').off('.template_form');
			$("#template-wrapper").off('.template_form');
		},
		getData: function(){ // get form values
			var values={}
			$.each($('#ticket_template').serializeObject(), function(fieldname, value){
				if(fieldname!='_method' && fieldname!='authenticity_token' && fieldname!='utf8' && fieldname!= 'p_id' && fieldname!='id'){
			    values[fieldname] = value;
				}
			});
			return values;
		},
		clearIndividualField: function(element,source,fieldType){ // clear individual field 
			if(source != 'childexisting'){
				switch(fieldType){
					case 'textfield':
						element.find('input,textarea').not('.checkbox,.date').val('');
						var $foundEl = element.find("input");
						if($foundEl.hasClass('date')){
							element.find('.dateClear').trigger('click')
						}
						if($foundEl.hasClass('checkbox')){
							element.find('input').prop('checked',false).val(0)
						}
						if($foundEl.hasClass('decimal')){
							element.find('input').valid();
						}
						if(element.hasClass('default_tags')){
							element.find('input').trigger('change')
						}
						break;
					case 'dropdown':
						element.find('select').select2('val','').trigger('change');
						break;
					case 'redactor_editor':
						element.find('.redactor_editor').html('');
						break;
					default:
						break;
				}
			}
		},
		openTemplate: function(status){ // open template
			this.clearData();
			this.localStorageProcess('add',customMessages.existing, true);
			$("#filter-template").val("").focus();
	    $("#template-wrapper").addClass('active');
	    this.loadAllChildTemplate('initload');
	    this.childExistingChange(status,'');
		 	$('#helpdesk_ticket_template_name').val('').prop('disabled',status);
		},
		editRestValue: function(keyArray,oldValues){ // get reset value
			var value;
			if(oldValues){
				keyArray.each(function(val,index){
					value=  (index === 0) ? oldValues[val] : (value ? value[val] : undefined)
				});
			}
			return value;
		},
		editResetField: function(status,keyArray,oldValues,field,fieldType){ // reset edit field value to original value after undo inherit parent
			var self=this;
			if(customMessages.edit && !status){
				var resetValue;
				switch(fieldType){
					case "textfield":
						resetValue=self.editRestValue(keyArray,oldValues);
						if(!field.hasClass('checkbox')){
							field.val(resetValue)
							if(field.attr('id') === 'template_data_tags') {
								field.trigger('change');
							}
							if(field.hasClass('date') && resetValue){
								field.parent().find('.dateClear').show()
							}
							break;
						}
						if(field.hasClass('checkbox')){
							field.val(resetValue).attr('checked',(resetValue==='1')?true:false)
						}
						break;
					case "dropdown":
						resetValue=self.editRestValue(keyArray,oldValues);
						if(field.attr('id')=== 'template_data_responder_id'){
							setTimeout(function(){
								field.select2('val',resetValue).trigger('change');
							},1000)
						}else{
							field.select2('val',resetValue).trigger('change');
						}
						break;
					case "nested_field":
						field.closest('select.nested_field').map(function(){
							resetValue=self.editRestValue($(this).attr('name').replace(/[\[\]/\s/']+/g,',').split(",").filter(Boolean)
	,oldValues);
							$(this).select2('val',resetValue).trigger('change');
						})
						break;
					case "redactor_editor":
						resetValue=self.editRestValue(keyArray,oldValues);
						field.find('.redactor_editor').html(resetValue);
						$('#template_data_ticket_body_attributes_description_html').val(resetValue);
						break;
					default:
						break;
				}
			}
		},
		editResetAllFields: function(){
			var self=this,fieldDetails,keyArray=[],eleClassFlag;
			$('.template-ticket-fields li.field label').each(function(index,ele){
				eleClassFlag=typeof jQuery(ele).attr('class') !== typeof undefined ;
				if(!jQuery(ele).hasClass('select2-offscreen') && eleClassFlag && jQuery(ele).attr('class') !== false || jQuery(ele).attr('for') === 'template_data_tags'){
					fieldDetails=self.setFieldNames(ele,'reset-all');
					if(fieldDetails && fieldDetails.fieldName) { 
						keyArray=fieldDetails.fieldName.replace(/[\[\]/\s/']+/g,',')
							.split(",")
							.filter(Boolean);
						self.editResetField(false,keyArray,oldValues,fieldDetails.field,fieldDetails.fieldTypeName);
						keyArray=[];
					}
				}
			});
		},
		redactorEnableOrDisable: function(status){
			$('.redactor_editor').attr('contenteditable',!status);
			if(status){
				$('.redactor_toolbar').addClass('disabled');
				$('.attachmentTrigger').hide();
				$('.attachments-wrap').addClass('hide');
				Helpdesk.Multifile.resetAll(jQuery('#ticket_template'));
			}else{
				$('.redactor_toolbar').removeClass('disabled');
				$('.attachmentTrigger').show();
				$('.attachments-wrap').removeClass('hide');
			}
		},
		setFieldNames: function(ele,source){
			var obj={},className,notFound=-1;
			obj.parentElement = $(ele).closest('li');
			className=obj.parentElement.attr('class');
			switch(true){
				case (className.indexOf('decimal') !== notFound || className.indexOf('number') !== notFound || className.indexOf('date') !== notFound || className.indexOf('checkbox') !== notFound || className.indexOf('text') !== notFound || className.indexOf("requester") !== notFound ):
					obj.inputField= (className.indexOf('default_tags') !== notFound) ? obj.parentElement.find('input#template_data_tags') : ((className.indexOf('requester') !== notFound) ? obj.parentElement.find('input.requester')  : obj.parentElement.find('input'));
					obj.field=obj.inputField;obj.fieldType='input';
					obj.fieldName=($(obj.inputField).prop('class').indexOf('date')!== notFound )? ($(obj.inputField[1]).prop('name')) :obj.inputField.attr('name');
					obj.fieldTagName='textfield';obj.clearField=obj.parentElement;obj.fieldTypeName='textfield';
					break;
				case (className.indexOf('custom_paragraph') !== notFound ):
					obj.field=obj.parentElement.find('textarea');obj.fieldType='textarea';obj.fieldName=obj.field.attr('name');obj.fieldTagName='textfield';obj.clearField=obj.parentElement;obj.fieldTypeName='textfield';
					break;
				case ((className.indexOf('dropdown_blank') !== notFound || className.indexOf('dropdown') !== notFound ) && !className.indexOf('select2-container') !== notFound ):
					obj.field=obj.parentElement.find('select');obj.fieldType='select';obj.fieldName=obj.field.attr('name');obj.fieldTagName='dropdown';obj.clearField=obj.parentElement,obj.fieldTypeName='dropdown';
					break;
				case (className.indexOf('html_paragraph') !== notFound ):
					obj.field=$(ele).closest('li');obj.fieldType='textarea';obj.fieldName=$('#template_data_ticket_body_attributes_description_html').attr('name');
					obj.fieldTagName='redactor_editor';obj.clearField=obj.field;obj.fieldTypeName='redactor_editor';
					break;
				case (className.indexOf('nested_field nested_field') !== notFound ):
					obj.field=obj.parentElement.find('select');obj.fieldType='select';obj.fieldName=obj.parentElement.find('select').attr('name');obj.fieldTagName='dropdown';obj.clearField=obj.parentElement;obj.fieldTypeName='nested_field';
					break;
				default:
					break;
			}
			return obj;
		},
		enableOrDisableFields: function(status,ele,source,childexisting){ // enable or disable fields
			var fieldDetails=this.setFieldNames(ele,source);
			if(!fieldDetails)
				return;
			if(fieldDetails.parentElement.hasClass('html_paragraph')){
			 this.redactorEnableOrDisable(status);
			}
			if(fieldDetails.parentElement.hasClass('requester-email')){
			 $('#template_data_requester_id').prop('disabled',status);
			}
			fieldDetails.parentElement.find(fieldDetails.fieldType).prop('disabled',status)
			this.addOrRemoveData(status,source,fieldDetails.fieldName);
			this.clearIndividualField(fieldDetails.parentElement,childexisting,fieldDetails.fieldTagName);
			if(source!=='inherit_parent'){
				this.editResetField(status,fieldDetails.fieldName.replace(/[\[\]/\s/']+/g,',')
					.split(",")
					.filter(Boolean),oldValues,fieldDetails.field,fieldDetails.fieldTypeName)
			}
		},
		addOrRemoveData: function(status,source,val){ // add or remove data for inherit parent values
			if(!val)
				return
			var value = val.replace(/[\[\]']+/g,'').replace(/template_data/g,'').replace(/ticket_body_attributes/g,'').replace(/custom_field/g,'');
			if('parent-btn' === source) {
				if(status){
					inherit_parent.splice(inherit_parent.length,0,value)
				} else {
					inherit_parent.splice(inherit_parent.indexOf(value),1)
				}	
			}
			
		},
		appendHiddenField: function(form,name,value,id){ // append hidden field for form
			form.append(new Element('input', {
				type: 'hidden',
				name: name,
				value:value,
				id: id
			}));
			// form.find('input[name='+name+']').val(value)
		},
		clearData: function(){ // clear fields
			var $ticketTemplate = jQuery('#ticket_template'),$attachment=jQuery('.attachmentTrigger');
			$ticketTemplate.find("input[type=text], textarea").not('#helpdesk_ticket_template_name').val("");
			$ticketTemplate.find("select").val()
			jQuery('.redactor_editor').html('');
			jQuery('input:checkbox').removeAttr('checked');
			jQuery('#template_data_tags').val('').trigger('change');
			$ticketTemplate.find('select').select2('val','').trigger('change');
			$ticketTemplate.find('.dateClear').trigger('click')
			Helpdesk.Multifile.resetAll($ticketTemplate);
			if($attachment.is(':visible')){
				$attachment.hide()
			}else{
				$attachment.show()
			}
		},
		checkAllowedKeys: function(keyCode){ // key allowed filter child templates list
			var keyCodes = [13,37,38,39,40];
			return (keyCodes[keyCode]) ? false : true;
		},
		enablePicklist: function(){ // enable picklist for child template popup
		    var _this = this;
		    $("#filter-template").pickList({
		  		listId: $("#template-items"),
		  		callback: function(){
		  			var activeElem = $("#template-items li.active");
		  				_this.changeTemplate(activeElem);
		  		}
			 });
		 },
		 changeTemplate: function(elem){  // change child template list on filter action
		 	var id = $(elem).data('id'),self=this;
		   if(id){
		     self.showLoader();
		     $("input#id").val('').val(id);
		     $("#template-wrapper").removeClass('active');
		     $.ajax({
					url: '/helpdesk/ticket_templates/apply_existing_child',
					type: "POST",
					dataType: 'script',
					data:{
						id:id,
						p_id: customMessages.parentId
					},
					success: function(data){
					},
					error:function(err){
						console.log(err);
					}
				});
		   }
		 },
		 addExistingChild: function(id,elem){ // ajax call for saving child template using apply child template rjs
		 	var params={},self=this;
		 	if(elem.hasClass('add_child')){
		 		params.add_child=true;
		 	}
		 	params.p_id=customMessages.parentId
		 	$.ajax({
				url: "/helpdesk/ticket_templates/"+ id+"/add_existing_child",
				type: "POST",
				data:params,
				success: function(data){
					if(data && data.success && data.url ){
						self.localStorageProcess('remove',customMessages.existing,'');
						window.location.href = data.url;
					}
					else if(data.msg){
						$("#noticeajax").html(data.msg).show();
						closeableFlash('#noticeajax');
						$(document).scrollTop(0);
						self.disableBtnFields(false)
					}
				},
				error:function(err){
					console.log(err);
				}
			});
		},
		localStorageProcess: function(status,variable,value){ // local storage add/edit/get action
		 	if(status === 'add'){
		 		localStorage.setItem(customMessages.existing, true);
		 	}else if(status === 'remove'){
		 		localStorage.removeItem(customMessages.existing)
		 	}else if(status === 'get'){
		 		return localStorage.getItem(variable);
		 	}
		},
		showLoader: function(){ // show loader while apply child template is loading
	    if($('.loading-template').hasClass('hide')){
	      $('.loading-template').removeClass('hide');
	    }
	  },
	  hideLoader: function(){ // hide loader after apply child template is loaded
	    $('.loading-template').addClass('hide');
	  },
		hideSearchBox: function(){ // hide search box in apply template
			var $filterWrapper = $(".filter-wrapper");
			if($filterWrapper.is(':visible')){
				$filterWrapper.addClass('hide');
			}
		},
		showSearchBox:function(){ // show search box in apply template
			var $filterWrapper = $(".filter-wrapper");
			if($filterWrapper.hasClass('hide')){
				$filterWrapper.removeClass('hide');
			}
		},
		disableBtnFields:function(status){
			$('.form_btn').attr('disabled',status);
			$('.insert_placeholder').attr('disabled',status);
			$('.inherit_parent').attr('disabled',status);
		},
		changeInheritParentID: function(){
	    jQuery('#inherit-parent').val(customMessages.intialInheritParent)
	  },
	  formSubmit: function(srcElement){
  		this.disableBtnFields(true);
    	if($(srcElement).hasClass('template_add_child') || $(srcElement).hasClass('add_child')){ //redirects to add child template page after saving by passing 'add_child' param
    		this.appendHiddenField($('#ticket_template'),'add_child','true','add_child');
    	}
    	var id=$('#id').val();
	  	if(id && !$('#ticket_template').hasClass('edit_child_form')){ // if child template is created using apply child template action, then sends child_id before saving and it is allowed in creation action
			this.addExistingChild(id,$(srcElement));
			return
			}
			if(inherit_parent.length>0){ // if inherit parent field name values contains, append all values before saving
				this.appendHiddenField($('#ticket_template'),'template_data[inherit_parent]',inherit_parent,'inherit-parent');
			}
			if(customMessages.edit){
				if( $('#inherit-parent').val() && $('#inherit-parent').val().length===0) {
					$('#inherit-parent').remove();
				}
			}
			if(!$('#ticket_template').hasClass('edit_child_form') && !$('#ticket_template').hasClass('clone_parent_form')){
				$('#ticket_template').find('#id').remove();
			}
			if($('#ticket_template').hasClass('clone_parent_form')){ // if form is parent clone action then append child ids before saving
				this.appendHiddenField($('#ticket_template'),'clone_child_ids',customMessages.clone_child_ids.toJSON(),'clone_child_ids');
			}
	    $('#ticket_template').submit();
	  },
	  checkDuplicate: function(srcElement){
	  	var $element =$('#helpdesk_ticket_template_name'),
          state = $element.data("state"),
          prev_access_type = $element.data("access-type"),
          access_type_val=$('input[name="helpdesk_ticket_template[accessible_attributes][access_type]"]:checked').val(),
          template_id=$element.data("template-id"),
          previousName=$element.data('template-name'),
          nameValue=$('#helpdesk_ticket_template_name').val(),
          nameChanged= (!previousName || (nameValue != previousName)),
          accesstypeChanged= (state === 'edit' && prev_access_type === 1),
          failureStatus=false,
          data = {
          	name: nameValue,
          	state: state,
          	template_id: template_id,
          },self = this;
      if(access_type_val != 1 && (nameChanged || accesstypeChanged || state === 'clone')){ 
        $.ajax({
          url: "/helpdesk/ticket_templates/verify_template_name",
          mode: "abort",
          dataType: "json",
          data: data,
          type: 'GET',
          success: function(data) {
            failureStatus = data["failure"];
            if ( failureStatus ) {
              $("#noticeajax").html(data.message).show();
							closeableFlash('#noticeajax');
							$(document).scrollTop(0); 
							failureStatus= data["failure"]
            } else {
            	self.formSubmit(srcElement)
            }
          },
        });
      } else  {
         self.formSubmit(srcElement)
      }
      // return failureStatus
	  },
		bindEvents:function(){ //bind events
			invokeRedactor('template_data_ticket_body_attributes_description_html', 'template');
			$('body')
		    .on("change.template_form",'#template_data_group_id', function(e){
		      var select_agent = $('#template_data_responder_id')[0];
		      var prev_val = select_agent.options[select_agent.selectedIndex].value;
		      $('#template_data_responder_id')
		              .html("<option value=''>...</option>");
		      $.ajax({
		        type:        'GET',
		        url: 		     prev_val == "" ? '/helpdesk/commons/group_agents/'+this.value : '/helpdesk/commons/group_agents/'+this.value+"?agent="+prev_val,
		        contentType: 'application/text',
		        success:     function(data){
		                        $('#template_data_responder_id')
		                          .html(data).trigger('change');
		                     }
		      });
		    });

		  // Need to make the code generic to handle the custom dropdown fields sections.
		  $("body")
		    .on("change.template_form",'#template_data_ticket_type', function(e){
		      var id = $("option:selected", this).data("id");
		      $('ul.ticket_section').remove();
		      var element = $('#picklist_section_'+id).parent();
		      if(element.length != 0) {
		        element.append($('#picklist_section_'+id).val()
		                .replace(new RegExp('&lt', 'g'), '<')
		                .replace(new RegExp('&gt', 'g'), '>'));
		      }
		  }).trigger("change");
		  //TODO - Change to a generic truncate function.
		  $('.invalid_attachment a').livequery(function(e){
		  	var srcElement = e.target || e.srcElement;
		    $(srcElement).text($(srcElement).text().substring(0,19)+"...");
		  }.bind(this));

			// Event for searching child template list
			$('body').on('keyup.template_form', '#filter-template', function(e){
	      e.stopPropagation();
	      var isKeyAllowed = this.checkAllowedKeys(e.keyCode);
	      if(isKeyAllowed){
	        debounce(this.loadAllChildTemplate('keypress'), 10000);
	      }
	    }.bind(this));
	    // Event for clicking on child template list
	    $("body").on('click.template_form', '#template-wrapper li', function(event){
	    	var src = event.srcElement || event.target,curElem = $(src);
	    	this.changeTemplate(curElem);
	    }.bind(this));
	    //Event for clicking document to close the child template popup
	    $('body').on('click.template_form', function(event){
	      var src = event.srcElement || event.target;
	      var srcEle = $(src).attr('id');
	      if($('#template-wrapper').hasClass('active') && srcEle !== "child_template_existing" && srcEle !== "filter-template"){
	        $("#template-wrapper").removeClass('active');
	      }
	    }.bind(this));
	    // Event for change event for selecting template type
			$("body").on('change.template_form',"input[name=child_template]",function(e){
				var status,value;
				this.clearData();
				var srcElement = e.target || e.srcElement;
				if($(srcElement).val() === customMessages.new){
					status = false;
					$('#ticket_template').attr("action", "/helpdesk/ticket_templates");
					$('#ticket_template .hidden_upload').show();
					$("#filter-template").val("");
					$('#id').val('');
					$('.child-existing-select').addClass('hide').val('')
					this.localStorageProcess('remove',customMessages.existing,'');
					this.childExistingChange(status,'');
					$('#helpdesk_ticket_template_name').val('').attr('disabled',status);
					if($("#template-wrapper").is(':visible'))
						$("#template-wrapper").removeClass('active');
				}else{
					this.openTemplate(true);
				}
			}.bind(this));
			$('body').on('click.template_form','.existing_template',function(e){
				var srcElement = e.target || e.srcElement;
				if($(srcElement).parent().find('#child_template_existing').prop('disabled') !== 'disabled'){
					this.openTemplate(true);
					$(srcElement).parent().find('input[type=radio]').prop('checked',true);
					return false;
				}
			}.bind(this));
			/* Individual field hover effect starts */
			$('body').on('mouseenter','.template-ticket-fields li.field',function(e){
				$(this).find('.options-wrapper').show();
			});
			$('body').on('mouseleave','.template-ticket-fields li.field',function(e){
				$(this).find('.options-wrapper').hide();
			});
			/* Individual field hover effect end */
			
			// Event for clicking on inherit individual field parent button
			$('body').on('click.template_form','.parent-btn',function(event){
				event.preventDefault();
				event.stopPropagation();
				var ele=event.srcElement || event.target,$element=$(ele);
				if(!$element.hasClass('ficon-undo-inherit')){
					$element.removeClass('ficon-inherit-parent').addClass('ficon-undo-inherit').parent().addClass('parent-change');
					this.enableOrDisableFields(true,ele,'parent-btn');
					$element.prop('data-original-title',customMessages.undo_inherit_tooltip);
				}else{
					$element.removeClass('ficon-undo-inherit').addClass('ficon-inherit-parent').parent().removeClass('parent-change')
					this.enableOrDisableFields(false,ele,'parent-btn');
					$element.prop('data-original-title',customMessages.inherit_tooltip);
				}
			}.bind(this));
			// Event for clicking on insert placeholder
			$('body').on('click.template_form','.insert_placeholder',function(e){
				e.preventDefault();
				var srcElement = e.target || e.srcElement;
				if(!$(srcElement).attr('disabled')){
					$('#place-dialog').slideDown('fast', function(){
		    			$(srcElement).groupPlaceholders();
					});
				}
			}.bind(this));
			// Event for clicking on inherit all values from parent ticket
			$('body').on('click.template_form','.inherit_parent',function(e){
				e.preventDefault();
				e.stopPropagation();
				var self=this;
				var srcElement = e.target || e.srcElement;
				if(!$(srcElement).attr('disabled')){
					var dataInheritAll=$('.inherit_parent').attr('data-inherit-all');
					if(dataInheritAll==='false'){
						self.inheritAllParent();
					}else{
						$('.inherit_parent').attr({'data-inherit-all':false,'data-original-title':customMessages.insertParent})
							.removeClass('ficon-undo-inherit').addClass('ficon-inherit-parent').parent().removeClass('parent-change');
						$('.inherit_parent_label').text(customMessages.insertParent);
						self.clearData();
						self.enableDisableAllFields(false);
						self.editResetAllFields();
						$('.insert_placeholder').attr('disabled',false);
						$('input[name="child_template"]').attr('disabled',false);
						$('.parent-btn').removeClass('ficon-undo-inherit parent-disabled')
							.addClass('ficon-inherit-parent').prop('disabled',false).parent().removeClass('parent-change');
						if(oldValues.template_data && oldValues.template_data.inherit_parent){
							if(customMessages.edit && customMessages.inheritParentFields && customMessages.inheritParentFields.indexOf('all') === -1){
								setTimeout(function(){
									self.initializeEditInheritFeild(customMessages.inheritParentFields);
									self.changeInheritParentID();
								},1000)
								return;
							}
						}
						$('#inherit-parent').remove();
					}
				}
			}.bind(this));
			// Event for name field blur event to change name in parent list side bar
			$('body').on('blur.template_form','#helpdesk_ticket_template_name',function(e){
				var srcElement = e.target || e.srcElement, value=$(srcElement).val()?$(srcElement).val():'No Name';
				if($(srcElement).hasClass('new_child_name')){
					$('.parent-li ul li:last-child .edit').html("<i class='ficon-pencil'></i>"+value)
				}else if($(srcElement).hasClass('edit_parent_name')){
					$('.parent-li').find('.edit a').text(value);
				}else{
					$('.parent-li ul li').find('.edit a').text(value)
				}
			}.bind(this));
			// Event for clicking delete template to open delete confirmation popup
			$('body').on('click.template_form','.delete-template',function(e){
				e.preventDefault();
				var srcElement = e.target || e.srcElement;
				var modalName=$(srcElement).attr('data-controls-modal'),confirmClassName;
				$('#'+modalName).modal('show')
				confirmClassName= (modalName === 'edit-delete-template') ? 'edit-delete-confirm' : 'child-delete-confirm';
				$('.'+confirmClassName).attr('href',customMessages.deletePath);
			}.bind(this));
			// Event for clicking delete template to open delete confirmation popup
			$('body').on('click.template_form','.index-delete-template',function(e){
				e.preventDefault();
				var modalName,$el = $(this),$element,deleteMessage;
				$element= ($el.prop('tagName').toLowerCase()=== 'i') ? $el.parent() : $el;
				modalName=$element.data('controls-modal');
				deleteMessage= ($element.data('parent'))? customMessages.parentTemplateMsg : customMessages.normalTemplateMsg;
				$('#' + modalName).modal('show');
				$('#'+ modalName + ' .modal-body').html(deleteMessage);
				$('.index-delete-confirm').attr('href',$element.data('delete-url'));
			});
			// Event for clicking unlink template to open unlink confirmation popup
			$('body').on('click.template_form','.unlink-template',function(e){
				e.preventDefault();
				$('#edit-unlink').modal('show');
				$('.unlink-confirm').attr('href',customMessages.unlinkPath);
			}.bind(this));
			/* Event for clicking on page redirection confirmation action starts */
			$('body').on('click.template_form','.statusbar-redirect',function(e){ // open confirmation popup for redirection
				e.preventDefault();
				this.compareData();
				var srcElement = e.target || e.srcElement;
				if($('#ticket_template.ticket_template_form').data('formChanged')){
					if($('#toggle-confirm').length>0){
						$('#toggle-confirm').modal('show');
		        $('.proceed_anyway').attr('href',$(srcElement).attr('href'));
		       } 
				}else {
					window.location.href=$(srcElement).attr('href');
				}
			}.bind(this));
			$('body').on('click.template_form', '.proceed_anyway',function(e) { // redirect to selected page
				e.preventDefault();
				var srcElement = e.target || e.srcElement;
				$('#ticket_template.ticket_template_form').data('formChanged', false);
				$('#toggle-confirm').modal('hide');
				window.location.href=$(srcElement).attr('href');
			}.bind(this));
			$('body').on('click.template_form','.take_back',function(e){ // stay back in same page
				e.preventDefault();
				e.stopPropagation();
				$('.form_btn').attr('disabled',false);
				$('#toggle-confirm').modal('hide');
			}.bind(this));
			/* Event for clicking on page redirection confirmation action end */

			// Event for change in ticket template form
			$('body').on('change.template_form','#ticket_template.ticket_template_form',function(e){
				// e.stopPropagation();
				this.compareData();
			}.bind(this));
			// Event for open canned response popup
			$('body').on('click.template_form', '.template_form a[rel="ticket_canned_response"]', function(ev){
				ev.preventDefault();
				$("#canned_response_show").attr('data-tiny-mce-id', "#helpdesk_ticket_ticket_body_attributes_description_html");
				$('#canned_response_show').trigger('click');
			}.bind(this));
			// Event for removing child from parent list in clone parent action
			$('body').on('click.template_form','.clone-remove',function(e){
				var srcElement = e.target || e.srcElement,$currentEle=$(srcElement), childId=$currentEle.data('child-id').toString(),lastEle,$parentEle=$currentEle.closest('li'),className=$parentEle.attr('class'),notFound= -1;
	      switch(true){
	      	case className.indexOf('child-first-li') !== notFound:
	      		lastEle=$parentEle.next().addClass('child-first-li')
	      		break;
	      	case className.indexOf('child-last-li') !== notFound:
	      		lastEle=$parentEle.prev();
	      		break;
	      	default:
						break;
	      }
	      $currentEle.data('twipsy').hide();
	      $parentEle.remove();
	     	if(customMessages.clone_child_ids.indexOf(childId) != notFound){
					customMessages.clone_child_ids.splice(customMessages.clone_child_ids.indexOf(childId),1)
					if(customMessages.clone_child_ids.length < 6){
						$('.child-title').text(customMessages.clone_child_title+ " ( " +customMessages.clone_child_ids.length +" )");
						if(customMessages.clone_child_ids.length === 1)
							lastEle.addClass('nochild-last-li')
					}
					else
						$('.child-title').text(customMessages.clone_child_title+ " ( " +customMessages.clone_child_ids.length +" / "+ customMessages.clone_child_max_Count +")");
				}
	    }.bind(this));
	    // Event for form submit action
	    $('body').on('click.template_form','.form_btn',function(e){
	    	var srcElement = e.target || e.srcElement;
				if(($(srcElement).prop("tagName")==='A')) {
					this.disableBtnFields(true);
					return;
				} // return if button is not submit action
				e.preventDefault();
				var formValid=$('#ticket_template').valid() && $('#helpdesk_ticket_template_name').valid();
				if(formValid){
					this.checkDuplicate(srcElement);
				}
		  }.bind(this));

		  // enable save and cancel button action on popup close event
		  $('.modal').on('hidden.bs.modal', function (e) {
			   if($('.form_btn').attr('disabled') === 'disabled'){
			   	 $('.form_btn').attr('disabled',false);
			   }
			}.bind(this))
		}

	};
}(window.jQuery));



// DEBOUNCE technique based on underscore
function debounce(func, wait, immediate) {
	var timeout;
	return function() {
		var context = this, args = arguments;
		var later = function() {
			timeout = null;
			if (!immediate) func.apply(context, args);
		};
		var callNow = immediate && !timeout;
		clearTimeout(timeout);
		timeout = setTimeout(later, wait);
		if (callNow) func.apply(context, args);
	};
};