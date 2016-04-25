// For Marketplace -- Kissmetrics tracking
  var mktplace_domain, selected_app;
  // viewed integrations home - Number of visits to the top level Apps page
  jQuery(document).on("script_loaded", function (ev, data) {
    App.Marketplace.Metrics.push_event("Viewed Apps Home Page", mktplace_domain);
  });

  //clicked browse apps button -Number of visits to the App Gallery 
  jQuery(document).on("click.km_track_evt", ".button-bar .browse-btn", function(){
    App.Marketplace.Metrics.push_event("Clicked Browse Apps Button", mktplace_domain);
  });
  //clicked blank slate browse apps button - Number of visits to the App Gallery 
  jQuery(document).on("click.km_track_evt", ".btn-appgallery", function(){
    App.Marketplace.Metrics.push_event("Clicked Blank State Browse Apps Button", mktplace_domain);
  });

  //clicked app box in app gallery - Number of visits to each app’s description page
  jQuery(document).on("viewed_app_description_page", function(e){
    App.Marketplace.Metrics.push_event(
      "Viewed App Description Page", 
      { "Domain Name": mktplace_domain, 
        "App Name": e.app_name,
        "Viewed From Search Suggestions": e.is_suggestion,
        "Viewed From Search Results" : e.is_from_search
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
  jQuery(document).on("click.km_track_evt", ".create-new .btn, .new-customapp", function(){
    App.Marketplace.Metrics.push_event( "Clicked Create New Custom App Button", mktplace_domain);
  });
  /* Kissmetrics tracking code block ends */