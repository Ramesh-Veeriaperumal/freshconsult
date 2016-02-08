var MarketplaceBrowser  = Class.create({
	initialize: function(settingsLinks, customMsgs ) {
		this.settingsLinks = settingsLinks;
    this.customMessages = customMsgs;
		this.isMouseInside = false; //flag for checking whether mouse is in app-browser
		this.viewportHeight = jQuery(window).height();
    this.deletablePlug = {};

		jQuery(document).on("click.nc_apps_evt", this.settingsLinks.browseBtn , this.openAppBrowser.bindAsEventListener(this))
        						.on("keyup.nc_apps_evt", this.onPageKeyup.bindAsEventListener(this)) //doubt
         						.on("click.nc_apps_evt", this.settingsLinks.appBrowserClose, this.onCloseBtnClick.bindAsEventListener(this))
         						.on("change.nc_apps_evt", this.settingsLinks.activationSwitch, this.activationSwitchOnOFF.bindAsEventListener(this))
                    .on("click.nc_apps_evt", this.settingsLinks.deleteBtn, this.onDeleteApp.bindAsEventListener(this))
                    .on("click.nc_apps_evt", ".delete-confirm", this.onConfirmDelete.bindAsEventListener(this));

		//for closing app browser upon clicking outside on body and other than the app browser box
		jQuery(document).on("mouseover.nc_apps_evt", this.settingsLinks.appBrowser, this.onAppBrowserHover.bindAsEventListener(this))
		 			   				.on("mouseleave.nc_apps_evt", this.settingsLinks.appBrowser, this.onAppBrowserMouseLeave.bindAsEventListener(this));

 		jQuery('body').on("mouseup.nc_apps_evt", this.onBodyClick.bindAsEventListener(this));

    this.pageURL = document.location.toString();
    this.setupSelectedTabs();
	},
  setupSelectedTabs: function(){
    var tabSelected = this.pageURL.split('#')[1];
    jQuery('.nav-tabs a[href=#'+tabSelected+']').tab('show');
    jQuery('body,html').animate({scrollTop: 0}, 800);
  },
	activationSwitchOnOFF: function(e){		//used
		var el = jQuery(e.target),
				url = jQuery(el).attr("data-url"),
				toggle_url = jQuery(el).attr("data-toggle"),
        list_box = jQuery(el).parents(".list-box"),
        that = this;

		jQuery(el).parent(".onoffswitch").addClass("disabled");

		jQuery.ajax({
      type: 'PUT',
      url: url,
      success: function() {
        if(jQuery(list_box).hasClass("disabled-app"))
          jQuery(list_box).removeClass("disabled-app");
        else
          jQuery(list_box).addClass("disabled-app");

        jQuery(el).attr("data-toggle", url)
                  .attr("data-url", toggle_url)
                  .removeAttr("disabled");
        
        jQuery(el).parent(".onoffswitch").removeClass("disabled");
      },
      error: function(){
        jQuery(el).attr("data-url", url).attr("data-toggle", toggle_url).removeAttr("disabled");
        toggle_button = jQuery(el).parent().find('.toggle-button');
        if(toggle_button.hasClass("active"))
          toggle_button.removeClass("active");
        else
          toggle_button.addClass("active");

        jQuery("#noticeajax").html(that.customMessages.no_connection).show().addClass("alert-danger");
        closeableFlash('#noticeajax');
      }
    });
	},
	openAppBrowser: function(e){
    jQuery('body').addClass('b-OH');
    jQuery('.header').addClass("h-Z0");
    this.isMouseInside = true;
    jQuery(this.settingsLinks.appBrowser).addClass("a-B");

    var appBrowser = jQuery('#appBrowser');
		appBrowser.height = this.viewportHeight;
    var app_browser = jQuery(this.settingsLinks.appBrowser);
   	
    if (app_browser.hasClass('slide-activate')){
      jQuery(this.settingsLinks.appBrowser).css('height', this.viewportHeight);
    }
    else {
      jQuery(app_browser).addClass("slide-activate");
    }
	},
  onDeleteApp: function(e){
    e.preventDefault();
    this.deletablePlug =  { 
                            element: jQuery(e.currentTarget),
                            url: jQuery(e.currentTarget).attr("data-url")
                          };
  },
  onConfirmDelete: function(e) {
    var that = this;
    var el = that.deletablePlug.element;
    
    jQuery.ajax({
      url: that.deletablePlug.url,
      type: "delete",
      success: function(resp_body, statustext, resp){
        jQuery("#toggle-confirm").modal("hide");
        jQuery('.twipsy').remove();
        if(resp.status == 200){
          jQuery(el).closest(".installed-listing").remove();
          jQuery("#noticeajax").html(that.customMessages.delete_success).show().removeClass("alert-danger");
          closeableFlash('#noticeajax');
          if(jQuery(el).closest(".plugs").length > 0){
            that.togglePlugsMessage(that.getFreshPlugsLength() == 0);
          }else{
            that.toggleAppsMessage(that.getAppsLength() == 0);
          }
        }
        else {
          jQuery("#noticeajax").html(that.customMessages.delete_error).show().addClass("alert-danger");
          closeableFlash('#noticeajax');
        }     
      },
      error: function(){
        jQuery("#toggle-confirm").modal("hide");
        jQuery('.twipsy').remove();
        jQuery("#noticeajax").html(that.customMessages.delete_error).show().addClass("alert-danger");
        closeableFlash('#noticeajax');
      }
    });
  },
  onAppBrowserHover: function(e){ //used
    this.isMouseInside=true;
  },
  onAppBrowserMouseLeave: function(e){ //used
    this.isMouseInside=false;
  },
	onPageKeyup: function(e){
		//for esc close
		if(jQuery(this.settingsLinks.appBrowser).hasClass('slide-activate')){
			if (e.keyCode == 27) {
				this.closeSlideOutDiv();
			}
		}
	},
	onBodyClick: function(e){
	  if(!this.isMouseInside && !jQuery(e.originalEvent.target).hasClass("select2-drop-mask")){
    	if(jQuery(this.settingsLinks.appBrowser).hasClass('slide-activate')){
        	this.closeSlideOutDiv();
    	}
    }
	},
	onCloseBtnClick: function(e){
		this.closeSlideOutDiv();
	},
	closeSlideOutDiv: function(){
		jQuery('body').removeClass("b-OH");
		jQuery('.header').removeClass('h-Z0');
		jQuery(this.settingsLinks.appBrowser).removeClass("slide-activate a-B");
	},
  toggleAppsMessage: function(toggle_apps){
    if( toggle_apps || jQuery('#apps .alert-error').length > 0){
      jQuery('#apps .no-plugs').toggle();
    }
  },
  togglePlugsMessage: function(toggle_plugs){
    if(toggle_plugs){
      jQuery('#plugs .no-plugs').toggle();
    }
  },
  getAppsLength: function(){
    return jQuery('#apps .apps-wrapper').length;
  },
  getFreshPlugsLength: function(){
    return jQuery('#plugs .apps-wrapper').length;
  },
	destroy: function(){
		jQuery("document,body").off(".nc_apps_evt");
	}
});