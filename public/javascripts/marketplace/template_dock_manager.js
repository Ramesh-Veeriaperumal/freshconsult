var TemplateDockManager = Class.create({
  initialize: function(extensionsEl, customMsgs, tabName, platformVersion) {
    this.extensionsWrapper = extensionsEl;
    this.customMessages = customMsgs;
    this.progressInterval;
    this.tabName = tabName;
    this.isSearched = false;
    this.appName;
    this.extensionId = jQuery('#app-window').attr('data-extension_id');
    this.developedBy;
    this.action;
    this.pollRetryLimit = 5;
    this.isAppBrowserOpened = false;
    this.accApiPollInterval = customMsgs.accapi_poll_interval;
    this.platformVersion = platformVersion;
    this.marketplaceAdapter = this.marketplaceAdapter || new MarketplaceAdapter();
    this.marketplaceManager = this.marketplaceManager || new MarketplaceManager(this.marketplaceAdapter.getAdapter());
    this.appInstance;

    this.loggerOptions = {
      status: {
        IN_PROGRESS: 202,
        OK: 200,
        NO_CONTENT: 204
      },
      messages: {
        NO_LOGS_FOUND: 'There are no logs for the last 1 hour.',
        ERROR_FETCHING_LOGS: 'There was an error while trying to fetch the logs. Please <a class="reload_logs">try again</a> later.',
        TAKING_TOO_LONG: 'The request is taking longer than usual. Please <a class="reload_logs">try again</a> later.',
        FOUND_LOGS: 'Logs for the last 1 hour',
        LOADING: 'Retrieving logs for the last 1 hour. This may take up to 30 seconds.'
      },
      count: 12,
      logsAPIPollInterval: 5000
    };

    this.bindTemplateEvents();
    this.setupCarousel();
    var that = this;
    jQuery(".search-query").livequery(function(){
      var _searchInput = jQuery(this);
      jQuery(this).autocomplete({
        source: function( request, response ) {
          var term = jQuery.trim(request.term)
          if (term.length >= 2) {
            jQuery.ajax({
              type: 'get',
              url: jQuery(_searchInput).data("url")+'&query='+encodeURIComponent(term),
              success: function(data) {
                that.isSearched = false;
                results = data;
                if(results.length > 0){
                  response(
                    jQuery.map( results, function( item ) {
                      return {
                        term : item.suggest_term,
                        url : item.show_url
                      }
                    })
                  )
                }else{
                  jQuery('.search-loader, .ui-autocomplete').hide();
                  jQuery('.remove-query, .search-apps').show();
                }
              },
              error: function(jqXHR, exception) {
                that.showErrorMsg(that.customMessages.api_error);
              }
            });
          }
        },
        minLength: 2,
        search: function( event, ui ){
          jQuery('.search-apps').hide();
          jQuery('.search-loader').show();
          jQuery('.remove-query, .search-apps').hide();
        },
        open: function( event, ui ){
          jQuery('.search-loader, .remove-query').hide();
          jQuery('.search-apps').show();
        },
        select: function( event, ui ) {
          that.getAppInfo(ui.item.url, true); // params are 'url to be loaded on click', 'is this from search suggestion?'
          jQuery(".appsearch-box #query").val(ui.item.term);
        },
        focus: function( event, ui ) {
          jQuery(".appsearch-box #query").val(ui.item.term);
          return false;
        }
      }).autocomplete( "instance" )._renderItem = function( ul, item ) {
        jQuery('.search-loader').hide();
        jQuery('.remove-query').show();
        return jQuery( "<li class='fa-autocomplete'></li>" )
            .data( "autocomplete-item", item )
            .append( "<a class='suggested-term' data-url='"+ item.url+ "'>" + escapeHtml(item.term) + "</a>" )
            .appendTo( ul );
      };

    });

  },
  bindTemplateEvents: function(){
    jQuery(document).on("click.tmpl_events", ".browse-btn, .category, .back2list_btn, .back2catg_btn, #appGalleryLogo, .view-all", this.loadApps.bindAsEventListener(this))
                    .on("click.tmpl_events", ".fplugs-box,.backbtn, .show_btn" , this.loadAppInfo.bindAsEventListener(this))
                    .on("click.tmpl_events", ".cancel_btn" , this.cancelInstall.bindAsEventListener(this))
                    .on("click.tmpl_events", ".install-btn" , this.installApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".install-form-btn, .update" , this.updateApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".oauth-iparams-btn" , this.getOauthIparams.bindAsEventListener(this))
                    .on("click.tmpl_events", ".install-oauth-btn", this.installOAuthApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".install-iframe-settings, .update-iframe-settings" , this.updateIframeApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".nativeapp" , this.installNativeApp.bindAsEventListener(this))
                    .on("submit.tmpl_events", "form#extension-search-form" , this.onSearch.bindAsEventListener(this))
                    .on("click.tmpl_events", ".appbrowser-close" , this.appBrowserClosed.bindAsEventListener(this))
                    .on("click.tmpl_events", "[id^=carousel-selector-]" , this.carouselSelector.bindAsEventListener(this))
                    .on("click.tmpl_events", ".fa-tabd a", this.reinstateURL.bindAsEventListener(this))
                    .on("click.tmpl_events", ".remove-query", this.resetQuery.bindAsEventListener(this))
                    .on("click.tmpl_events", ".carousel-dot", this.carouselDotNav.bindAsEventListener(this))
                    .on("click.tmpl_events", ".carousel", this.carouselScroll.bindAsEventListener(this))
                    .on("click.tmpl_events", ".toggle_policy" , this.togglePolicyInfo.bindAsEventListener(this))
                    .on("click.tmpl_events", ".buy-app" , this.buyApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".tab" , this.switchTabs.bindAsEventListener(this))
                    .on("click.tmpl_events", ".reload_logs" , this.pollLogAPI.bindAsEventListener(this))
                    .on("click.tmpl_events", ".update-payment-info" , this.updatePaymentInfo.bindAsEventListener(this));
  },
  togglePolicyInfo: function() {
    jQuery('.display_policy').toggle();
  },
  resetQuery: function (e) {
    jQuery(".appsearch-box #query").val("");
    jQuery(".search-apps").show();
    jQuery(".search-loader, .remove-query").hide();
  },
  setupCarousel: function(){
    jQuery("#screenshotsCarousel").livequery(function(){
      jQuery("#screenshotsCarousel").carousel({
        pause: true,
        interval: false
      });
      jQuery(this).on('slid', function (e) {
        var item = jQuery('#screenshotsCarousel .carousel-inner .item.active');
        // Deactivate all nav links
        jQuery('.slider-thumbs li').removeClass('active');
        //to activate the nav link based on slide
        var index = item.index() + 1;
        jQuery('.slider-thumbs li:nth-child(' + index + ')').addClass('active');
        jQuery(".carousel-dot.active").removeClass("active");
        jQuery('.carousel-indicators li:nth-child(' + index + ')').addClass('active');
      });
    });
  },
  carouselDotNav: function(e){
    jQuery(".carousel").carousel(parseInt(jQuery(e.target).attr("data-slide-to")));
    jQuery(".carousel-dot.active").removeClass("active");
    jQuery(e.target).addClass("active");
  },
  carouselSelector: function(e){
    var id_selector = jQuery(e.currentTarget).attr("id");
    var id = id_selector.substr(id_selector.length -1);
    var id = parseInt(id);
    jQuery('#screenshotsCarousel').carousel(id);
  },
  carouselScroll: function(e){
    var descHeight = jQuery(".descript").outerHeight();
    var whatsNewHeight = 0;
    if(jQuery(".whats-new").length > 0){
      whatsNewHeight = jQuery(".whats-new").outerHeight();
    }

    jQuery('.head-spacer').animate({
      scrollTop: descHeight+whatsNewHeight+15
    }, 1000);
  },
  showLoader: function(){
    jQuery(this.extensionsWrapper).empty();
    jQuery(this.extensionsWrapper).append('<div class="sloading loading-block"></div>');
  },
  installTrigger: function(trigger_element){
    jQuery(trigger_element).trigger("click");
  },
  startProgress: function(){
    this.progressInterval = setInterval(function() {
      var $bar = jQuery('.bar');
      var width = $bar.width();
      var parentWidth = $bar.offsetParent().width();
      var elWidthPercent = 100*width/parentWidth;

      if (elWidthPercent <= 95) {
        $bar.width($bar.width()+Math.floor(Math.random() * 50) + 10);
      }
    }, 125);
  },
  loadApps: function(e){
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);
    jQuery.ajax({
      url: jQuery(el).attr("data-url"),
      type: "GET",
      beforeSend: function(){
        that.showLoader();
      },
      success: function(jqXHR, exception){
        jqXHR['category_specific'] = jQuery(el).hasClass('category') || jQuery(el).hasClass('view-all') ||
                                     jQuery(el).hasClass('back2catg_btn');
        jQuery(that.extensionsWrapper).empty()
                                      .append(JST["marketplace/marketplace_list"](jqXHR));
        if(jQuery(el).hasClass('view-all')) {
          jQuery('a[href="#' + jQuery(el).attr('id') + '"]').click();
        };
        if(jQuery(el).is('#category_0') || jQuery(el).hasClass('view-all')) {
          jQuery('#category_0').css({'color':'#555','font-weight': 'bold'});
        }
        that.isSearched = false;
        jQuery("#query").focus();
      },
      error: function(jqXHR, exception) {
        that.showErrorMsg(that.customMessages.no_connection);
      }
    });
  },
  showErrorMsg: function(error_msg){
    var that = this;
    error_msg = error_msg || that.customMessages.no_connection;
    jQuery(that.extensionsWrapper).empty();
    jQuery(that.extensionsWrapper).append("<div class='alert alert-error'>"+ error_msg + "</div>");
  },
  cancelInstall: function(e) {
    window.location.hash = "";
    this.loadAppInfo(e);
  },
  loadAppInfo: function(e){
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);
    if(jQuery(el).hasClass("closable")){
      e.preventDefault();
      e.stopPropagation();
    }
    else{
      var ele = jQuery(el);
      this.getAppInfo(ele, false);
    }
  },

  getAppInfo: function(obj, isSuggestion){
    var that = this,
        url;

    if(isSuggestion){
      that.isSearched = false;
      url = obj;
    }else{
      url = jQuery(obj).attr("data-url");
    }

    jQuery.ajax({
      url: url,
      type: "GET",
      beforeSend: function(){
        that.showLoader();
      },
      success: function(extensions){
        jQuery(that.extensionsWrapper).empty()
                                    .append(JST["marketplace/marketplace_show"](extensions));
        var isFromInstalled = isSuggestion ? false : jQuery(obj).hasClass("moreinfo-lnk");

        jQuery(document).trigger({
          type: "viewed_app_description_page",
          app_name: extensions.display_name,
          developed_by: extensions.account,
          is_suggestion: isSuggestion,
          is_from_search: that.isSearched,
          is_from_installed : isFromInstalled,
          time: new Date()
        });

        that.appName = extensions.display_name;
        that.appType = extensions.app_type;
        that.type = extensions.type;
        that.developedBy = extensions.account;

        if(!isSuggestion){
          if(jQuery(obj).hasClass("moreinfo-lnk")){
            jQuery(".app-name").css("padding-left", "15px");
            jQuery(".dtl-box").removeClass("head-spacer");
          }
          else{
           jQuery("#fa-nav").css("display", "inline-block");
           jQuery(".dtl-box").addClass("head-spacer");
          }
        }

        that.manageShowMore();
      },
      error: function(jqXHR, exception) {
        that.showErrorMsg(that.customMessages.no_connection);
      }
    });
  },

  getOauthIparams: function(e) {
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);
    jQuery.ajax({
      url: jQuery(el).attr("data-url"),
      type: "GET",
      beforeSend: function(){
        that.showLoader();
      },
      success: function(extension) {
        jQuery(that.extensionsWrapper).empty().append(JST["marketplace/marketplace_install_v2"](extension));
      },
      error: function(jqXHR, exception) {
        that.showErrorMsg(that.customMessages.no_connection);
      }
    })
  },

  manageShowMore: function(){
    var showChar = 600,  // How many characters are shown by default
        ellipsis = "...",
        moretext = "more",
        lesstext = "less",
        content  = jQuery(".descript").html();

    if(content && content.length > showChar) {

        var c = content.substr(0, showChar);
        var h = content.substr(showChar, content.length - showChar);

        var html = c + '<span class="moreellipses">' + ellipsis+ '&nbsp;</span><span class="morecontent"><span>' + h + '&nbsp;&nbsp;</span><a href="" class="morelink">' + moretext + '</a></span>';

        jQuery(".descript").html(html);
    }

    jQuery(".morelink").click(function(){
      if(jQuery(this).hasClass("less")) {
          jQuery(this).removeClass("less");
          jQuery(this).html(moretext);
      } else {
          jQuery(this).addClass("less");
          jQuery(this).html(lesstext);
      }
      jQuery(this).parent().prev().toggle();
      jQuery(this).prev().toggle();
      return false;
    });
  },

  displayError: function(error) {
    jQuery("#install-error").show().text(error);
    jQuery(".install-form").css("height", "calc(100vh - 230px)");
  },

  installOAuthApp: function(e) {
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);

    var url = jQuery('.install-oauth-btn').attr('data-url');
    if (jQuery(el).attr("data-page") == "oauth_iparams") {
      if (!validate()) {
          return that.displayError(that.customMessages.validation_failed);
        }
      url += "?oauth_iparams=" + JSON.stringify(postConfigs());
    }
    jQuery.ajax({
      url: url,
      type: "GET",
      success: function(resp_body, statustext, resp){
        that.platformVersion == '2.0' ? parent.location = resp_body.redirect_url : window.location = resp_body.redirect_url;
      },
      error: function(jqXHR, exception) {
        that.showErrorMsg(that.customMessages.no_connection);
      }
    });
  },

  getIparams: function() {
    if (this.platformVersion === '2.0') {
      if (this.appInstance) {
        return this.appInstance.trigger({ type: 'custom_iparam.submit' });
      }
      return RSVP.Promise.resolve({ configs: '' });
    }

    var isEmpty = function isEmpty(index, value) {
      return jQuery.trim(jQuery(value).val()).length == 0;
    }
    // validation for V1 apps
    var invalidElements = jQuery(".installer-form input.fa-textip.required").filter(isEmpty);
    if (invalidElements.length > 0) {
      // Display V1 form validation error
      this.displayError(this.customMessages.field_blank);
      return RSVP.Promise.reject();
    }

    // validation succeeds - return installation parameters.
    var configs = {};
    var configsObj = jQuery("#install-form").serialize().split('&')
              .map(function(e) { var x = e.split("="); if(x[0] != 'authenticity_token' && x[0] != "" && x[0]!= null) { 
                configs[x[0]] = decodeURIComponent(x[1]); 
              }});
    return RSVP.Promise.resolve({configs: configs,
                            authenticity_token: jQuery("#install-form input[name='authenticity_token']").val()});
  },

  submitIparams: function(el, params) {
    var that = this;
    var initialCount = 0;
    var data = { configs: params.configs == "" ? params.configs : Object.toJSON(params.configs) };
    if (this.platformVersion === '1.0') {
      data['authenticity_token'] = params.authenticity_token
    }
    jQuery.ajax({
      url: jQuery(el).attr("data-url"),
      type: jQuery(el).attr("data-method"),
      data: data,
      beforeSend: function(){
        that.handleInstallProgress();
      },
      success: function(resp_body, statustext, resp){
        if(resp.status == 200){
          that.handleInstallSuccess();
        } else if (resp.status == 202){
          var installedExtensionId = resp_body.installed_extension_id;
          setTimeout( function() {
            that.pollAccountApi(initialCount, that.pollRetryLimit, installedExtensionId);
          }, that.accApiPollInterval);
        } else {
          that.handleInstallFailure();
        }
      },
      error: function(jqXHR, exception) {
        that.handleInstallFailure();
      }
    });
  },

  //install button in install config page
  installApp: function(e){
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);

    this.getIparams().then(function(configs) {
      that.submitIparams(el, configs)
    }).catch(function(e) {
      if (e.hasOwnProperty('isValid') || !e.isValid) {
        return that.displayError(that.customMessages.validation_failed);
      }
      if (e.hasOwnProperty('method')) {
        return that.displayError(that.customMessages.error_calling_method + e.method + ' - ' + (e.error.message || JSON.stringify(e)));
      }
      return that.handleInstallFailure();
    });
  },
  handleInstallProgress: function() {
    jQuery("#install-error").hide();
    jQuery(".progress, .installing-text").show();
    jQuery(".install-form").hide();
    jQuery('.backbtn').attr('disabled', 'disabled');
    this.startProgress();
  },
  handleInstallSuccess: function() {
    // TODO: custom app_type should be removed after new ext type is added for custom app
    if((this.appType == app_details.get('custom_app_type')) || (this.type == app_details.get('custom_app_ext_type'))){
      jQuery(document).trigger({
        type: "installed_custom_app",
        app_name: this.appName,
        time: new Date()
      });
    } else {
      jQuery(document).trigger({
        type: "successful_installation",
        app_name: this.appName,
        developed_by: this.developedBy,
        time: new Date()
      });
    }
    jQuery('.install-form').remove();
    jQuery('.progress').removeClass('active');
    jQuery('.bar').css("width", "100%");
    if (parent.location.hash && parent.location.hash.match('^#[0-9]')) {
      parent.location.hash = "";
    }
    window.location.reload();
    clearInterval(this.progressInterval);
  },

  handleInstallFailure: function(message) {
    jQuery(".progress .bar").css("width", "0");
    clearInterval(this.progressInterval);
    var progEl = jQuery(".progress, .installing-text, .install-form");
    progEl.hide();
    var backUrl = jQuery('#fa-nav .backbtn').attr('data-url');
    var html = '<span>'+ this.customMessages.app_setup_error +'</span> ';
    html += 'Please <a class="backbtn" href data-url='+backUrl+'>try again</a>. ';
    html += 'If the error persists, please <a href="https://support.freshdesk.com">contact support.</a>';
    if (message) {
      html += '<div class="mkp-error-details"><a>View error details<a></div>';
      jQuery('.fa-installer .fa-hmeta').height('65px');
    }
    jQuery('.fa-hmeta').css('height', 'auto').html(html);
    jQuery('.mkp-error-details').click(function() {
      jQuery('.mkp-error-details').html('<p>'+ escapeHtml(message) +'<p>');
    });
  },

  pollAccountApi: function(count, maxCount, installedExtensionId) {
    var self = this;
    jQuery.ajax({
      url: '/admin/marketplace/installed_extensions/'+ installedExtensionId +'/app_status?event='+ this.action,
      type: "GET",
      success: function(resp_body, statustext, resp){
        self.handlePollSuccess(resp, count, maxCount, installedExtensionId);
      },
      error: function(jqXHR, exception) {
        self.handleInstallFailure();
      }
    })
  },

  handlePollSuccess: function(resp, count, maxCount, installedExtensionId) {
    var self = this;
    if (resp.status == 202 && count < maxCount) {
      count = count + 1;
      setTimeout( function() {
        self.pollAccountApi(count, maxCount, installedExtensionId);
      }, self.accApiPollInterval);
    } else if( resp.status == 200) {
      response = resp.responseJSON;
      switch (response.status) {
        case 'SUCCESS':
          self.handleInstallSuccess();
          break;
        case 'FAILED':
        case 'LIMBO':
          self.handleInstallFailure(response.message);
          break;
      }
    } else {
      self.handleInstallFailure();
    }
   },

  buyApp: function(e) {
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);

    jQuery.ajax({
      url: jQuery(el).attr("data-url"),
      type: 'get',
      data: {install_url: jQuery(el).attr("data-install-url")},
      dataType: 'json',

      success: function(extension){
        if ( extension.account_suspended ) {
          that.showErrorMsg(that.customMessages.suspended_plan_info);
        }
        else {
          jQuery(".overlay-content").html(extension.message);
          jQuery(".overlay").show();
          jQuery(document).trigger({
            app_name: that.appName,
            time: new Date()
          });
        }
      },
      error: function(jqXHR, exception) {
        that.showErrorMsg(that.customMessages.no_connection);
      }
    });
  },
  updatePaymentInfo: function(e) {
    jQuery('.overlay').attr('style', 'display: hide');
  },
  installNativeApp: function(e){
    jQuery("#nativeapp-form").submit();
    jQuery(".nativeapp").attr('disabled', 'disabled');
  },
  switchTabs: function(e) {
    var formClasses = {
      configs_tab: 'install-form',
      logs_tab: 'logs-form'
    };
    var toShow = e.target.id;
    var toHide = toShow === 'configs_tab' ? 'logs_tab' : 'configs_tab';

    jQuery('.' + formClasses[toHide]).css('display', 'none');
    jQuery('.' + formClasses[toShow]).css('display', '');
    jQuery('#' + toShow).addClass('active');
    jQuery('#' + toHide).removeClass('active');
  },
  parseLogs: function(logs) {
    function safeJSONParse(string) {
      try {
        return JSON.parse(string);
      } catch(e) {
        return {};
      }
    }

    function isLog(log) {
      return log && log.length !== 0;
    }

    function transform(log) {
      var splitAt = log.indexOf(' ');

      log = [ log.slice(0, splitAt), log.slice(splitAt + 1) ];

      var timestamp = log[0];
      var log = safeJSONParse(log[1]);

      return {
        timestamp: (new Date(timestamp || '')).toLocaleTimeString(),
        id: (log.RequestId || '').slice(-5),
        type: log.type || 'info',
        message: log.message || ''
      };
    }

    return logs.split('\n').filter(isLog).map(transform);
  },

  appBrowserClosed: function() {
    this.isAppBrowserOpened = false;
  },

  downloadLogs: function(url, extensionId) {
    var self = this;

    jQuery.ajax({
      method: 'GET',
      url: url,
      success: function(response) {
        self.renderLogsTab({
          url: url,
          table_header: self.loggerOptions.messages.FOUND_LOGS,
          logs: self.parseLogs(response)
        }, extensionId);
      },
      error: self.renderLogsTab.bind(this, {
        message: self.loggerOptions.messages.ERROR_FETCHING_LOGS
      }, extensionId)
    })
  },
  renderLogsTab: function(params, extensionId) {
    var logsForm = jQuery('.logs-form');

    if (logsForm.attr('data-extension_id') == extensionId && this.isAppBrowserOpened) {
      logsForm.html(JST['marketplace/marketplace_install_logs'](params));
    }
  },
  pollLogAPI: function() {
    var self = this;
    var count = self.loggerOptions.count;

    function poll(extensionId, versionId) {
      /**
       *  The two extension ID will be different only if the slider has been opened
       *  for a new app. If this is the case, stop polling. Don't poll if the app
       *  browser is closed.
       */
      if (self.extensionId != extensionId || !self.isAppBrowserOpened) {
        return;
      }

      jQuery.ajax({
        url: '/mkp/data-pipe.json',
        method: 'POST',
        dataType: 'json',
        data: {
          data_pipe: {
            action: 'retrieve',
            type: 'view'
          }
        },
        headers: {
          'MKP-EXTNID': extensionId,
          'MKP-VERSIONID': versionId,
          'MKP-ROUTE': 'log'
        },
        success: function(response) {
          if (response.status === self.loggerOptions.status.IN_PROGRESS) {
            if (--count <= 0) {
              return self.renderLogsTab({
                message: self.loggerOptions.messages.TAKING_TOO_LONG
              }, extensionId);
            }

            return setTimeout(poll.bind(null, extensionId, versionId), self.loggerOptions.logsAPIPollInterval);
          }

          if (response.status === self.loggerOptions.status.OK) {
            return self.downloadLogs(response.url, extensionId);
          }

          if (response.status === self.loggerOptions.status.NO_CONTENT) {
            return self.renderLogsTab({
              message: self.loggerOptions.messages.NO_LOGS_FOUND
            }, extensionId);
          }

          return self.renderLogsTab({
            message: self.loggerOptions.messages.ERROR_FETCHING_LOGS
          }, extensionId);
        },
        error: self.renderLogsTab.bind(self, {
          message: self.loggerOptions.messages.ERROR_FETCHING_LOGS
        }, extensionId)
      });
    }
    self.renderLogsTab({
      loading_message: self.loggerOptions.messages.LOADING
    }, self.extensionId);;
    poll(self.extensionId, self.versionId);
  },

  // Custom installation page set iframe container height
  setFormHeight: function() {
    var appContainer = jQuery(".app-container", this.extensionsWrapper);
    var installFormPadding = jQuery('.install-form').innerHeight() - jQuery('.install-form').height();
    var configsFormPadding = jQuery('.configs-form').innerHeight() - jQuery('.configs-form').height();
    var footerHeight = jQuery('.button-container-v2').outerHeight();
    var headerHeight = jQuery('.fa-hmeta').outerHeight();
    var sliderHeight = jQuery('.app-browser').outerHeight();
    var installStatus = jQuery('.install-status').outerHeight();
    var breadcumbHeight = jQuery('#fa-nav').outerHeight();
    var height = sliderHeight - footerHeight - headerHeight - installFormPadding - configsFormPadding - installStatus - breadcumbHeight;
    jQuery(appContainer).css({ 'padding-bottom': height+ 'px' });
  },

  updateApp: function(e) {
    e.preventDefault();
    e.stopPropagation();
    var that = this;

    var el = jQuery(e.currentTarget);
    jQuery.ajax({
      url: jQuery(el).attr("data-url"),
      type: jQuery(el).attr("data-method"),
      dataType: 'json',
      beforeSend: function(){
        that.showLoader();
      },
      success: function(install_extension){
        install_extension.self = install_extension;
        that.extensionId = install_extension.extension_id;
        that.versionId = install_extension.version_id;
        that.action = install_extension.install_btn['text'].toLowerCase();
        that.isAppBrowserOpened = true;

        jQuery(document).one("click.tmpl_events", ".tab#logs_tab" , that.pollLogAPI.bindAsEventListener(that));

        if ( install_extension.account_suspended ) {
          that.showErrorMsg(that.customMessages.suspended_plan_info);
        }
        else {
          jQuery(that.extensionsWrapper).empty()
                                        .append(JST["marketplace/marketplace_install_base"](install_extension));
          if (install_extension.configs_url) {
            var app = {
              'id': that.extensionId,
              'versionId': that.versionId,
              'locations': {
                'custom_iparam': {
                  'url': install_extension.configs_url,
                }
              },
              'features': install_extension.features,
              'configs': install_extension.configs
            }
            that.appInstance = that.marketplaceManager.createInstance(app);
            var appContainer = jQuery(".app-container", that.extensionsWrapper);
            jQuery('.button-container').addClass('button-container-v2');
            that.setFormHeight();
            jQuery(appContainer).html(that.appInstance.element); // Embed Configs IFrame
          }
          if ( install_extension.configs_page && install_extension.configs != null ){
            that.whenAvailable('getConfigs', install_extension.configs);
          }

          that.appName = install_extension.display_name;

          if(jQuery(el).attr("data-developedby") != undefined){
            that.developedBy = jQuery(el).attr("data-developedby");
          }

          jQuery(document).trigger({
              type: "km_install_config_page_loaded",
              app_name: that.appName,
              developed_by: that.developedBy,
              time: new Date()
          });
          if ( !install_extension.configs_page && !install_extension.configs_url && (!install_extension.configs ? true : install_extension.configs.length == 0 )) { // no config
            jQuery(".install-form").hide();
            setTimeout( that.installTrigger('.install-btn'), 1000);
          }

          if(jQuery(el).hasClass("btn-settings")){
            jQuery("#fa-nav").css("display", "none");
            jQuery(".fa-hmeta").removeClass("head-spacer");

            jQuery(".button-container .show_btn").addClass("closable");
          }
          else{
           jQuery("#fa-nav").css("display", "inline-block");
           jQuery(".fa-hmeta").addClass("head-spacer");
           jQuery(".button-container .show_btn").removeClass("closable");
          }
        }
      },
      error: function(jqXHR, exception) {
        that.showErrorMsg(that.customMessages.no_connection);
      }
    });

  },

  whenAvailable: function(methodName, configs) {
    var interval = 10;
    window.setTimeout(function(){
      if(window[methodName]) {
        getConfigs(configs)
      }
      else {
        window.setTimeout(arguments.callee, interval);
      }
    }, interval);
  },

  updateIframeApp: function(e){
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);

    jQuery.ajax({
      url: jQuery(el).attr("data-url"),
      type: jQuery(el).attr("data-method"),
      beforeSend: function(){
        that.showLoader();
      },
      success: function(install_extension){
        jQuery(that.extensionsWrapper).empty()
                                      .append(JST["marketplace/marketplace_iframe_settings"](install_extension));

        that.appName = install_extension.display_name;

        if(jQuery(el).attr("data-developedby") != undefined){
          that.developedBy = jQuery(el).attr("data-developedby");
        }

        jQuery(document).trigger({
            type: "km_install_config_page_loaded",
            app_name: that.appName,
            developed_by: that.developedBy,
            time: new Date()
        });

        if(install_extension.iframe_url){
          var iframeHelper = new MarketplaceIframeHelper();
          iframeHelper.createSandboxedIframe(install_extension.iframe_url);
        }
        else{
          that.showErrorMsg(that.customMessages.no_connection);
        }
      },
      error: function(jqXHR, exception) {
        that.showErrorMsg(that.customMessages.no_connection);
      }
    });
  },

  onSearch: function(e){
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);
    jQuery.ajax({
      type: 'get',
      url: jQuery(el).attr("action"),
      data: jQuery(el).serialize(),
      beforeSend: function(){
        that.showLoader();
      },
      success: function(jqXHR, exception){
        jqXHR['category_specific'] = false;
        jQuery(that.extensionsWrapper).empty()
                                      .append(JST["marketplace/marketplace_list"](jqXHR));
        that.isSearched = true;
      },
      error: function(jqXHR, exception) {
        that.showErrorMsg(that.customMessages.no_connection);
      }
    });
  },

  reinstateURL: function(e){
    e.preventDefault();
    e.stopPropagation();
    window.history.pushState(null, null, this.tabName);
  },

  destroy: function(obj){
    jQuery(obj).off(".tmpl_events");
  }
});
