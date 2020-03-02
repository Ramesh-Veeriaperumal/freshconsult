var MarketplaceBrowser  = Class.create({
	initialize: function(settingsLinks, customMsgs, platformVersion) {
    var self = this;
		this.settingsLinks = settingsLinks;
    this.customMessages = customMsgs;
		this.isMouseInside = false; //flag for checking whether mouse is in app-browser
		this.viewportHeight = jQuery(window).height();
    this.deletablePlug = {};
    this.pollRetryLimit = settingsLinks.accApiPollRetryLimit;
    this.accApiPollInterval = settingsLinks.accApiPollInterval;
    this.platformVersion = platformVersion;

		jQuery(document).on("click.nc_apps_evt", this.settingsLinks.browseBtn , this.openAppBrowser.bindAsEventListener(this))
        						.on("keyup.nc_apps_evt", this.onPageKeyup.bindAsEventListener(this)) //doubt
         						.on("click.nc_apps_evt", this.settingsLinks.appBrowserClose, this.onCloseBtnClick.bindAsEventListener(this))
         						.on("change.nc_apps_evt", this.settingsLinks.activationSwitch, this.activationSwitchOnOFF.bindAsEventListener(this))
                    .on("click.nc_apps_evt", this.settingsLinks.deleteBtn, this.onDeleteApp.bindAsEventListener(this))
                    .on("click.nc_apps_evt", this.settingsLinks.reauthorizeBtn, this.onReauthorizeApp.bindAsEventListener(this))
                    .on("click.nc_apps_evt", this.settingsLinks.updateOAuth, this.onUpdateOAuth.bindAsEventListener(this))
                    .on("click.nc_apps_evt", ".delete-confirm", this.onConfirmDelete.bindAsEventListener(this))
                    .on("click.nc_apps_evt", ".reauthorize-confirm", this.onReauthorizeConfirm.bindAsEventListener(this))
                    .on("click.nc_apps_evt", "#integrations-list .mkt-apps, #integrations-list .cla-plugs, #integrations-list .nat-apps", this.showActions.bindAsEventListener(this));

		//for closing app browser upon clicking outside on body and other than the app browser box
		jQuery(document).on("mouseover.nc_apps_evt", this.settingsLinks.appBrowser, this.onAppBrowserHover.bindAsEventListener(this))
		 			   				.on("mouseleave.nc_apps_evt", this.settingsLinks.appBrowser, this.onAppBrowserMouseLeave.bindAsEventListener(this));

 		jQuery('body').on("mouseup.nc_apps_evt", this.onBodyClick.bindAsEventListener(this));

    this.pageURL = document.location.toString();
    this.setupSelectedTabs();
    jQuery(document).ready(function(){
      self.deleteInProgressExt();
    });
	},

  deleteInProgressExt: function() {
    var inProgressExt = jQuery('.list-box.mkp-uninstall_in_progress .plug-actions .delete-btn');
    var installedExtensionId = inProgressExt.attr('data-installed-extn-id');
    var initialCount = 0;
    if (inProgressExt.length > 0) {
      var plug = {
        element: inProgressExt,
        url: inProgressExt.attr("data-url"),
        mkpRoute: inProgressExt.attr("data-mkp-route"),
        extensionId: inProgressExt.attr("data-extn-id"),
        installedExtnId: installedExtensionId,
        versionId: inProgressExt.attr("data-version-id")
      };
      var el = jQuery("#delete_prog_" + installedExtensionId);
      el.siblings('.plug-actions').hide();
      jQuery("#delete_prog_"+ installedExtensionId +" .mkp-prog-spinner").addClass('sloading loading-tiny');
      el.show();
      this.pollAccountApi(plug, initialCount, this.pollRetryLimit, installedExtensionId);
    }
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
  onUpdateOAuth: function(e) {
    e.preventDefault();
    this.handleOAuthInstall(jQuery('.update-oauth').attr('data-url'));
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
                            mkpRoute: jQuery(e.currentTarget).attr("data-mkp-route"),
                            extensionId: jQuery(e.currentTarget).attr("data-extn-id"),
                            installedExtnId: jQuery(e.currentTarget).attr('data-installed-extn-id'),
                            versionId: jQuery(e.currentTarget).attr("data-version-id")
                          };
  },

	onReauthorizeApp: function(e){
		e.preventDefault();
		this.reauthorizePlug =  {
                              url: jQuery(e.currentTarget).attr("data-url")
                            };
	},

	onReauthorizeConfirm: function(e) {
    this.handleOAuthInstall(this.reauthorizePlug.url);
	},

  handleOAuthInstall: function(url) {
    var that = this;
    jQuery.ajax({
      url: url,
      type: "GET",
      success: function(resp_body, statustext, resp){
        that.platformVersion == '2.0' ? parent.location = resp_body.redirect_url : window.location = resp_body.redirect_url;
      },
      error: function(jqXHR, exception) {
        jQuery("#noticeajax").html(that.customMessages.no_connection).show().addClass("alert-danger");
        closeableFlash('#noticeajax');
      }
    });    
  },

  onConfirmDelete: function(e) {
    var that = this;
    var plug = that.deletablePlug;
    that.uninstallApp(plug);
  },
  uninstallApp: function(plug){
    var that = this;
    var el = plug.element;
    var initialCount = 0;
    jQuery.ajax({
      url: plug.url,
      type: "delete",
      beforeSend: function(){
        var list_box = jQuery(el).parents(".list-box");
        jQuery(list_box).addClass("disabled-app");
        jQuery(el).closest('.plug-actions').hide();
        jQuery('#delete_prog_'+ plug.installedExtnId +' .mkp-prog-spinner').addClass('sloading loading-tiny');
        jQuery('#delete_prog_'+ plug.installedExtnId).show();
      },
      success: function(resp_body, statustext, resp){
        jQuery("#toggle-confirm").modal("hide");
        jQuery('.twipsy').remove();
        if(resp.status == 200){
          that.handleUninstallSuccess(plug);
        } else if (resp.status == 202) {
          var installedExtensionId = resp_body.installed_extension_id;
          setTimeout( function() {
        		that.pollAccountApi(plug, initialCount, that.pollRetryLimit, installedExtensionId);
        	}, that.accApiPollInterval);
        } else {
          that.handleUninstallFailure(plug);
        }
      },
      error: function(){
        that.handleUninstallFailure(plug);
      }
    });
  },

  handleUninstallSuccess: function(plug) {
    var el = plug.element;
    jQuery(el).closest(".installed-listing").remove();
    jQuery("#noticeajax").html(this.customMessages.delete_success).show().removeClass("alert-danger");
    closeableFlash('#noticeajax');
    if(jQuery(el).closest(".plugs").length > 0){
    	this.togglePlugsMessage(this.getFreshPlugsLength() == 0);
    }else{
    	this.toggleAppsMessage(this.getAppsLength() == 0);
    }
  },

  handleUninstallFailure: function(plug, message) {
    var that = this;
    that.rollbackDelete(plug);
    jQuery("#toggle-confirm").modal("hide");
    jQuery('.twipsy').remove();
    html = that.customMessages.delete_error.unescapeHTML();
    if (message) {
      html += '<div class="mkp-error-details"><a>View error details<a></div>';
    }
    jQuery("#noticeajax").html(html).show().addClass("alert-danger");
    jQuery('.mkp-error-details').click(function() {
      jQuery('.mkp-error-details').html('<p>'+ escapeHtml(message) +'<p>');
    });
    closeableFlash('#noticeajax');
  },

  pollAccountApi: function(plug, count, maxCount, installedExtensionId) {
    var self = this;
    jQuery.ajax({
      url: '/admin/marketplace/installed_extensions/'+ installedExtensionId +'/app_status',
      type: "GET",
      success: function(resp_body, statustext, resp){
        self.handlePollSuccess(plug, resp, count, maxCount, installedExtensionId);
      },
      error: function(jqXHR, exception) {
        self.handleUninstallFailure(plug);
      }
    });
  },

  handlePollSuccess: function(plug, resp, count, maxCount, installedExtensionId) {
    var self = this;
    if (resp.status == 202 && count < maxCount) {
      count = count + 1;
      setTimeout( function() {
        self.pollAccountApi(plug, count, maxCount, installedExtensionId);
      }, self.accApiPollInterval);
    } else if (resp.status == 200) {
      response = resp.responseJSON;
      switch (response.status) {
        case 'SUCCESS':
          self.handleUninstallSuccess(plug);
          break;
        case 'FAILED':
        case 'LIMBO':
          self.handleUninstallFailure(plug, response.message);
          break;
      }
    } else {
    	self.handleUninstallFailure(plug);
    }
  },

  rollbackDelete: function(plug) {
    var self = this;
    var el = plug.element;
    var list_box = jQuery(el).parents(".list-box");
    jQuery(list_box).removeClass("disabled-app");
    jQuery(el).closest('.plug-actions').show();
    jQuery('#delete_prog_'+ plug.installedExtnId +' .mkp-prog-spinner').removeClass('sloading loading-tiny');
    jQuery('#delete_prog_'+ plug.installedExtnId).hide();
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