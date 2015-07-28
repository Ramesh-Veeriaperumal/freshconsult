(function($){
	"use strict";
    window.CustomFieldDialog  = function(options){
    	var defaults = {
			currentData: 					null,
			customPropsModal: 				'#CustomPropsModal',
			dialogContainer: 				'#CustomFieldsPropsDialog',
			customPropertiesDiv: 			'#CustomProperties',
			cancelBtn: 						'#cancel-btn',
			propsSubmitBtn: 				'#PropsSubmitBtn',
			validateOptions: 				{}
			};
    	this.options = $.extend(true, {}, defaults, options);
    	this.element = null;
    	this.instance = null;
    	this.init();
    }
    CustomFieldDialog.prototype = {
    	init: function(){
	    	$(document).on('hidden.custom-fields', '.modal', $.proxy(function(e){
				if($(e.target).attr('id') == this.options.customPropsModal.slice(1)) {
					this.closeDialog();
				}
			}, this) );
			$(document).on('click.custom-fields', this.options.cancelBtn, $.proxy(function(e) {
				this.hideDialog();
			}, this) );
			$(document).on('click.custom-fields', this.options.propsSubmitBtn, $.proxy(function(){
				$(this.options.customPropertiesDiv).submit();
			}, this) );
			$(document).on('keypress.custom-fields', this.options.customPropertiesDiv + " input", $.proxy(function(e) {
				e.stopPropagation();
				var keyCode = e.which || e.keyCode || e.charCode;
				// To save the properties on pressing enter
				if(keyCode == 13) {
					$(this.options.customPropertiesDiv).submit();
				}
			}, this) );

			$(this.options.customPropertiesDiv).live('submit',function(){ return false; });

			this.options.validateOptions = {
				submitHandler: $.proxy(function(form){
					// console.log(form);
					this.options.currentData = this.setCurrentData();
					$(this.element).removeClass('active');
					$.event.trigger('customDataChange', this.options.currentData);
					this.hideDialog();
				}, this),
				rules: {},
				messages: {},
				onkeyup: false,
				onclick: false,
				ignore: ":hidden"
		 	};
	    },
		show: function(element, attachEvents, picklistIds){
			this.element = element;
			// this.options.currentData = $(this.element).data("raw");
			this.instance = $(this.element).data('customfield');
			this.options.currentData = this.instance.getProperties();
			$( this.element ).addClass("active");
			$(this.options.dialogContainer).html(JST['custom-form/template/formfield_props']({obj:this.options.currentData, picklistIds: picklistIds}));

			this.options.validateOptions = $.extend(true, {}, this.options.validateOptions, $(this.element).data('customfield')['getValidationRules']())
			$(this.options.customPropertiesDiv).validate(this.options.validateOptions);
			
			$.proxy(attachEvents, this.instance)();
			$(this.options.customPropsModal).modal('show');
		},
		setCurrentData: function(){
			$(this.element).data("fresh", false);
			return $(this.element).data('customfield')['setProperties']();
		},

		closeDialog: function(e) {
			if($(this.element).data("fresh")) {
				$(this.element).remove(); 
			}
			$( this.element ).removeClass('active');
			this.detachEvents();
		},

		detachEvents: function() {
			$(document).off('click.dialog-events')
						.off('keyup.dialog-events')
						.off('change.dialog-events');
		},

		hideDialog: function(){ 
			$(this.element).removeClass('active');
			$(this.options.customPropsModal).modal('hide');
		},
			
   		destroy: function() {
			return this.each(function() {
				$(this).removeData('customFieldDialog');
			});
		}
  };
})(window.jQuery);