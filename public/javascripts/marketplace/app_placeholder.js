var appPlaceholder = appPlaceholder || {};

(function(appPh){

  init:(function (){
    placeholderEl = {
      //ticket details page placeholders
      //customButtonBar: "[data-domhelper-name='ticket-action-options']",
      moreOption: "[data-domhelper-name='more-collapse-list']",
      ticketSidebar: "[data-domhelper-name='ticket-details-sidebar']",
      belowRequestorInfo: "[data-domhelper-name='requester_info']",
      requestorInfo: "[data-domhelper-name='requester_info']",
      tabLinkInRequestorInfo: "[data-domhelper-name='requester_info'] [data-domhelper-name='tkt-tabs']",
      tabContentInRequestorInfo: "[data-domhelper-name='requester_info'] [data-domhelper-name='tkt-tabs-wrap']",
      //contact page placeholder
      contactSidebar: "[data-domhelper-name='contact-sidebar']"
    }
    
  })();

  // Helper Object Methods (API)
  if(page_type == "ticket"){
    appPlaceholder.ticket = {  
      /* should document: sample code snippet with UI guidelines. for navBarButton.
        <li class='ticket-btns'>
          <a href='' class='btn'></a>
        </li>
      */
      /*navBarButton: function(myApp){
        if(appPlaceholderValidator.checkParams("navBarButton", myApp)){  
          jQuery(placeholderEl.customButtonBar).append(myApp);
        }
      }, */

      navBarList: function(myApp){
        if(appPlaceholderValidator.checkParams("navBarList", myApp)){
          /* should document: sample code snippet with UI guidelines. It is: 
            
              <a href='/helpdesk/tickets/4/print' target='_blank'>My New Option</a>
            
          */
          if(tktDetailDom){
            tktDetailDom.getElement('collapse-list', function() {
              jQuery(placeholderEl.moreOption).append(myApp);
            });
          }
        }
      },

      sidebar: function(myApp){
        if(appPlaceholderValidator.checkParams("sidebar", myApp)){
          // should document: sample code snippet with UI guidelines -- markup can be anything
          jQuery(placeholderEl.ticketSidebar).append(myApp);
        }
      },

      requestorInfo: function(myApp) {
        if(appPlaceholderValidator.checkParams("requestorInfo", myApp)){
          // should document: sample code snippet with UI guidelines -- markup can be anything
          jQuery(placeholderEl.requestorInfo).append(myApp);
        }
      },

      belowRequestorInfo: function(myApp) {
        if(appPlaceholderValidator.checkParams("belowRequestorInfo", myApp)){
          // should document: sample code snippet with UI guidelines -- markup can be anything
          jQuery(myApp).insertAfter(placeholderEl.belowRequestorInfo);
        }
      },

      requestorInfoTab: function( myApp ){ 
        if(appPlaceholderValidator.checkParams("requestorInfoTab", myApp)){
          // should document: sample code snippet with UI guidelines -- markup can be anything
          /*
              Tab :
              <a href="#contact_info_salesforce" class="requester-info-sprite requester-info-salesforce" data-tab="tab"></a>

              TabContent: 
              <div id="contact_info_salesforce" class="requester_tab" style="display: none;" data-tab-content="tabContent">
              </div>
          */

          jQuery('.requester-info-sprite').parents('.tkt-tabs').show();

          var tabIcon = jQuery(myApp).find("[data-tab-icon='tab']");

          jQuery(placeholderEl.tabContentInRequestorInfo).append(jQuery(myApp));
          jQuery(placeholderEl.tabLinkInRequestorInfo).append(jQuery("<li>", {}).append(jQuery(tabIcon)));
          
        }
      }
    };
  }

  if(page_type == "contact"){
    appPlaceholder.contact = {

      //contact sidebar API
      sidebar: function(myApp){
        if(appPlaceholderValidator.checkParams("sidebar", myApp)){
          jQuery(placeholderEl.contactSidebar).append(myApp);
        }
      }

    };
  }

})(appPlaceholder);
