// !PATTERN
// OnDemand dialog wrapper for Bootstrap modal 
// This will have the default markup example as the wrapper-template

!function( $ ) {

	"use strict"

	/* DIALOG PUBLIC CLASS DEFINITION
	* ============================== */

	var Freshdialog = function (element, options, title) {	
		var data = {};
		if (element !== null) {
			this.$element = element;
			data = this.$element.data();
		}

		this.options = $.extend({}, $.fn.freshdialog.defaults, options, data);

		// Title Fallback for the ones with Tooltip class applied
		this.options.title = this.options.title || this.options.modalTitle;

		// Removing the hash in-front of the target
		this.$dialogid = this.options.targetId.substring(1)

		// Getting static content id and dom if it is present in the document
		this.$content = $(this.options.targetId)
		// Building the base wrapper for the modal dialog

		//RTL
		var direction = ($("html").attr("dir") == "rtl") ? 'marginRight' :'marginLeft';
		this.$placement = {
			"width": this.options.width
		};
		this.$placement[direction] = -(parseInt(this.options.width)/2);
		
		this.$dynamicTarget = $('<div class="modal fade" role="dialog" aria-hidden="true"></div>')
									.attr('id', this.$dialogid)
									.addClass(this.options.classes) // Adding classes if send via options
									.css(this.$placement)
									.appendTo('body') // Appending to the end of the body														
        
        if(this.options.templateHeader != ""){
        	// Title for the header        
        	this.dialogTitle = title || this.options.title;

        // Setting modal dialogs header and its title
	    	this.$dynamicTarget
		    		.append(this.options.templateHeader)
						.find(".modal-title")
						.attr("title", this.dialogTitle)
						.html(this.dialogTitle)

			// Setting close link for the dialog
			if(this.options.showClose == true)
        	   this.$dynamicTarget
        			.find(".modal-header")
        			.prepend('<button type="button" class="close" data-dismiss="modal" aria-hidden="true"></button>')
		}

        // Setting up content body 
        this.$body = $(this.options.templateBody)
        // Using static content body if its present in the dom
		if(this.$content.get(0)){
			this.$body
				.html(this.$content.attr("id", "").show())
				.attr("id", this.$dialogid + "-content")
		}
		this.$dynamicTarget.append(this.$body)

		// Building the footer content
		if(this.options.templateFooter != ""){
			this.$closeBtn = $('<a href="#" data-dismiss="modal" class="btn">' +
								this.options.closeLabel + '</a>').attr('id', this.$dialogid + '-cancel')
			this.$submitBtn = $('<a href="#" data-submit="modal" class="' + this.options.submitClass + '">' +
								this.options.submitLabel + '</a>').attr('id', this.$dialogid + '-submit')
			if(this.options.submitLoading != "") {
				this.$submitBtn.data('loadingText',this.options.submitLoading )
			}

			this.$footer = $(this.options.templateFooter)
							.append(this.$closeBtn).append(this.$submitBtn)
							.appendTo(this.$dynamicTarget)
		}

		// Delegating the click for a submit button
 		this.$dynamicTarget
 			.delegate('[data-submit="modal"]:not([disabled])', 'click.submit.modal', $.proxy(this.formSubmit, this))
	}

	Freshdialog.prototype = {
		constructor: Freshdialog

		// To submit the first form inside the modal dialog
	,	formSubmit: function(e){
			e && e.preventDefault()
         var form = this.$dynamicTarget.find('form:first')       

         if(form.get(0) && form.valid()){
         	$(form).trigger("dialog:submit");
            if(this.options.submitLoading != ""){
            	this.$submitBtn.button('loading');
            }
            form.submit();
         }
      
         if(this.options.closeOnSubmit) this.$dynamicTarget.modal("hide")
		}
		// Destroy the dialog object when a close is invoked
    , 	destroy: function(e){	 
    		$(this.$body.html())
    			.appendTo("body")
    			.attr("id", this.$dialogid).hide()
    		if (this.$element !== undefined) { this.$element.removeData('freshdialog'); }
	    	this.$dynamicTarget.off("submit.modal");
	    }

	}

	/* DIALOG PLUGIN DEFINITION
	* ======================= */

	$.fn.freshdialog = function (option) {
		return this.each(function () {			
			var $this = $(this)
			, data = $this.data('freshdialog')
			, options = typeof option == 'object' && option

			if(!data) {
				$this.data('freshdialog', (data = new Freshdialog($this, options, this.getAttribute('title'))));
			}

			if (typeof option == 'string') data[option]()
		})
	}
	
	$.freshdialog = function (option) {
		var options = typeof option == 'object' && option,
			freshdialog = new Freshdialog(null, options),
			$target;
		$target = $(options.targetId);
		$target.data('freshdialog', freshdialog);
		$target.data("source", $target)
		$target.modal(options);
		return(freshdialog);
	}

	$.fn.freshdialog.defaults = {
	  	width: 				"710px",
		title: 				'',
		classes: 			'',      
      	closeOnSubmit: 		false,
		keyboard: 			true, 
		templateHeader: 	'<div class="modal-header">' +
								'<h3 class="ellipsis modal-title"></h3>' +
							'</div>',
		templateBody:		'<div class="modal-body"><div class="sloading loading-small loading-block"></div></div>',
	    templateFooter: 	'<div class="modal-footer"></div>',
	    submitLabel: 		"Submit",
	    submitClass: 		"btn btn-primary", 
	    submitLoading: 		"", 
	    closeLabel: 		"Close",
	    showClose: 			true,
	    destroyOnClose: 	false
	}

	$.fn.freshdialog.Constructor = Freshdialog

	$(document).on('click.freshdialog.data-api', '[rel="freshdialog"]', function (e) {
	    e.preventDefault()

	    var $this = $(this)
	    ,  	href = $this.attr('href')

	    if($this.data('lazyload')) {
	    	var content = $($this.data('target') + ' textarea[rel=lazyload]').first().val()
	    	$($this.data('target')).hide().html(content)
	    }

	    // creating the dialog through the api
	    if(!$this.data('freshdialog')){
	    	var targetId = $this.attr('data-target') || (href && href.replace(/.*(?=#[^\s]+$)/, ''));
	    	$this.data("targetId", targetId);
	    	$this.freshdialog();

	    	if($this.data("group")){
	    		var $objGroup = $("[data-group="+$this.data("group")+"]");

	    		$objGroup.data({ "targetId": targetId, 
	    						 "freshdialog": $this.data('freshdialog') });
	    	}
	    }

	    var $target = $($(this).data("targetId"))
	    var	option = $target.data('modal') ? 'toggle' : $.extend({ remote:!/#/.test(href) && href }, $target.data(), $this.data())

	    $target.data("source", $this)

	    if(!$target.data('modal')){
	    	$target.modal(option);
	    }else{
	    	$target.modal("toggle");
	    }
	})

}(window.jQuery);