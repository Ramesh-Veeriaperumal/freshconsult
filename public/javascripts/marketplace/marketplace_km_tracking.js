// For Marketplace -- Kissmetrics tracking
  var mktplace_domain, selected_app;
  // viewed integrations home - Number of visits to the top level Apps page
  jQuery(document).on("script_loaded", function (ev, data) {
    App.Marketplace.Metrics.push_event("Viewed Apps Home Page", mktplace_domain);
  });

  //clicked browse apps button -Number of visits to the App Gallery 
  jQuery(document).on("click.km_track_evt", ".button-bar .browse-apps-btn", function(){
    App.Marketplace.Metrics.push_event(
      "Opened App Gallery",
      { "Domain Name": mktplace_domain,
        "Opened App Gallery from" : "Browse apps button"
      }
    );
  });
  //clicked blank slate browse apps button - Number of visits to the App Gallery 
  jQuery(document).on("click.km_track_evt", ".btn-appgallery", function(){
    App.Marketplace.Metrics.push_event(
      "Opened App Gallery",
      { "Domain Name": mktplace_domain,
        "Opened App Gallery from" : "Blank state browse apps button"
      }
    );
  });

  //clicked blank slate browse apps button - Number of visits to the App Gallery
  jQuery(document).on("click.km_track_evt", ".fa-dd .category" , function(e){
    App.Marketplace.Metrics.push_event(
      "Filtered App Gallery",
      { "Domain Name": mktplace_domain,
        "App Category" : e.target.innerText.trim()
      }
    );
  });

  //clicked app box in app gallery - Number of visits to each app’s description page
  jQuery(document).on("viewed_app_description_page", function(e){
    var _viewedAppFrom;
    switch(true){
      case e.is_suggestion:
        _viewedAppFrom = "App Gallery Search Suggestion";
        break;
      case e.is_from_search:
        _viewedAppFrom = "App Gallery Search Result";
        break;
      case e.is_from_installed:
        _viewedAppFrom = "Installed App Listing";
        break;
      default:
        _viewedAppFrom = "App Gallery Listing";
    }

    App.Marketplace.Metrics.push_event(
      "Viewed app description",
      { "Domain Name": mktplace_domain,
        "App Name": e.app_name,
        "Viewed app description page from": _viewedAppFrom
      }
    );
  });

  //clicked install button in app gallery description page
  jQuery(document).on("click.km_track_evt", ".install-app", function(e){
    App.Marketplace.Metrics.push_event(
      "Clicked Install App Button in Description Page", 
      { "Domain Name": mktplace_domain, 
        "App Name": templateDockManager.appName,
        "Developed By": templateDockManager.developedBy
      } 
    );
  });

  jQuery(document).on("km_install_config_page_loaded", function(e){
    App.Marketplace.Metrics.push_event(
      "Viewed Installation Config Page", 
      { "Domain Name": mktplace_domain, 
        "App Name": e.app_name,
        "Developed By": e.developed_by
      }
    );
  });

  //clicked install button in install config page,
  //developer name also recorded from install config page
  jQuery(document).on("click.km_track_evt", ".install-form .install-btn", function(e){
    App.Marketplace.Metrics.push_event(
      "Installed App from Config Page", 
      { "Domain Name": mktplace_domain, 
        "App Name": templateDockManager.appName,
        "Developed By": templateDockManager.developedBy
      }
    );
  });

  jQuery(document).on("successful_installation", function (e) {
    App.Marketplace.Metrics.push_event(
      "Successful Installation", 
      { "Domain Name": mktplace_domain, 
        "App Name": e.app_name,
        "Developed By": e.developed_by
      }
    );
  });

  //When Custom App is installed successfully
  jQuery(document).on("installed_custom_app", function (e) {
    App.Marketplace.Metrics.push_event(
      "Installed custom app", 
      { "Domain Name": mktplace_domain, 
        "App Name": e.app_name
      }
    );
  });

  //when an app enabled
  jQuery(document).on("enabled_app", function(e){
    App.Marketplace.Metrics.push_event(
      "Enabled App", 
      { "Domain Name" : mktplace_domain, 
        "Enabled App Named" : e.app_name 
      } 
    );
  });

  //when an app disabled
  jQuery(document).on("disabled_app", function(e){
    App.Marketplace.Metrics.push_event(
      "Disabled App", 
      { "Domain Name" : mktplace_domain, 
        "Disabled App Named" : e.app_name 
      } 
    );
  });

  //search term
  jQuery(document).on("submit.km_track_evt", "#extension-search-form", function(e){
    var search_term = jQuery(e.target).find("#query").val();
    App.Marketplace.Metrics.push_event(
      "Searched App Gallery", 
      { "Searched Term": search_term, 
        "Searched By": mktplace_domain
      } 
    );
  });

  //clicked Uninstall App button
  jQuery(document).on("click.km_track_evt", ".plug-actions .delete-btn", function(e){
    selected_app = jQuery(e.currentTarget).parents(".plug-data").find(".plug-name").text().trim()
  });

  //Confirming Uninstall App button
  jQuery(document).on("click.km_track_evt", ".delete-confirm", function(){
    if(jQuery("#apps").hasClass("active")){
      App.Marketplace.Metrics.push_event(
        "Uninstalled App",
        { "Domain Name": mktplace_domain,
          "App uninstalled": selected_app
        } 
      );
    }
  });
  //create new plug button clicked -additional
  jQuery(document).on("click.km_track_evt", ".new-customapp", function(){
    App.Marketplace.Metrics.push_event( "Clicked Create New Custom App Button", mktplace_domain);
  });

  //Clicked get custom apps button
  jQuery(document).on("click.km_track_evt", ".get-custom-apps", function(){
    App.Marketplace.Metrics.push_event( "Clicked get custom apps button", mktplace_domain);
  });

  //Clicked custom apps tab
  jQuery(document).on("click.km_track_evt", ".cla-plugs", function(){
    App.Marketplace.Metrics.push_event( "Clicked custom apps tab", mktplace_domain);
  });

  /* Kissmetrics tracking code block ends */
