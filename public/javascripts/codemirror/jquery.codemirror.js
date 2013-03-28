/*
 * @author venom
 * Code mirror jquery adaptor to handle codemirror as an direct object association
 * The below Advanced features are added through this adaptor
 * - fullscreen
 */

!function( $ ) {

	"use strict"

	/* CODEMIRROR PUBLIC CLASS DEFINITION
	* ============================== */

	var Codemirror = function (element, options) {
		this.$element = $(element)
		this.options = $.extend({}, $.fn.codemirror.defaults, options, this.$element.data())

		if(this.options['editFullscreen']){
			this.options['extraKeys'] = {
		        "Shift-Cmd-F": function(cm) {
		        	jQuery(cm.getTextArea()).codemirror("showFullscreen")
		        }
			,   "Shift-Ctrl-F": function(cm) {
		        	jQuery(cm.getTextArea()).codemirror("showFullscreen")
		        }
		    ,   "Esc": function(cm) {
		        	jQuery(cm.getTextArea()).codemirror("hideFullscreen")
		        }
		    ,   "Cmd-S" : function(cm) {
		    		jQuery('input[name="save_button"]:visible')[0].click();
		    	}
		    ,   "Ctrl-S" : function(cm) {
		    		jQuery('input[name="save_button"]:visible')[0].click();
		    	}
		    ,   "Shift-Cmd-P" : function(cm) {
		    		jQuery('input[name="preview_button"]:visible')[0].click();
		    	}
		    ,   "Shift-Ctrl-P" : function(cm) {
		    		jQuery('input[name="preview_button"]:visible')[0].click();
		    	}
		    }
		}

		this.$editor = CodeMirror.fromTextArea(element, this.options)
		this.$editor.getScrollerElement().style.height = this.options['height'] || ""
		this.$editor.refresh()
		
		if(this.options['editFullscreen']){
			var _fullscreen = $("<i class='cm-fullscreen'></i>")
									.on("click", function(ev){
										$(element).codemirror("toggleFullscreen")
									})

			$(this.$editor.getWrapperElement()).prepend(_fullscreen)
		}
	}

	Codemirror.prototype = {

		editor: function(){
			return this.$editor
		}
	,  	resizeInFullscreen: function(){
			var _h1 = $("#cm-fs-wrapper h3").height(),
				_h3 = $("#cm-fs-wrapper").height()

			this.$editor.getScrollerElement().style.height = (_h3 - (_h1 + 65)) + "px"
		}
	,	buildFullscreen: function(cm){
			var wrap = cm.getWrapperElement(), 
				scroll = cm.getScrollerElement(),
				wrap_action_group = $(this.$element.data("fullscreenActions")).find("input, a")

			if(!document.getElementById("cm-fs-editor")){
				$("<div id='cm-fs-wrapper' class='hide' />")
					.appendTo("body")
					.append("<h3 />")
					.append("<div id='cm-fs-editor'>")
					.append("<div id='cm-fs-actions'><div class='cm-well'></div></div>")
			}

			$("#cm-fs-wrapper h3").html(this.$element.data("fullscreenTitle") || "Editing in fullscreen")

			$("#cm-fs-actions .cm-well").empty();
			$.each(wrap_action_group, function(i, item){
				$(item)
					.clone()
					.appendTo("#cm-fs-actions .cm-well")
					.on("click", function(ev){
						$(item).trigger("click")
					})
			})

			$(wrap).detach().appendTo("#cm-fs-editor")

			$("#cm-fs-wrapper").show()
			this.resizeInFullscreen()
		}
	,	showFullscreen: function(){
			var cm = this.$editor,
				wrap = cm.getWrapperElement(), 
				scroll = cm.getScrollerElement()
				
			if (!$(wrap).data("fullscreen")) {
				$(wrap).addClass("CodeMirror-fullscreen")
				$(wrap).data("fullscreen", true)
				$(scroll).data("oldHeight", scroll.style.height)

				this.buildFullscreen(cm)

				$(document).data("fs-codemirror", this.$element)

				document.documentElement.style.overflow = "hidden"
			}

			window['codemirror-fullscreen'] = true
			cm.refresh()
			cm.focus()
		}
	,	hideFullscreen: function(){
			var cm = this.$editor,
				wrap = cm.getWrapperElement(), 
				scroll = cm.getScrollerElement()

			if(jQuery(wrap).data("fullscreen")) {
				$(wrap).removeClass("CodeMirror-fullscreen")
				$(wrap).data("fullscreen", false)
				scroll.style.height = $(scroll).data("oldHeight")
				document.documentElement.style.overflow = ""
				$(cm.getTextArea()).after($(wrap).detach())
				jQuery("#cm-fs-wrapper").hide()
				$(document).data("fs-codemirror", false)
			}

			window['codemirror-fullscreen'] = false
			cm.refresh()
			cm.focus()
		}
	,	toggleFullscreen: function(){
			if(jQuery(this.$editor.getWrapperElement()).data("fullscreen"))
				this.hideFullscreen()
			else
				this.showFullscreen()
		}
	,	refresh: function(){
			this.$editor.refresh()
		}
	, save: function(){
			this.$editor.save()
		}
	}

	/* CODE MIRROR PLUGIN DEFINITION
	* ======================= */

	$.fn.codemirror = function (option) {
		return this.each(function () {
			var $this = $(this)
			, data = $this.data('codemirror')
			, options = typeof option == 'object' && option

			if (!data) $this.data('codemirror', (data = new Codemirror(this, options)))

			if (typeof option == 'string') data[option]()

		})
	}

	$.fn.codemirror.defaults = {
	    lineNumbers 	: true,
      	mode      		: "liquid", 
      	theme       	: 'textmate',
      	tabMode   		: "indent",
      	gutter      	: true,
      	editFullscreen 	: true      	
	}

	$.fn.codemirror.Constructor = Codemirror

	// !PORTALCSS Code mirror scripts to be moved into seperate codemirror util file
	$(document).ready(function(){
	  CodeMirror.connect(window, "resize", function() {
	  	if($(document).data("fs-codemirror"))
	    	$(document).data("fs-codemirror").codemirror("resizeInFullscreen");
	  });  
	})

}(window.jQuery);