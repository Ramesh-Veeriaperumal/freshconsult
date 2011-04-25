(function(){  
	 // Private Variable and methods
	 var document 	   = window.document,
	 	 locationClass = { 1: "top", 2: "right", 3: "bottom", 4: "left", top: "top", right: "right", bottom: "bottom", left: "left"},
		 urlWithScheme = /^[a-zA-Z]+:\/\//,
		 options = {
			widgetId:		0,					 	
			buttonText: 	"Support",
			buttonBg: 	 	"#7eb600",
			buttonColor: 	"white",
			backgroundImage: null, 
			alignment:  	"left", 
			offset:     	"35%",
			url:			"http://support.freshdesk.com",
			queryString:    ""
		},
		assetUrl  = "http://www.freshdesk.com/assets/",
		iframe, button, closeButton, overlay, dialog
		container = null;
	
	 // Utility methods for FreshWidget	
	 function catchException(fn) {
		try {
			return fn();
		} catch(e) {
			if (window.console && window.console.log && window.console.log.apply) {
				window.console.log("Freshdesk Error: ", e);
			}
		}
	 }
	 
	 function prependSchemeIfNecessary(url) {
	    if (url && !(urlWithScheme.test(url))) {
	      return document.location.protocol + '//' + url;
	    } else {
	      return url;
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
	 	 
	 function extend (params) {
		var prop;
	    for (prop in params) {
	      if (options.hasOwnProperty(prop)) {
	        if (prop === 'url' || prop === 'assetHost') {
	          options[prop] = prependSchemeIfNecessary(params[prop]);
	        } else {
	          options[prop] = params[prop];
	        }
	      }
	    }
	 } 
	 
	 function useFilterforIE(item) {
	 	url = item.src;
	    var browser = window.navigator && window.navigator.appVersion.split("MSIE");
	    var version = parseFloat(browser[1]);
	    if ((version >= 5.5) && (version < 7) && (document.body.filters)) {
	      item.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + url + "', sizingMethod='crop')";
	    } else {
	      item.style.backgroundImage = 'url(' + url + ')';
	    }
		return item;
	 }
	 	 
	 function createButton(){
	 	if (button == null) {
			class_name = locationClass[options.alignment] || "left";
			button = document.createElement('div');
			button.setAttribute('id', 'freshwidget-button');
			button.className = "freshwidget-button " + class_name;
			
			link = document.createElement('a');
			link.setAttribute('href', 'javascript:void(0)');
			
			text = null;
			
			if(options.backgroundImage == null || options.backgroundImage == ""){
				link.className = "freshwidget-theme";
				link.style.color		   = options.buttonColor;
				link.style.backgroundColor = options.buttonBg;
				link.style.borderColor	   = options.buttonColor;
				text = document.createTextNode(options.buttonText);
			}else{
				link.className 			   = "freshwidget-customimage";
				text = document.createElement("img");
				text.src = options.backgroundImage;	
				text = useFilterforIE(text);
			}
			
			if (class_name == 'top' || class_name == 'bottom'){
				button.style.left = options.offset; 
			}
			else{ 
				button.style.top = options.offset;
			}
			
			document.body.insertBefore(button, document.body.childNodes[0]);
			button.appendChild(link);
			link.appendChild(text);
			
			bind(link, 'click', function(){ window.FreshWidget.show(); });
		}
	 }	 
	 
	 function destroyButton(){
 	   if (button != null) {
	   	document.body.removeChild(button);
	   	button = null;
	   }
	 }
	 
	 function createContainer(){
	 	if (container == null) {
			container = document.createElement('div');
			container.className = "freshwidget-container";
			container.id = "FreshWidget";
			container.style.display = 'none';
			document.body.insertBefore(container, document.body.childNodes[0]);
			
			container.innerHTML = '<div class="widget-ovelay" id="freshwidget-overlay">&nbsp;</div>' +
			'<div class="freshwidget-dialog" id="freshwidget-dialog">' +
			' <img id="freshwidget-close" class="widget-close" src="'+assetUrl+'/widget_close.png" />' +
			' <div class="frame-container">' +
			' 	<iframe id="freshwidget-frame" src="about:blank" frameborder="0" scrolling="auto" allowTransparency="true" />' +
			' </div>'
			'</div>';
			
			container 	= document.getElementById('FreshWidget');
			closeButton = document.getElementById('freshwidget-close');
			closeButton	= useFilterforIE(closeButton);
			dialog      = document.getElementById('freshwidget-dialog');
			iframe	    = document.getElementById("freshwidget-frame");
			overlay     = document.getElementById('freshwidget-overlay'); 
			
			dialog.appendChild(iframe);
			loadingIframe();
			
			bind(closeButton, 'click', function(){ window.FreshWidget.close(); });
			bind(overlay, 	  'click', function(){ window.FreshWidget.close(); });
		}
	 }; 
	 
	 function loadingIframe(){
	 	iframe.src = options.url + "/loading.html";
	 }  
	 
	 function widgetFormUrl(){
	 	iframe.src = options.url + "/widgets/feedback_widget/new?"+options.queryString;	
	 }
	 
	 function showContainer(){ 
	 	scroll(0,0);
	 	container.style.display = 'block';
		widgetFormUrl();
	 }
	 
	 function close(){
	 	container.style.display = 'none';
		loadingIframe();
	 }
	 
	 function initialize(params){ 
		extend(params);
		bind(window, 'load', function(){
			// File name to be changed later when uploaded
			createButton();
			createContainer();
		});
	 }
	 
	 function updateWidget(params){
	 	extend(params);
		destroyButton();
		createButton();
	 }
	 
	 // Defining Public methods				  
     var FreshWidget = {
	 	init 		: function(apikey, params){
						catchException(function(){ return initialize(params); });	
				      }, 
		show 		: function(){
						catchException(function(){ return showContainer(); });
					  },
		close		: function(){
						catchException(function(){ return close(); });
					  },
		iframe 		: function(){
						return iframe;
					  }, 
	    update 		: function(params){
						catchException(function(){ return updateWidget(params); });
					  }
	 }; 
	 
	 loadcssfile(assetUrl+"/freshwidget.css");
	 
	 if(!window.FreshWidget){window.FreshWidget=FreshWidget;}
})();