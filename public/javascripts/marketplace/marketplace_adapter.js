var MarketplaceAdapter = Class.create({
  initialize: function initialize() {
  },
  getAdapter: function getAdapter() {
    function getLocations() {
      return {
        'custom_iparam': {
          'services': {}
        }
      }
    }
    /**
     *  jQuery used here is very old and the promise it returns 
     *  doesnt conform to ES6 standard. So we are wrapping it with
     *  the promise in the window which is hopefully polyfilled to
     *  meet the standard.
     */
    function wrappedAJAX(options) {
      return new RSVP.Promise(function(resolve, reject) {
        var request = jQuery.ajax(options);
        request.done(resolve);
        request.fail(reject);
      });
    }
    return {
      Promise: RSVP.Promise,
      ajax: wrappedAJAX,
      csrfToken: jQuery('meta[name=csrf-token]').attr('content'),
      page: 'custom_iparam',
      product: 'freshdesk',
      locations: getLocations(),
      accountID: current_account_id,
      domain: window.location.origin,
      isInstall: true
    };
  }
});