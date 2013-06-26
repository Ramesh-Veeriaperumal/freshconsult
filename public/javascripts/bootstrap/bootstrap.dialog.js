// !PATTERN
// OnDemand dialog wrapper for Bootstrap modal 
// This will have the default markup example as the wrapper-template

!function( $ ) {

	"use strict"

	/* DIALOG PUBLIC CLASS DEFINITION
	* ============================== */

	var Freshdialog = function (element, options) {
		this.$element = $(element)

		this.options = $.extend({}, $.fn.freshdialog.defaults, options, this.$element.data())		

		// Removing the hash in-front of the target
		this.$dialogid = this.options.targetId.substring(1)

		// Getting static content id and dom if it is present in the document
		this.$content = $((/#/.test(element.href) ? element.href : this.options.targetId))
		// Building the base wrapper for the modal dialog
		this.$dynamicTarget = $('<div class="modal fade" role="dialog" aria-hidden="true"></div>')
									.attr('id', this.$dialogid)
									.addClass(this.options.classes) // Adding classes if send via options
									.css({ 
											"width": this.options.width
										,	"marginLeft": -(parseInt(this.options.width)/2)
									})
									.appendTo('body') // Appending to the end of the body														
        
        if(this.options.templateHeader != ""){
        	// Title for the header        
        	this.dialogTitle = element.getAttribute('title') || this.options.title

	        // Setting modal dialogs header and its title
	    	this.$dynamicTarget
	    			.append(this.options.templateHeader)
					.find(".modal-title")
					.attr("title", this.dialogTitle)
					.html(this.dialogTitle)
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
								this.options.closeLabel + '</a>')
			this.$submitBtn = $('<a href="#" data-submit="modal" class="btn btn-primary" data-toggle="button">' +
								this.options.submitLabel + '</a>')
			if(this.options.submitLoading != "") {
				this.$submitBtn.data('loadingText',this.options.submitLoading )
			}

			this.$footer = $(this.options.templateFooter)
							.append(this.$closeBtn).append(this.$submitBtn)
							.appendTo(this.$dynamicTarget)
		}

		// Delegating the click for a submit button
 		this.$dynamicTarget
 			.delegate('[data-submit="modal"]', 'click.submit.modal', $.proxy(this.formSubmit, this))
	}

	Freshdialog.prototype = {
		constructor: Freshdialog
		// To submit the first form inside the modal dialog
	,	formSubmit: function(e){
			e && e.preventDefault()

			var form = this.$dynamicTarget.find('form:first')

			if(form.get(0)){
				if(this.options.submitLoading != "") this.$submitBtn.button('loading');
					form.submit();
			} 
		}
	}

	/* DIALOG PLUGIN DEFINITION
	* ======================= */

	$.fn.freshdialog = function (option) {
		return this.each(function () {			
			var $this = $(this)
			, data = $this.data('freshdialog')
			, options = typeof option == 'object' && option

			if (!data) $this.data('freshdialog', (data = new Freshdialog(this, options)))

			if (typeof option == 'string') data[option]()
		})
	}

	$.fn.freshdialog.defaults = {
	  	width: 		"710px",
		title: 		'',
		classes: 	'',
		keyboard: 	true, 
		templateHeader: '<div class="modal-header">' +
							'<button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>' +
							'<h3 class="ellipsis modal-title"></h3>' +
						'</div>',
		templateBody:	'<div class="modal-body"><div class="sloading loading-small loading-block"></div></div>',
        templateFooter: '<div class="modal-footer"></div>',
        submitLabel: 	"Submit",
        submitLoading: 	"", 
        closeLabel: 	"Close"
	}

	$.fn.freshdialog.Constructor = Freshdialog

	$(document).on('click.freshdialog.data-api', '[rel="freshdialog"]', function (e) {
	    e.preventDefault()

	    var $this = $(this)
	    ,  	href = $this.attr('href')

	    if ($this.data('lazyload')) {
	    	var content = $($this.data('target') + ' textarea[rel=lazyload]').first().val()
	    	$($this.data('target')).hide().html(content)
	    }

	    // creating the dialog through the api
	    if(!$this.data('freshdialog')){
	    	$(this).data("targetId", ($this.attr('data-target') || 
	    		(href && href.replace(/.*(?=#[^\s]+$)/, ''))))
	    	$this.freshdialog($this.data())
	    }

	    var $target = $($(this).data("targetId"))
	    var	option = $target.data('modal') ? 'toggle' : $.extend({ remote:!/#/.test(href) && href }, $target.data(), $this.data())

	    $target
			.modal(option);
			// .one('hide', function () {
			// 	$this.focus()
			// })

	  })

}(window.jQuery);