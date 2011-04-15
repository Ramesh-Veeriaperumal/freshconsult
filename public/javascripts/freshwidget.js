(function(){  
	 // Private Variable and methods
	 var document 	   = window.document,
	 	 locationClass = { 1: "top", 2: "right", 3: "bottom", 4: "left", top: "top", right: "right", bottom: "bottom", left: "left"},
		 options = {
			buttonText: "Support", 
			alignment:  "left", 
			offset:     "35%"	
		};
	 
	 function showIFrame(){
		overlay = document.createElement('div');
		overlay.className = "freshwidget-ovelay";
		document.body.appendChild(overlay);
	 }
	 	 
	 function createButton(){
		try { 
			class_name = locationClass[options.alignment] || "left";
			button = document.createElement('div');
			button.setAttribute('id', 'freshwidget-button'); 
			button.className = "freshwidget-button "+ class_name;
			if(class_name == 'top' || class_name == 'bottom')
				button.style.left = options.offset;
			else
				button.style.top = options.offset;
			
			link = document.createElement('a');
		    link.setAttribute('href', 'javascript:void(0)');
			link.className = "freshwidget-theme";
			bind(link, "click", function(){
				showIFrame();
			});
			
			text = document.createTextNode(options.buttonText);
			
			//document.body.appendChild(button);
			document.body.insertBefore(button, document.body.childNodes[0]);
			button.appendChild(link);
			link.appendChild(text);
			
		}catch(e){
			console.log(e);
		}
	 };
					  
     function loadcssfile(filename){
	 					var fileref = document.createElement("link");
						  	fileref.setAttribute("rel", "stylesheet");
						  	fileref.setAttribute("type", "text/css");
						  	fileref.setAttribute("href", filename);
						if (typeof fileref!="undefined")
  							document.getElementsByTagName("head")[0].appendChild(fileref);	
					  };					  
					  
	 function bind(obj, evt, callback){
		if (obj && obj.addEventListener) {
	      obj.addEventListener(evt, callback, false);
	    } else if (obj && obj.attachEvent) {
	      obj.attachEvent('on' + evt, callback);
	    }
	 }  
	 	 
	 var extend = function(obj, extObj) {
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
	 };	 
	 // Defining Public methods				  
     var FreshWidget = {
	 	init 		: function(apikey, params){
							extend(options, params);
							bind(window, 'load', function() {
								// File name to be changed later when uploaded
								loadcssfile("../stylesheets/freshwidget.css"); 
							 	createButton();
							});
				    	  }
	 }
	 
	 if(!window.FreshWidget){window.FreshWidget=FreshWidget;}
})();