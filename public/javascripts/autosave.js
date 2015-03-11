/* Autosave Plugin

Quick Documentation Details
-----------------------------------------------------------------------------------------------------------------------
Dependency : jQuery
Starts with intialization of Options
Options are 
1. autoSaveInterval
		This expects time  interval in milliseconds. Each autosave action will be performed in this time interval
		if the content of any of the elements specified in ;monitorChengesOf' changes.
2. autosaveUrl
		The data will submitted as POST to the url specified here.
3. monitorChnagesOf
		This expects a hash. The key of the hash will specify the name of the parameter while sending to server and
		the value of the hash expects the DOM element ID or class[which has to be unique] to be monitored for changes.
		eg: { description: "#my_article_description", title: ".my_article_title" }
				This means it will send the below object
					{ "draft_data" => { 
															"description" => content of "my_article_description"[id] element
															"title" => content of "my_article_title"[class] element
														}
					} 
				as POST in autosave action in the specified time interval only if the content of either one of them changes.
4. extraParams
		This expects a hash. If you want some other extra params to be send to backend along with the data in the 
		specified DOM elements, you can specify it here. This hash will be send along with the other specified DOM 
		element data and if the response contains any JSON with a key matching any key in extraParams, that keys 
		value will be updated as well. And next time this updated value will be send to the server.
5. responseCallback
		This expects a function with a single parameter. This will be called after each autosave action with the response
		recieved from the server.

*/

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
			extraParams: {},
			responseCallback: function(){}
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
			if(!$.isEmptyObject(this.opts.extraParams)){
				$.each(this.opts.extraParams, function(key, value){
					$this.content[key] = value;
				});
			}
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
			console.log($this.content);
			$.ajax({
				url: $this.opts.autosaveUrl,
				type: 'POST',
				data: $this.content,
				success: function(response) {
					console.log(response);

					if(response.success == true){
						console.log('Saved the draft succesfully');
						$this.contentChanged = false;
					} else {
						console.log('Saving Failed.');
					}

					//updating the extra params if it exists from the response
					if(!$.isEmptyObject($this.opts.extraParams)){
						$.each($this.opts.extraParams, function(key, value){
							if(response[key]){
								$this.opts.extraParams[key] = response[key];
							}
						});
					}

					$this.savingContentFlag = false;
					$this.opts.responseCallback(response);
				},
				error: function (xhr, ajaxOptions, thrownError) {
					$this.savingContentFlag = false;
	        console.log(xhr.status);
	        console.log(thrownError);
	        $this.opts.responseCallback(xhr.status);
      	}
			})
		}
	}

	/* Autosave PLUGIN Definiton */

	$.autoSaveContent = function (options) {
		var savecontent = new autoSaveContent(options);
	}

})(window.jQuery);