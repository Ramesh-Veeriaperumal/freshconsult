var TemplateDockManager   = Class.create({
  initialize: function(extensionsEl, customMsgs, tabName) {
    this.extensionsWrapper = extensionsEl;
    this.customMessages = customMsgs;
    this.progressInterval;
    this.chosenCategory = "All";
    this.tabName = tabName;

    this.bindTemplateEvents();
    this.setupCarousel();

    jQuery(document).on( "mousewheel.tmpl_events DOMMouseScroll.tmpl_events", ".app-browser, .dtl-box, .dd-left, .install-form", function(ev){
      if (ev.originalEvent) ev = ev.originalEvent;
      var delta = ev.wheelDelta || -ev.detail;
      this.scrollTop += (delta < 0 ? 1 : -1) * 20;
      ev.preventDefault();
    });
  },
  bindTemplateEvents: function(){
    jQuery(document).on("click.tmpl_events", ".browse-btn,.category,.index_btn,.in-dev-apps" , this.loadApps.bindAsEventListener(this))
                    .on("click.tmpl_events", ".fplugs-box,.backbtn, .show_btn" , this.loadAppInfo.bindAsEventListener(this))
                    .on("click.tmpl_events", ".install-btn" , this.installApp.bindAsEventListener(this))
                    .on("click.tmpl_events", ".install-form-btn, .update" , this.updateApp.bindAsEventListener(this))
                    .on("submit.tmpl_events", "form#search-extension-form" , this.onSearch.bindAsEventListener(this))
                    .on("click.tmpl_events", "[id^=carousel-selector-]" , this.carouselSelector.bindAsEventListener(this))
                    .on("click.tmpl_events", ".fa-tabd a", this.reinstateURL.bindAsEventListener(this));
  },
  setupCarousel: function(){
    jQuery("#screenshotsCarousel").livequery(function(){
      jQuery(this).carousel({
        interval: 5000
      });
      jQuery(this).on('slid', function (e) {
        var item = jQuery('#screenshotsCarousel .carousel-inner .item.active');
        // Deactivate all nav links
        jQuery('.slider-thumbs li').removeClass('active');
        //to activate the nav link based on slide
        var index = item.index() + 1;
        jQuery('.slider-thumbs li:nth-child(' + index + ')').addClass('active');
      });
    });
  },
  carouselSelector: function(e){
    var id_selector = jQuery(e.currentTarget).attr("id");
    var id = id_selector.substr(id_selector.length -1);
    var id = parseInt(id);
    jQuery('#screenshotsCarousel').carousel(id);
  },
  showLoader: function(){
    jQuery(this.extensionsWrapper).empty();
    jQuery(this.extensionsWrapper).append('<div class="sloading loading-block"></div>');
  },
  getObjConstr: function(i){
    var screenshots_no = {
      "screenshots_no" : i
    };
    return screenshots_no;
  },
  installTrigger: function(){
    jQuery(".install-btn").trigger("click");
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
        if(jQuery(el).hasClass("browse-btn") || jQuery(el).hasClass("in-dev-apps"))
          that.chosenCategory = "All";
        else if(jQuery(e.currentTarget).hasClass("category"))
          that.chosenCategory = jQuery(e.currentTarget).text();
        else
          that.chosenCategory = that.chosenCategory;
      },
      success: function(jqXHR, exception){
        jQuery(that.extensionsWrapper).empty();
        jQuery('#freshplug_listing_template').tmpl(jqXHR).appendTo(that.extensionsWrapper);
        if(jQuery(el).hasClass("category") || jQuery(el).hasClass("index_btn")){
          jQuery('#categoryname').text("/ " + that.chosenCategory);
          jQuery(el).parent(".dd-categories").hide();
        }
      },
      error: function(jqXHR, exception) {
        jQuery(that.extensionsWrapper).empty();
        jQuery(that.extensionsWrapper).append("<div class='alert alert-error'>"+ that.customMessages.no_connection + "</div>");
      }
    });
  },
  loadAppInfo: function(e){
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
      success: function(extensions){
        jQuery(extensions.screenshots).each(function(index){
          jQuery.extend( extensions.screenshots[index], that.getObjConstr(index) );
        });
        jQuery(that.extensionsWrapper).empty();
        jQuery('#freshplug_details_template').tmpl(extensions).appendTo(that.extensionsWrapper);
      }
    });
  },
  installApp: function(e){
    e.preventDefault();
    e.stopPropagation();
    var that = this;
    var el = jQuery(e.currentTarget);
  
    var isFormValid = true;
    jQuery(".installer-form input.fa-textip").each(function(index, value){
      if (jQuery.trim(jQuery(value).val()).length == 0){
        isFormValid = false;
      }
    });

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
        success: function(install_extension){
          if(install_extension.status == 200){
            jQuery('.install-form').remove();
            jQuery('.progress').removeClass('active');
            jQuery('.bar').css("width", "100%");
            parent.location.reload();
          } else {
            jQuery("#install-error").show().text(that.customMessages.install_error);
            jQuery(".progress, .installing-text").hide();
            jQuery('.backbtn').removeAttr('disabled');
            jQuery(".install-form").show();
            jQuery(".progress .bar").css("width", "0");
          }
          clearInterval(that.progressInterval);
        }
      });
    }else{
      jQuery("#install-error").show().text(that.customMessages.field_blank);
      jQuery(".install-form").css("height", "calc(100vh - 230px)");
    }
  },
  updateApp: function(e){
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
        jQuery(that.extensionsWrapper).empty();
        jQuery('#install_new_template').tmpl(install_extension).appendTo(that.extensionsWrapper);
        if(install_extension.configs == null  ) { // no config
          jQuery(".install-form").hide();
          setTimeout( that.installTrigger, 1000);
        }
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
      success: function(extensions) {
        jQuery(that.extensionsWrapper).empty();
        jQuery('#freshplug_listing_template').tmpl(extensions).appendTo(that.extensionsWrapper);
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