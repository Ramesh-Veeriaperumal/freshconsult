(function(){
	 // Private Variable and methods
	 var document 	   = window.document,
	 	 locationClass = { 1: "top", 2: "right", 3: "bottom", 4: "left", top: "top", right: "right", bottom: "bottom", left: "left"},
		 urlWithScheme = /^[a-zA-Z]+:\/\//,
		 version  	   = 2,
		 body_overflow,
		 options = {
			widgetId:		0,
			buttonText: 	"Support",
			buttonBg: 	 	"#7eb600",
			buttonColor: 	"white",
			backgroundImage: null,
			alignment:  	"left",
			offset:     	"35%",
			url:			"http://support.freshdesk.com",
			assetUrl: 		"https://s3.amazonaws.com/assets.freshdesk.com/widget",
			queryString:    "",
			screenshot: 	"",
			formHeight: 	"500px",
			responsive: 	"",
			widgetType: 	"popup",
			buttonType:     "text",
			captcha: 		"",
			loadOnEvent:    "windowLoad" // 'documentReady' || 'immediate' || 'onDemand'
		},
		widgetHeadHTML, widgetBodyHTML = null;
		$widget_attr = {
			"button"		: null,
			"dialog"		: null,
			"container" 	: null,
			"overlay" 		: null,
			"iframe" 		: null,
			"iframeLoaded"	: false,
			"closeButton"   : null,
			"mobileCloseButton" : null
		}

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
	 // Checking browser support for IE
	 var Browser = {
		Version: function() {
			var version = 999; // we assume a same browser
			// bah, IE again, lets downgrade version number
			if (navigator.appVersion.indexOf("MSIE") != -1)
				version = parseFloat(navigator.appVersion.split("MSIE")[1]);
			return version;
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

	 function loadjsfile(filename){
	 	var fileref = document.createElement("script");
	 		fileref.setAttribute("type","text/javascript");
	 		fileref.setAttribute("src", filename);
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
	        if (prop === 'url' || prop === 'assetUrl') {
	          options[prop] = prependSchemeIfNecessary(params[prop]);
	        } else {
	          options[prop] = params[prop];
	        }
	      }
	    }
	 }

	 function useFilterforIE(item) {
	 	var url = item.src;
	    var browser = window.navigator && window.navigator.appVersion.split("MSIE");
	    var version = parseFloat(browser[1]);
	    if ((version >= 5.5) && (version < 7) && (document.body.filters)) {
	      item.style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(src='" + url + "', sizingMethod='crop')";
	    }
		return item;
	 }

	 function createButton(){
	 	if ($widget_attr.button == null && options.widgetType == "popup") {
			class_name = locationClass[options.alignment] || "left";
			$widget_attr.button = document.createElement('div');
			$widget_attr.button.setAttribute('id', 'freshwidget-button');
			$widget_attr.button.style.display = 'none';
			$widget_attr.button.className = "freshwidget-button fd-btn-" + class_name;

			if(Browser.Version() <= 10)
				$widget_attr.button.className += " ie"+Browser.Version();

			link = document.createElement('a');
			link.setAttribute('href', 'javascript:void(0)');

			text = null;

			proxyLink = document.createElement('a');
			proxyLink.setAttribute('href', 'javascript:void(0)');

			if(options.backgroundImage == null || options.backgroundImage == "" || options.buttonType == "text"){
				link.className = "freshwidget-theme";
				link.style.color		   = options.buttonColor;
				link.style.backgroundColor = options.buttonBg;
				link.style.borderColor	   = options.buttonColor;
				proxyLink.className 	   = "proxy-link";
				text = document.createTextNode(options.buttonText);
			}else{
				link.className 			   = "freshwidget-customimage";
				text = document.createElement("img");
				text.src = options.backgroundImage;
				text.alt = options.buttonText;
				text = useFilterforIE(text);
			}

			if (class_name == 'top' || class_name == 'bottom'){
				$widget_attr.button.style.left = options.offset;
			}
			else{
				$widget_attr.button.style.top = options.offset;
			}

			document.body.insertBefore($widget_attr.button, document.body.childNodes[0]);
			$widget_attr.button.appendChild(link);
			link.appendChild(text);

			if((options.backgroundImage == null || options.backgroundImage == "") && (Browser.Version() <= 10)) {
				$widget_attr.button.appendChild(proxyLink);
				bind(proxyLink, 'click', function(){ window.FreshWidget.show(); });
				proxyLink.style.height = link.offsetHeight+"px";
				proxyLink.style.width = link.offsetWidth+"px";
			}
			bind(link, 'click', function(){ window.FreshWidget.show(); });
		}
	 }

	 function destroyButton(){
 	   if ($widget_attr.button != null) {
	   	document.body.removeChild($widget_attr.button);
	   	$widget_attr.button = null;
	   }
	 }

	 function destroyContainer(){
	 	if ($widget_attr.container != null) {
	 		document.body.removeChild($widget_attr.container);
	 		$widget_attr.container = null;
	 	}
	 }
	 function createContainer(){
	 	if ($widget_attr.container == null) {
			$widget_attr.container = document.createElement('div');

			$widget_attr.container.className = "freshwidget-container";
			$widget_attr.container.id = "FreshWidget";

			if(options.responsive == ""){
				$widget_attr.container.className += " responsive";
			}

			$widget_attr.container.style.display = 'none';

			document.body.insertBefore($widget_attr.container, document.body.childNodes[0]);

			$widget_attr.container.innerHTML = '<div class="widget-ovelay" id="freshwidget-overlay">&nbsp;</div>' +
						'<div class="freshwidget-dialog" id="freshwidget-dialog">' +
						' <img alt="Close Feedback Form" id="freshwidget-close" class="widget-close" src="'+options.assetUrl+'/widget_close.png?ver='+ version +'" />' +
						'<div class="mobile-widget-close" id="mobile-widget-close"></div>'+
						' <div class="frame-container">' +
						' 	<iframe title="Feedback Form" id="freshwidget-frame" src="about:blank" frameborder="0" scrolling="auto" allowTransparency="true" style="height: '+options.formHeight+'"/>' +
						' </div>'
						'</div>';

			$widget_attr.container 	= document.getElementById('FreshWidget');
			$widget_attr.closeButton = document.getElementById('freshwidget-close');
			$widget_attr.closeButton	= useFilterforIE($widget_attr.closeButton);
			$widget_attr.mobileCloseButton = document.getElementById('mobile-widget-close');
			$widget_attr.dialog      	= document.getElementById('freshwidget-dialog');
			$widget_attr.iframe	    = document.getElementById("freshwidget-frame");
			$widget_attr.overlay     = document.getElementById('freshwidget-overlay');

			$widget_attr.dialog.appendChild($widget_attr.iframe);

			loadingIframe();

			bind($widget_attr.closeButton, 'click', function(){ window.FreshWidget.close(); });
			bind($widget_attr.mobileCloseButton, 'click', function(){ window.FreshWidget.close(); });
			bind($widget_attr.overlay, 	  'click', function(){ window.FreshWidget.close(); });

			bind($widget_attr.iframe, 'load', function() {
				if(!$widget_attr.iframeLoaded && $widget_attr.iframe.src.indexOf("/widgets/feedback_widget/new?") != -1){
					$widget_attr.iframeLoaded = true;
				}
			});
		}
	 };

	 function loadingIframe(){
	 	$widget_attr.iframe.src = options.url + "/loading.html?ver=" + version;
	 }

	 function widgetFormUrl(){
	 	$widget_attr.iframe.src = options.url + "/widgets/feedback_widget/new?"+options.queryString;
	 }

	 function showContainer(){
	 	scroll(0,0);
	 	$widget_attr.container.style.display = 'block';

		if(!options.responsive){
			body_overflow = document.body.style.overflow;
			document.body.style.overflow='hidden'
		}
	 	if(Browser.Version() > 8 && options.screenshot == ""){
	        html2canvas( [ document.body ], {
					ignoreIds: "FreshWidget|freshwidget-button",
					proxy:false,
				    onrendered: function( canvas ) {
				      	var img = canvas.toDataURL();
				      	var message = img;

						 sendMessage = setInterval(function() {
						 	if ($widget_attr.iframeLoaded) {
							 	document.getElementById('freshwidget-frame').contentWindow.postMessage(message, "*");
							 	clearInterval(sendMessage);
						 	}else {
						 		//console.log('waiting for iframe to load');
						 	}
						 }, 500);
				    }
			});
    	}
	 	if(!$widget_attr.iframeLoaded) {
	 		widgetFormUrl();
	 	}
	 }

	 function close(){
	 	$widget_attr.container.style.display = 'none';
	 	if(!options.responsive){
			document.body.style.overflow= body_overflow || "auto";

		}
	 	widgetFormUrl();
	 }

	 function initialize(params){
		extend(params);

		if(Browser.Version() > 8 && (typeof html2canvas === 'undefined') && options.screenshot == "")
			loadjsfile(options.assetUrl+"/html2canvas.js?ver=" + version);

		switch(options.loadOnEvent){
			case 'windowLoad':
				bind(window, 'load', createWidget);
			break;
			case 'documentReady':
				bind(document, 'ready', createWidget);
			break;
			case 'immediate':
				createWidget();
			break;
		}
		

		loadcssfile(options.assetUrl+"/freshwidget.css?ver=" + version);
	 }


	 function createWidget() {
	 	// File name to be changed later when uploaded
	 	createButton();
		createContainer();
	 }

	 function updateWidget(params){
	 	extend(params);
		destroyButton();
		destroyContainer();
		$widget_attr.iframeLoaded = false;
		createButton();
		createContainer();
	 }

	 function destroyWidget(){
	 	destroyButton();
		destroyContainer();
		delete window.FreshWidget;
	 }

	 // Defining Public methods
     var FreshWidget = {
	 	init 		: function(apikey, params){
						catchException(function(){ return initialize(params); });
				      },
		create      : function(){
						catchException(function(){ return createWidget(); });
					  },
		show 		: function(){
						catchException(function(){ return showContainer(); });
					  },
		close		: function(){
						catchException(function(){ return close(); });
					  },
		iframe 		: function(){
						return $widget_attr.iframe;
					  },
	    update 		: function(params){
						catchException(function(){ return updateWidget(params); });
					  },
	    destroy  	: function(){
	    				catchException(function(){ return destroyWidget(); });
	    			}
	 };

	 if(!window.FreshWidget){window.FreshWidget=FreshWidget;}
})();