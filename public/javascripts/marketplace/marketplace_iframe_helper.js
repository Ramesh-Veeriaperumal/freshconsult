var MarketplaceIframeHelper = Class.create({


  initialize: function () {
    //jQuery(document).on('load_iframe_app',this.createSandboxedIframe)


  },

  createSandboxedIframe: function (url) {
    this.sandbox = oasis.createSandbox({
      url: url,
      type: 'html',
      capabilities: ['fd_iframe'],
      sandbox: {
        allowSameOrigin: true
      }
    });
    jQuery('#fa_iframe_wrapper').append(this.sandbox.el).find('iframe').height('100%').width('100%');
    this.startListening();
  },

  startListening: function() {
    this.sandbox.connect('fd_iframe').then(function (port) {
    });
  }

});




