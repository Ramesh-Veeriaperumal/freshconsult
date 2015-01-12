
!function( $ ) {

	"use strict"

	/* CONFIRM DELETE PUBLIC CLASS DEFINITION
	* ============================== */

	var Confirmdelete = function (element) {
		if (element === null) {
			return false;
		}

		this.$element = element;
		this.data = this.$element.data();

		this.constructForm();
		this.constructDialog();
	}

	Confirmdelete.prototype = {
		constructor: Confirmdelete,

		constructForm: function() {
			this.createForm();
			this.appendInputs();
			this.appendDetails();
			this.bindHandlers();
		},

		constructDialog: function() {
			if (this.checkParentDiv()){
				this.createModalDiv();
			}
			this.triggerDialog();
		},

		createForm: function() {
			this.form = $('<form />').attr('id', this.data.dialogId + '-form').
									attr('class', 'delete-confirm-form').
									attr('action', this.data.destroyUrl ).attr('method', 'POST');;
		},

		appendInputs: function() {
			// To ensure this seen as DELETE method by RAILS
			this.form.append($('<input />').attr('type', 'hidden').attr('name', '_method').attr('value', 'delete'));

			this.text_input = $('<input />').attr('name', 'verify_title').attr('placeholder', this.data.itemTitle).
										attr('type', 'text').attr('autocomplete', 'off').attr('id', 'check-title_'+this.data.dialogId);

			this.form.append(this.text_input);
		},

		appendDetails: function() {
				this.form.prepend($('<p />').html(this.data.deleteTitleMsg));
				this.form.append($('<p />').html(this.data.deleteMsg));
		},

		bindHandlers: function() {
			this.form.on('submit.delete_confirm', $.proxy(this.handleSubmit, this));
			this.text_input.on('keyup.delete_confirm', $.proxy(this.handleKeyup, this));
		},

		handleSubmit: function () {
			return this.checkTitle();
		},

		handleKeyup: function () {
			this.btnToggle(!(this.checkTitle()));
		},

		checkParentDiv: function(){
			return ($("#"+this.data.dialogId).length == 0) ;
		},

		triggerDialog: function(){
			this.data['targetId'] = "#" + this.data.dialogId;
			$.freshdialog(this.data);
			this.hideSubmitInitial();
		},

		createModalDiv: function(){
			this.createParentDiv();
			this.createContextDiv();
			this.appendContextDetails();
		},

		createParentDiv: function(){
			this.parent_div = $('<div />').attr('id', 'delete_confirm_dialogs').appendTo('body');
		},

		createContextDiv: function(){
			this.context_div = $('<div />').attr('id', this.data.dialogId).addClass("hide");
		},

		appendContextDetails: function(){
			this.createWarningDiv();
			this.context_div.append(this.warning_div).append(this.form);
			this.parent_div.append(this.context_div);
		},

		createWarningDiv: function(){
			this.warning_div = $('<div />').attr('class', 'delete-confirm-warning');
			var warning_msg = $('<div />').attr('class', 'delete-confirm-warning-message').
												append($('<p />').html(this.data.warningMessage+"<br/>"+this.data.detailsMessage));
			var warning_icon = $('<div />').attr('class', 'delete-confirm-warning-icon delete-notice');
			this.warning_div.append(warning_icon).append(warning_msg);
		},

		checkTitle: function(){
			return this.text_input.val().substring(0,5).toLowerCase() == this.data.itemTitle.substring(0,5).toLowerCase();
		},

		show: function() {
			$('#' + this.$element.data('dialog-id')).modal('show');
		},

		btnToggle: function(flag) {
			this.animateToggle(flag);
			var data = this.data;
			if (this.previous_flag != flag){
				setTimeout(function() {
						$("#"+data.dialogId+"-submit").toggleClass('hide', flag);
					}, (flag? 100: 10));
				this.previous_flag = flag;
			}
		},

		animateToggle: function(flag){
			var animate_submit = ['btnFadeIn', 'btnFadeOut'];
			if (this.previous_flag != flag){
				$("#"+this.data.dialogId+"-submit").removeClass(animate_submit[(flag? 0:1)]).addClass(animate_submit[(flag? 1:0)]);
			}
		},

		hideSubmitInitial: function() {
			$("#"+this.data.dialogId+"-submit").addClass('hide');
		}
	}

	/* CONFIRM DELETE PLUGIN DEFINITION
	* ======================= */

	$.fn.confirmdelete = function (option) {
		return this.each(function () {			
			var $this = $(this),
					obj = $this.data('confirmdelete')
			if(!obj) {
				$this.data('confirmdelete', (obj = new Confirmdelete($this)));
			} else {
				obj.show();
			}
		})
	}

	$.fn.confirmdelete.Constructor = Confirmdelete

	$(document).on('click.freshdialog.data-api', '[rel="confirmdelete"]', function (e) {
	    e.preventDefault()
	    var $this = $(this)
	    $this.confirmdelete();
	})

}(window.jQuery);