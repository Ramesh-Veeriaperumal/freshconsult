
BoxChooser = Class.create(); 
var winpos = {};

function clip_filename(s, maxlen){
  if(s.length <= maxlen) return s;
  var filename, ext='';
  filename = s.split('.')
  if(filename.length>1){
    ext = filename.pop()
    filename = filename.join('.')
  } else { filename = s;}

  if(filename.length > maxlen){filename = filename.substring(0, maxlen) + '... .'}

  return filename+ext.toUpperCase();
}

function blockChooser(){
  jQuery('body').block({
          message: " <h1>...</h1> ",
          css: {
            display: 'none',
            backgroundColor: '#e9e9e9',
            border: 'none',
            color: '#FFFFFF',
            opacity:0
          },
          overlayCSS: {
            backgroundColor: '#e9e9e9',
            opacity: 0.6,
            "z-index": 1050
          }
        });
}

function unblockChooser(){
  jQuery('body').unblock();
}

function maximize() {
  winpos = winpos || {};
  winpos.innerWidth = window.innerWidth;
  winpos.innerHeight = window.innerHeight;
  winpos.screenX = window.screenX || window.screenLeft;
  winpos.screenY = window.screenY || window.screenTop;
  if(window.opener) window.opener.window.Box.chooser_pos = winpos;

  window.moveTo(0,0);
  window.resizeTo(screen.width, screen.height);
}

function restore(){
  if(window.opener && (window.opener.window.Box.chooser_pos)){
    winpos = window.opener.window.Box.chooser_pos;
    window.resizeTo(winpos.innerWidth, winpos.innerHeight);
    window.moveTo(winpos.screenX, winpos.screenY);
    window.opener.window.Box.chooser_pos = null;
    window.opener.chooser_reloading = true;
    location.reload();
  }
}

BoxChooser.prototype = {
  list_item: new Template('<li class="box-item" data-item-id="#{item_id}" data-item-type="#{type}"> \
                <a href="#"><span class="name-holder">#{name}</span>#{arrow_span}</a> \
              </li>'),
  navbar_item: new Template('<div class="box-item"><span data-item-id="#{item_id}">#{name}</span></div>'),
  
  initialize: function(boxBundle) {
    if(boxBundle.auth_status === 'failed') {
      window.close();
    } else if(!boxBundle.oauth_token) {
      performOAuth();
    } else {
      boxChooser = this
      this.options = boxBundle
      this.options.app_name = 'box'
      this.options.domain = 'api.box.com'
      this.options.auth_type = 'OAuth'
      this.options.useBearer=true
      this.options.ssl_enabled = true
      this.fw = new Freshdesk.Widget(this.options)
      this.item_id_to_entry = {}
      this.get_folder_items((function(){
        if(window.opener && window.opener.window.Box) 
          return (window.opener.window.Box.init_folder_id || 0);
        return 0;
      })())
      restore()
    }
  },

  get_folder_items: function(folder_id){
    var url = '2.0/folders/' + folder_id;
    this.last_accessed_folder_id = folder_id;
    if(this.isDuplicateRequest(url)) return;
    var req = {
      rest_url: url,
      method: 'get',
      on_success: function(response){ this.populate_files(response, folder_id, url) }.bind(this),
      on_failure: this.handle_request_failure.bind(this),
      custom_callbacks: { on0: this.handle_broken_request.bind(this) }
    }
    this.fw.request(req)
  },

  get_item_by_id: function(itemId){
    return this.item_id_to_entry[itemId]
  },

  populate_files: function(response, folder_id, url){
    
    if(url!=this.last_requested_url) return;
    this.last_requested_url = null; // To make sure refresh of same folder works. else isDuplicateRequest would block it.
    if(window.opener && window.opener.window.Box){
      window.opener.window.Box.init_folder_id = folder_id;
    }
    // Parse the data.
    res = response.responseJSON;
    res.item_collection.entries.sort(function(a, b){
      return (a.type==b.type) ? a.name.localeCompare(b.name) : (a.type=='folder' ? -1 : 1);
    });
    var list_markup = '';
    res.item_collection.entries.each(function(entry, index){
      arrow_span_html = (entry.type=='folder'?'<span class="arrow-right"></span>':'');
      list_markup += this.list_item.evaluate({name: clip_filename(entry.name, 35), item_id: entry.id, type: entry.type, arrow_span: arrow_span_html});
      entry.parent_id = folder_id;
      this.item_id_to_entry[entry.id] = entry;
    }.bind(this));
    if(list_markup=='')
      list_markup = "<li><p class=\"empty-folder\">Folder Empty<br><span><!--This folder doesn't contain any file or folder.--></span></p></li>";
    jQuery("#box-left-list").html(list_markup);
    this.path_collection = res.path_collection;
    max_depth = res.path_collection.total_count;
    min_depth = Math.max(0, max_depth-4);
    var navbar_html = '';
    if(min_depth){ navbar_html += this.navbar_item.evaluate({item_id: 'na', name: '...'}); }
    for(i=min_depth+1; i<max_depth; i++){
      entry = this.path_collection.entries[i];
      navbar_html += this.navbar_item.evaluate({item_id: entry.id, name: entry.name}); 
    }
    if(Number(res.id))
      navbar_html += this.navbar_item.evaluate({item_id: res.id, name: '<b>'+res.name+'</b>'});
    jQuery('#box-navbar').html(navbar_html);
    jQuery(".box-loading-big").hide();
  },

  handle_request_failure: function(evt){
    if(evt.status == 401){
      performOAuth();
      return true; 
    } else if(evt.status == 404){
        boxChooser.get_folder_items(0);
        return true;
    } else {
      jQuery('span.loading-circle').removeClass('sloading loading-circle loading-left').addClass('arrow-right');
      jQuery(".box-loading-big").hide();
      this.last_requested_url = null;
      unblockChooser();
    }       
  },

  handle_broken_request: function(response){  
    if(window.opener && window.opener.chooser_reloading) {
      window.opener.chooser_reloading = false;
      return;
    };
    alert('The connection to Box was interrupted. Please check your network and try again or contact support if problem persists.');
    jQuery('span.loading-circle').removeClass('sloading loading-circle loading-left').addClass('arrow-right');
    jQuery(".box-loading-big").hide();
    this.last_requested_url = null;
    unblockChooser();
  },

  attach_file: function(file){
    shared_link = file.shared_link
    url = shared_link[shared_link.permissions.can_download ? 'url' : 'download_url']
    window.opener.Box.on_choose([{name: file.name, link: url, provider: 'box'}],
      window.box_attaching_document, JSON.stringify({name: file.name, link: url, provider: 'box'}))
    window.close()
  },

  isDuplicateRequest: function(url){
    if(url==this.last_requested_url) return true;
    this.last_requested_url = url;
    return false;
  },

  createSharedLink: function(){
    boxChooser.fw.request({
      method: 'put',
      rest_url: '2.0/files/' + entry.id,
      body: '{"shared_link": {"access": "open"}}',
      on_success: function(response){ boxChooser.attach_file(response.responseJSON); unblockChooser(); },
      after_failure: function(response){ boxChooser.handle_request_failure(response); },
      custom_callbacks: {
        on0: boxChooser.handle_broken_request.bind(boxChooser),
        on403: boxChooser.error_insufficient_permission.bind(boxChooser)
       }
    });                   
  },

  error_insufficient_permission: function(response){

    var data = {
        targetId: "#box-error-modal",
        title: "Access Denied",
        width: "420",
        backdrop: "static",
        templateFooter: false,
        destroyOnClose: true
    }

    jQuery.freshdialog(data);
  }

};

