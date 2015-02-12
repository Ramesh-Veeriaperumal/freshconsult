(function($) {

	//Script for autosaving content of a DOM element on change at a particular interval
	var autoSaveContent = function (options) {
		this.initialize(options);
	}

	autoSaveContent.prototype = {
		constructor: autoSaveContent,

		contentChanged: false,
		savingContentFlag: false,

		//Default options
		opts: {
			autosaveInterval: 30000,
			autosaveUrl: window.location.pathname,
			monitorChangesOf: {
				description: ".redactor_editor",
				title: "#solution_article_title"
			},
			livestampContainer: ".autosave-time-stamp",
			livestampPreText: "Saved ",
			livestampPreTextDiv: ".autosave-pre-text"
		},

		initialize: function(options) {
			var $this = this;
			this.opts = $.extend(this.opts, options);
			$(document).ready(function() {
				$this.bindEvents();
				$this.autoSaveTrigger();
			});
		},
		
		bindEvents: function() {
			var $this = this;
			$.each(this.opts.monitorChangesOf, function(key, value){
				$(value).bind("keyup DOMNodeInserted DOMNodeRemoved",function(){
		    	console.log("Content changed."+key);
		    	$this.contentChanged = true;
		    });
			});
		},

		getContent: function() {
			var $this = this;
			this.content = {};
			$.each(this.opts.monitorChangesOf, function(key, value){
				$this.content[key] = $(value).html() || $(value).val();
			});
			this.contentChanged = false;
			this.savingContentFlag = true;
			this.saveContent();
		},

		autoSaveTrigger: function() {
			var $this = this;
			window.setInterval(function(){
					if($this.contentChanged) {
						$this.getContent();
					}
				}, this.opts.autosaveInterval);
		},

		saveContent: function() {
			var $this = this;
			$.ajax({
				url: $this.opts.autosaveUrl,
				type: 'POST',
				data: {draft_data: $this.content},
				success: function(response) {
					if(response == "Success"){
						console.log('Saved the draft succesfully');
						jQuery($this.opts.livestampContainer).livestamp();
						jQuery($this.opts.livestampPreTextDiv).html($this.opts.livestampPreText);
						$this.contentChanged = false;	
					} else {
						console.log('Saving Failed.');
						console.log(response);
					}
					$this.savingContentFlag = false;
				}
			})
		}
	}

	/* Autosave PLUGIN Definiton */

	$.autoSaveContent = function (options) {
		var savecontent = new autoSaveContent(options);
	}

})(window.jQuery);