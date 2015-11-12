var MarketplaceBrowser  = Class.create({
	initialize: function(settingsLinks, customMsgs ) {
		this.settingsLinks = settingsLinks;
    this.customMessages = customMsgs;
		this.isMouseInside = false; //flag for checking whether mouse is in app-browser
		this.viewportHeight = jQuery(window).height();

		jQuery(document).on("click.nc_apps_evt", this.settingsLinks.browseBtn , this.openAppBrowser.bindAsEventListener(this))
        						.on("keyup.nc_apps_evt", this.onPageKeyup.bindAsEventListener(this)) //doubt
         						.on("click.nc_apps_evt", this.settingsLinks.appBrowserClose, this.onCloseBtnClick.bindAsEventListener(this))
         						.on("change.nc_apps_evt", this.settingsLinks.activationSwitch, this.activationSwitchOnOFF.bindAsEventListener(this))
                    .on("click.nc_apps_evt", this.settingsLinks.deleteBtn, this.onDeleteApp.bindAsEventListener(this));

		//for closing app browser upon clicking outside on body and other than the app browser box
		jQuery(document).on("mouseover.nc_apps_evt", this.settingsLinks.appBrowser, this.onAppBrowserHover.bindAsEventListener(this))
		 			   				.on("mouseleave.nc_apps_evt", this.settingsLinks.appBrowser, this.onAppBrowserMouseLeave.bindAsEventListener(this));

 		jQuery('body').on("mouseup.nc_apps_evt", this.onBodyClick.bindAsEventListener(this));

    this.pageURL = document.location.toString();
    this.setupSelectedTabs();
	},
  setupSelectedTabs: function(){
    var tabSelected = this.pageURL.split('#')[1];
    var tab = jQuery(tabSelected);
    if(tabSelected == "fresh-plugs"){
      jQuery('.nav-tabs a[href=#freshplugs]').tab('show');
      jQuery('.portal-pills a[href=#fresh-plugs]').tab('show');
    }
    else if(tabSelected == "apps"){
      jQuery('.nav-tabs a[href=#freshplugs]').tab('show');
      jQuery('.portal-pills a[href=#apps]').tab('show');
      window.history.pushState(null, null, "#apps");
    }
    else{
      jQuery('.nav-tabs a[href=#'+tabSelected+']').tab('show');
      if(tabSelected == "freshplugs"){
        jQuery('.portal-pills a[href=#apps]').tab('show');
      }
    }
    jQuery('body,html').animate({scrollTop: 0}, 800);
  },
  feedbackStatus: function(status_code, version_id, success_msg, error_msg, submit_lbl){
    if(status_code == 'true'){
      console.log("Success")
      jQuery('#feedbackModal-'+version_id+'-content').find('div.status').removeClass('error').text(success_msg).show();
      jQuery('#feedbackModal-'+version_id+'-content').find('.feedback-form').hide();
      jQuery('#feedbackModal-'+version_id+'-content').next('.modal-footer').hide();
    }
    else{
      jQuery('#feedbackModal-'+version_id+'-content').find('div.status').addClass('error').text(error_msg).show();
      jQuery('#feedbackModal-'+version_id+'-submit').removeAttr('disabled').removeClass('disabled').text(submit_lbl);
    }
  },
	activationSwitchOnOFF: function(e){		//used
		var el = jQuery(e.target),
				url = jQuery(el).attr("data-url"),
				toggle_url = jQuery(el).attr("data-toggle"),
        list_box = jQuery(el).parents(".list-box");

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
   	
    if (app_browser.hasClass('visible'))
      jQuery(this.settingsLinks.appBrowser).css('height', this.viewportHeight);
    else 
      app_browser.animate({"right":"0px"}, 240).addClass('visible');
	},
  onDeleteApp: function(e){
    var that = this;
    var el = jQuery(e.currentTarget);

    jQuery.ajax({
      url: jQuery(el).attr("data-url"),
      type: "delete",
      success: function(response){
        if(response.status == 200){
          var name = escapeHtml(response.name);
          jQuery("#noticeajax").html(name+ " " +that.customMessages.delete_success).show();
          if(response.classic_plug)
            jQuery("#ext-"+response.application_id).remove();
          else
            jQuery("#ext-"+response.version_id).remove();
          that.toggleNoPlugsMessage();
        }
        else {
          jQuery("#noticeajax").html(that.customMessages.delete_error + " " + name);
        }     
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
		if(jQuery(this.settingsLinks.appBrowser).hasClass('visible')){
			if (e.keyCode == 27) {
				this.closeSlideOutDiv();
			}
		}
	},
	onBodyClick: function(e){
		if(!this.isMouseInside){
    	if(jQuery(this.settingsLinks.appBrowser).hasClass('visible')){
        	this.closeSlideOutDiv();
    	}
    }
	},
	onCloseBtnClick: function(e){
		this.closeSlideOutDiv();
	},
	closeSlideOutDiv: function(){
		jQuery(this.settingsLinks.appBrowser).animate({"right":"-2000px"},'slow').removeClass('visible a-B');
		jQuery('body').removeClass("b-OH");
		jQuery('.header').removeClass('h-Z0');
		jQuery(this.settingsLinks.appBrowser).hide();
	},
  toggleNoPlugsMessage: function(){
    jQuery('#apps .no-plugs').toggle(jQuery('#apps .apps-wrapper').length == 0)
    jQuery('#fresh-plugs .no-plugs').toggle(jQuery('#fresh-plugs .apps-wrapper').length == 0)
  },
	destroy: function(){
		jQuery("document,body").off(".nc_apps_evt");
	}
});