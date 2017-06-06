var TemplateDockManager   = Class.create({
  initialize: function(extensionsEl, customMsgs, tabName) {
    this.extensionsWrapper = extensionsEl;
    this.customMessages = customMsgs;
    this.progressInterval;
    this.tabName = tabName;
    this.isSearched = false;
    this.appName;
    this.developedBy;

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
                    .on("click.tmpl_events", ".install-btn" , this.installApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".install-form-btn, .update" , this.updateApp.bindAsEventListener(this))
                    .on("click.tmpl_events", "#oauth_link", this.installOAuthApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".install-iframe-settings, .update-iframe-settings" , this.updateIframeApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".nativeapp" , this.installNativeApp.bindAsEventListener(this))
                    .on("submit.tmpl_events", "form#extension-search-form" , this.onSearch.bindAsEventListener(this))
                    .on("click.tmpl_events", "[id^=carousel-selector-]" , this.carouselSelector.bindAsEventListener(this))
                    .on("click.tmpl_events", ".fa-tabd a", this.reinstateURL.bindAsEventListener(this))
                    .on("click.tmpl_events", ".remove-query", this.resetQuery.bindAsEventListener(this))
                    .on("click.tmpl_events", ".carousel-dot", this.carouselDotNav.bindAsEventListener(this))
                    .on("click.tmpl_events", ".carousel", this.carouselScroll.bindAsEventListener(this))
                    .on("click.tmpl_events", ".toggle_policy" , this.togglePolicyInfo.bindAsEventListener(this))
                    .on("click.tmpl_events", ".buy-app" , this.buyApp.bindAsEventListener(this))
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

  manageShowMore: function(){
    var showChar = 600,  // How many characters are shown by default
        ellipsis = "...",
        moretext = "more",
        lesstext = "less",
        content  = jQuery(".descript").html();
 
    if(content.length > showChar) {

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

  isValidForm: function() {
    var isFormValid = true;
    jQuery(".installer-form input.fa-textip.required").each(function(index, value){
      if (jQuery.trim(jQuery(value).val()).length == 0){
        isFormValid = false;
      }
    });
    return isFormValid;
  },

  displayFormFieldError: function() {
    jQuery("#install-error").show().text(this.customMessages.field_blank);
    jQuery(".install-form").css("height", "calc(100vh - 230px)");
  },

  installOAuthApp: function(e) {
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var parameters = "";
    var elements = jQuery('.fa-elements');
    if(this.isValidForm()) {
      for( var i = 0; i < elements.length; i++ ){
        if(elements[i].name && elements[i].value) {
          parameters += parameters + '&' + elements[i].name + '=' + elements[i].value;
        }
      }
      var url = jQuery('#oauth_link').attr('data-url');
      window.location = url + parameters;
    }
    else {
      this.displayFormFieldError();

    }
  },

  //install button in install config page
  installApp: function(e){
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);
  
    var isFormValid = true;
    isFormValid = this.isValidForm(e);

    if(isFormValid ){
      jQuery.ajax({
        url: jQuery(el).attr("data-url"),
        type: jQuery(el).attr("data-method"),
        data: jQuery('#install-form').serialize(),
        beforeSend: function(){
          jQuery("#install-error").hide();
          jQuery(".progress, .installing-text").show();
          jQuery(".install-form").hide();
          jQuery('.backbtn').attr('disabled', 'disabled');
          that.startProgress();
        },
        success: function(resp_body, statustext, resp){
          if(resp.status == 200){
            if(that.appType == app_details.get('custom_app_type')){
              jQuery(document).trigger({
                type: "installed_custom_app",
                app_name: that.appName,
                time: new Date()
              });
            } else {
              jQuery(document).trigger({
                type: "successful_installation",
                app_name: that.appName,
                developed_by: that.developedBy,
                time: new Date()
              });
            }

            jQuery('.install-form').remove();
            jQuery('.progress').removeClass('active');
            jQuery('.bar').css("width", "100%");
            if (parent.location.hash && parent.location.hash.match('^#[0-9]')) {
              parent.location.hash = "";
            }
            parent.location.reload();
          } else {
            jQuery("#install-error").show().text(that.customMessages.api_error);
            jQuery(".progress, .installing-text").hide();
            jQuery('.backbtn').removeAttr('disabled');
            jQuery(".install-form").show();
            jQuery(".progress .bar").css("width", "0");
          }
          clearInterval(that.progressInterval);
        },
        error: function(jqXHR, exception) {
          that.showErrorMsg(that.customMessages.api_error);
        }
      });
    }else{
      this.displayFormFieldError();
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
  updateApp: function(e){
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
        if ( install_extension.account_suspended ) {
          that.showErrorMsg(that.customMessages.suspended_plan_info);
        }
        else {
          jQuery(that.extensionsWrapper).empty()
                                        .append(JST["marketplace/marketplace_install"](install_extension));

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


          if( !install_extension.configs.length ) { // no config
            jQuery(".install-form").hide();
            if(install_extension.install_btn['is_oauth_app']) {
              trigger_element = '#oauth_link'
            }
            else {
              trigger_element = '.install-btn'
            }
            setTimeout( that.installTrigger(trigger_element), 1000);
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