jQuery(document).on('click', '#box-error-button', function(){
  jQuery('.modal').modal('hide');
})

jQuery('div#box-navbar').on('click.box_chooser', 'div.box-header div.box-item span:not([data-item-id=na])', function(e) {
  jQuery(".box-loading-big").show();
  boxChooser.get_folder_items(jQuery(this).data('item-id'));
});

function performOAuth(){
  jQuery.cookie('return_uri', document.location.href, {path: '/'});
  maximize();
  document.location.href = boxBundle.oauth_url;
}

var autoClose = false; 
function confirmSecurityDowngrade(dTitle, dContent, y, n, callback){
  jQuery("div.box-confirm-modal-content").html(dContent);

  var data = {
        targetId: "#box-confirm-modal",
        title: dTitle,
        width: "450",
        backdrop: "static",
        templateFooter: false,
        destroyOnClose: true
    }

    jQuery.freshdialog(data);
}

jQuery(document).on('click', '#box-confirm-yes', function(){
  jQuery('.modal').modal('hide');
  boxChooser.createSharedLink();
})

jQuery(document).on('click', '#box-confirm-no', function(){
  jQuery('.modal').modal('hide');
  boxChooser.attach_file(entry); 
})

jQuery(document).on('click', '#box-confirm-cancel', function(){
  jQuery('.modal').modal('hide');
})

jQuery('div#box-content-pane li.box-item').live('click', function(e){
  e.preventDefault();
  element = jQuery(this)
  element.find('span.arrow-right').removeClass('arrow-right').addClass('sloading loading-circle loading-left');
  jQuery('div#box-content-pane li.box-item').not(element).find('span.sloading').removeClass('sloading loading-circle loading-left').addClass('arrow-right')
  if(element.data('item-type')=='file'){
    boxChooser.fw.request({
      method: 'get',
      rest_url: '2.0/files/' + element.data('item-id'),
      on_success: function(request){
                    entry = request.responseJSON;
                    if(entry.shared_link){
                      if(entry.shared_link.access != 'open'){
                        if (entry.shared_link.access=='collaborators')
                          msg = "This file has been shared only with specific collaborators. ";
                        else if(entry.shared_link.access=='company')
                          msg = "This file has been shared only with specific collaborators. ";
                        msg += "Would you like to make this link public before you share it?";
                        createSharedLink = confirmSecurityDowngrade("", msg, "Yes", "No", function(update){
                                            if(update)
                                              this.createSharedLink();
                                            else
                                              boxChooser.attach_file(entry);  
                                          }.bind(boxChooser));
                      } else { boxChooser.attach_file(entry);  }
                    } else { boxChooser.createSharedLink(); }
                  },
      after_failure: function(response){boxChooser.handle_request_failure(response);},
      custom_callbacks: {
        on0: boxChooser.handle_broken_request.bind(boxChooser)
      }
    });
    // blockChooser();
  } else if(element.data('item-type')=='folder'){
    boxChooser.get_folder_items(element.data('item-id'))
  }
});

boxChooser = new BoxChooser(boxBundle);
