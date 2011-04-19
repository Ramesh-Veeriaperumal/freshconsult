(function(){  
	 // Private Variable and methods
	 var document 	   = window.document,
	 	 locationClass = { 1: "top", 2: "right", 3: "bottom", 4: "left", top: "top", right: "right", bottom: "bottom", left: "left"},
		 options = {
			buttonText: "Support", 
			alignment:  "left", 
			offset:     "35%",
			domain:		"http://192.168.1.104:3000"	
		},
		iframe, button, closeButton, overlay, dialog
		container = null;
	
	 // Utiltiy methods for FreshWidget	
	 function catchException(fn) {
		try {
			return fn();
		} catch(e) {
			if (window.console && window.console.log && window.console.log.apply) {
				window.console.log("Freshdesk Error: ", e);
			}
		}
	 }
	 
	 function loadcssfile(filename){
		var fileref = document.createElement("link");
		  	fileref.setAttribute("rel", "stylesheet");
		  	fileref.setAttribute("type", "text/css");
		  	fileref.setAttribute("href", filename);
		if (typeof fileref!="undefined")
  			document.getElementsByTagName("head")[0].appendChild(fileref);	
	 }					  
					  
	 function bind(obj, evt, callback){
		if (obj && obj.addEventListener) {
	      obj.addEventListener(evt, callback, false);
	    } else if (obj && obj.attachEvent) {
	      obj.attachEvent('on' + evt, callback);
	    }
	 }  
	 	 
	 function extend (obj, extObj) {
	    if (arguments.length > 2) {
	        for (var a = 1; a < arguments.length; a++) {
	            extend(obj, arguments[a]);
	        }
	    } else {
	        for (var i in extObj) {
	            obj[i] = extObj[i];
	        }
	    }
	    return obj;
	 } 
	 	 
	 function createButton(){
	 	if (container == null) {
			class_name = locationClass[options.alignment] || "left";
			button = document.createElement('div');
			button.setAttribute('id', 'freshwidget-button');
			button.className = "freshwidget-button " + class_name;
			if (class_name == 'top' || class_name == 'bottom') 
				button.style.left = options.offset;
			else 
				button.style.top = options.offset;
			
			link = document.createElement('a');
			link.setAttribute('href', 'javascript:void(0)');
			link.className = "freshwidget-theme";
			text = document.createTextNode(options.buttonText);
			document.body.insertBefore(button, document.body.childNodes[0]);
			button.appendChild(link);
			link.appendChild(text);
			
			container = document.createElement('div');
			container.className = "freshwidget-container";
			container.id = "FreshWidget";
			container.style.display = 'none';
			document.body.insertBefore(container, document.body.childNodes[0]);
			
			container.innerHTML = '<div class="widget-ovelay" id="freshwidget-overlay">&nbsp;</div>' +
			'<div class="freshwidget-dialog" id="freshwidget-dialog">' +
			' <span id="freshwidget-close" class="widget-close"></span>' +
			' <div class="frame-container">' +
			' 	<iframe id="freshwidget-frame" src="about:blank" frameborder="0" scrolling="auto" allowTransparency="true" />' +
			' </div>'
			'</div>';
			
			container 	= document.getElementById('FreshWidget');
			closeButton = document.getElementById('freshwidget-close');
			dialog      = document.getElementById('freshwidget-dialog');
			iframe	    = document.getElementById("freshwidget-frame");
			overlay     = document.getElementById('freshwidget-overlay'); 
			
			dialog.appendChild(iframe);
			loadingIframe();
			
			bind(link, 		  'click', function(){ window.FreshWidget.show(); });
			bind(closeButton, 'click', function(){ window.FreshWidget.close(); });
			bind(overlay, 	  'click', function(){ window.FreshWidget.close(); });
		}
	 }; 
	 
	 function loadingIframe(){
	 	iframe.src = options.domain + "/loading.html";
	 }  
	 
	 function widgetFormUrl(){
	 	iframe.src = options.domain + "/widgets/feedback_widget/new";	
	 }
	 
	 function showContainer(){ 
	 	container.style.display = 'block';
		widgetFormUrl();
	 }
	 
	 function close(){
	 	container.style.display = 'none';
		loadingIframe();
	 }
	 
	 function initialize(){ 
		loadcssfile("http://192.168.1.104:3000/stylesheets/freshwidget.css"); 
		bind(window, 'load', function(){
			// File name to be changed later when uploaded
			createButton();
		});
	 }
	 
	 // Defining Public methods				  
     var FreshWidget = {
	 	init 		: function(apikey, params){
						catchException(function(){ return extend(options, params) });
						catchException(function(){ return initialize() });	
				      },
		show 		: function(){
						catchException(function(){ return showContainer(); });
					  },
		close		: function(){
						catchException(function(){ return close(); });
					  },
		iframe 		: function(){
						return iframe;
					  }
	 }
	 
	 if(!window.FreshWidget){window.FreshWidget=FreshWidget;}
})();