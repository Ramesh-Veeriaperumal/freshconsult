// Handeling javascript framework wrappers to send CSRF token along with ajax requests
// In order for this to work there needs to be a csrf token added to the head section
// eg: <%= csrf_meta_tag %> 

// Altering the prototype framework
Ajax.Base.prototype.initialize = Ajax.Base.prototype.initialize.wrap(
    function (callOriginal, options) {
        var headers = options.requestHeaders || {},
            meta = $$('meta[name="csrf-token"]')[0];

        if (meta != undefined) {
            headers["X-CSRF-Token"] = meta.getAttribute('content');
            options.requestHeaders = headers;
        }

        return callOriginal(options);
    }
);

// Setting up jQuery to send csrf token in ajax requests

jQuery.ajaxSetup({
  headers: {
    'X-CSRF-Token': jQuery('meta[name="csrf-token"]').attr('content')
  }
});

window.add_csrf_token = function(form) {
    var token = jQuery('meta[name="csrf-token"]').attr('content') || null;
    if(token && !jQuery(form).find("[name=authenticity_token]").get(0)){
        jQuery(form).append("<input type='hidden' name='authenticity_token' value='"+token+"' />");
    }
}

// jQuery(document).on('submit.csrf', 'form', function(ev) {
//     add_csrf_token(this);
// });

jQuery('form').livequery(function(){
    if(jQuery(this).attr('data-csrf-ignore') !== "true") {
        add_csrf_token(this);
    }
})