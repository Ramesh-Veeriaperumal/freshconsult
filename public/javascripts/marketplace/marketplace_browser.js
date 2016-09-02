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
                    .on("click.nc_apps_evt", ".delete-confirm", this.onConfirmDelete.bindAsEventListener(this))
                    .on("click.nc_apps_evt", "#integrations-list .mkt-apps, #integrations-list .cla-plugs, #integrations-list .nat-apps", this.showActions.bindAsEventListener(this));

		//for closing app browser upon clicking outside on body and other than the app browser box
		jQuery(document).on("mouseover.nc_apps_evt", this.settingsLinks.appBrowser, this.onAppBrowserHover.bindAsEventListener(this))
		 			   				.on("mouseleave.nc_apps_evt", this.settingsLinks.appBrowser, this.onAppBrowserMouseLeave.bindAsEventListener(this));

 		jQuery('body').on("mouseup.nc_apps_evt", this.onBodyClick.bindAsEventListener(this));

    this.pageURL = document.location.toString();
    this.setupSelectedTabs();
	},

  showActions: function(e){
    if(jQuery(e.target).hasClass("mkt-apps")){
      jQuery(".tab-actions .create-new").hide();
      jQuery(".tab-actions .browse-apps").show();
    }else if (jQuery(e.target).hasClass("cla-plugs")){
      jQuery(".tab-actions .create-new").show();
      jQuery(".tab-actions .browse-apps").hide();
    }else if(jQuery(e.target).hasClass("nat-apps")){
      jQuery(".tab-actions .create-new").hide();
    }else{
      jQuery(".tab-actions .create-new").show();
    }
  },
  setupSelectedTabs: function(){
    var tabSelected = this.pageURL.split('#')[1];
    jQuery('.nav-tabs a[href="#'+tabSelected+'"]').tab('show');
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
        var selected_app = jQuery(list_box).find(".plug-data .plug-name").text().trim();
        if(jQuery(list_box).hasClass("disabled-app")){
          jQuery(list_box).removeClass("disabled-app");
          jQuery(document).trigger({
              type: "enabled_app",
              app_name: selected_app,
              time: new Date()
          });
        }
        else{
          jQuery(list_box).addClass("disabled-app");
          jQuery(document).trigger({
              type: "disabled_app",
              app_name: selected_app,
              time: new Date()
          });
        }

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
                            url: jQuery(e.currentTarget).attr("data-url"),
                            deleteUrl: jQuery(e.currentTarget).attr("data-delete-url"),
                            mkpRoute: jQuery(e.currentTarget).attr("data-mkp-route"),
                            extensionId: jQuery(e.currentTarget).attr("data-extn-id"),
                            versionId: jQuery(e.currentTarget).attr("data-version-id")
                          };
  },
  onConfirmDelete: function(e) {
    var that = this;
    var el = that.deletablePlug.element;
    
    if(that.deletablePlug.deleteUrl)
    {
      jQuery.ajax({
        url: that.deletablePlug.deleteUrl,
        type:"post",
        headers: {
          "MKP-ROUTE":that.deletablePlug.mkpRoute,
          "MKP-EXTNID": that.deletablePlug.extensionId,
          "MKP-VERSIONID": that.deletablePlug.versionId
        },
        success: function(resp_body, statustext, resp){
          that.uninstallApp();
        },
        error: function(){
          jQuery("#toggle-confirm").modal("hide");
          jQuery('.twipsy').remove();
          jQuery("#noticeajax").html(that.customMessages.delete_error).show().addClass("alert-danger");
          closeableFlash('#noticeajax');
        }
      });
    }
    else
    {
      that.uninstallApp();
    }

  },
  uninstallApp: function(){
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
    var ele = jQuery(e.originalEvent.target);
    var clickedSuggestions = jQuery(ele).hasClass("ui-autocomplete") || jQuery(ele).hasClass("suggested-term") || jQuery(ele).hasClass("fa-autocomplete") 

	  if(!this.isMouseInside && !jQuery(ele).hasClass("select2-drop-mask") && !clickedSuggestions ){
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
		jQuery(this.settingsLinks.appBrowser).removeClass("slide-activate a-B");
	},
  toggleAppsMessage: function(toggle_apps){
    if( toggle_apps || jQuery('#apps .alert-error').length > 0){
      jQuery('#apps .no-apps').toggle();
    }
  },
  togglePlugsMessage: function(toggle_plugs){
    if(toggle_plugs){
      jQuery('#custom_apps .no-custom-apps').toggle();
    }
  },
  getAppsLength: function(){
    return jQuery('#apps .apps-wrapper').length;
  },
  getFreshPlugsLength: function(){
    return jQuery('#custom_apps .apps-wrapper').length;
  },
	destroy: function(){
		jQuery("document,body").off(".nc_apps_evt");
	}
});