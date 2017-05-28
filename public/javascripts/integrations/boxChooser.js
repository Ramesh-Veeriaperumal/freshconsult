
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
  searchBar: new Template('<div class="box-search-bar"><div class="box-search inline-block"><input type="text" id="box-search-text" placeholder="Search in #{name}"></div>#{pageDirection}</div>'),
  pageDirection: new Template('<div class="page-info inline-block">#{number} of #{total}</div><div class="page-navigation inline-block"><label class="btn btn-prev disabled"><span class="arrow-previous"></span></label><label class="btn btn-next"><span class="arrow-next"></span></label></div>'),
  
  initialize: function(boxBundle) {
    if(boxBundle.auth_status === 'failed') {
      window.close();
    } else if(!boxBundle.oauth_token) {
      performOAuth();
    } else {
      boxChooser = this
      this.folder_items = [];
      this.pageSize = 100; // The number of files per pages for Both API limit and the UI.
      this.current_page_id = '';
      this.current_page_size = 0;
      this.options = boxBundle
      this.options.app_name = 'box'
      this.options.domain = 'api.box.com'
      this.options.auth_type = 'OAuth'
      this.options.useBearer=true
      this.options.ssl_enabled = true
      this.set_folder_actions();
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

  set_folder_actions: function(){
    // For Navigation between Pages.
    jQuery(document).on('click', '#box-content-pane .btn', function(){
      var pageNumberSelector = "div[id*=page-number]";
      var previousPage = (jQuery(this).attr("class").indexOf("btn-prev") != - 1);
      // navPage denotes the next or prev page depending on the selection.
      var navPage = previousPage ? jQuery("#"+boxChooser.current_page_id).prev(pageNumberSelector) : jQuery("#"+boxChooser.current_page_id).next(pageNumberSelector);
      navPage.removeClass("hide");
      boxChooser.current_page_id = jQuery(navPage[0]).attr("id");
      var currPage = boxChooser.current_page_id.split("_").last();
      jQuery(".page-info").text(currPage + " of " + boxChooser.current_page_size);
      if(previousPage){
        if(jQuery(navPage[0]).prev(pageNumberSelector).length == 0){
          jQuery("#box-content-pane .btn-prev").addClass("disabled");
        }
        if(jQuery(navPage[0]).next(pageNumberSelector).length > 0){
          jQuery("#box-content-pane .btn-next").removeClass("disabled");
        }
      }else{
        if(jQuery(navPage[0]).next(pageNumberSelector).length == 0){
          jQuery("#box-content-pane .btn-next").addClass("disabled");
        }
        if(jQuery(navPage[0]).prev(pageNumberSelector).length > 0){
          jQuery("#box-content-pane .btn-prev").removeClass("disabled");
        }
      }
      jQuery('div[id*="page-number"]:not(#'+ boxChooser.current_page_id + ')').addClass("hide");  
    });

    // For search inside Folders.
    jQuery(document).on('input', '.box-search', function(){
      var searchTerm = jQuery('#box-search-text').val();
      if(!searchTerm){
        jQuery('div[id*="page-number"]:not(#'+ boxChooser.current_page_id + ')').addClass("hide");
        jQuery('#box-content-pane .page-info').show();
        jQuery('#box-content-pane .page-navigation').show();
        jQuery(".box-item").show();
      }else{
        jQuery('#box-content-pane .page-info').hide();
        jQuery('#box-content-pane .page-navigation').hide();
        jQuery('div[id*="page-number"]').removeClass("hide");
        jQuery('#box-content-pane .box-item').each(function(){
          if(jQuery(this).text().toUpperCase().indexOf(searchTerm.toUpperCase()) != -1){
            jQuery(this).show();
          }else{
            jQuery(this).hide();
          }
        });
      }
    });
  },

  get_folder_items: function(folder_id, curOffset){
    var baseURL = '2.0/folders/' + folder_id + "?limit=" + this.pageSize;
    var url = (!curOffset) ? baseURL : ( baseURL +  "&offset=" + curOffset );
    this.last_accessed_folder_id = folder_id;
    if(this.isDuplicateRequest(url)) return;
    var req = {
      rest_url: url,
      method: 'get',
      on_success: function(response){ this.get_paginated_items(response, folder_id, url) }.bind(this),
      on_failure: this.handle_request_failure.bind(this),
      custom_callbacks: { on0: this.handle_broken_request.bind(this) }
    }
    this.fw.request(req)
  },

  get_paginated_items: function(response, folder_id, url){
    var res = response.responseJSON;
    var curOffset = res.item_collection.offset;
    var totalPages = res.item_collection.total_count;
    if(curOffset == 0){
      this.folder_items =[];
    }
    this.folder_items = this.folder_items.concat(res.item_collection.entries);
    if( (totalPages - curOffset) < this.pageSize){
      this.populate_files(response, this.folder_items, folder_id, url);
    }
    else{
      this.get_folder_items(folder_id, curOffset + this.pageSize);
    }
  },

  get_item_by_id: function(itemId){
    return this.item_id_to_entry[itemId]
  },

  populate_files: function(response, itemCollection, folder_id, url){
    var _this = this;
    if(url!=this.last_requested_url) return;
    this.last_requested_url = null; // To make sure refresh of same folder works. else isDuplicateRequest would block it.
    if(window.opener && window.opener.window.Box){
      window.opener.window.Box.init_folder_id = folder_id;
    }
    // Parse the data.
    res = response.responseJSON;
    itemCollection.sort(function(a, b){
      return (a.type==b.type) ? a.name.localeCompare(b.name) : _this.checkItemisFolder(a.type);
    });
    var list_markup = '';
    var page;
    var folderName = ( res.name == "All Files" ) ? "Folder" : res.name;
    // Page navigation only if page size is greater than 1.
    var pageDirectionTemplate = JST["app/integrations/box/paginate_files"]({ 
      number: "1", 
      total: Math.floor(itemCollection.length / this.pageSize) + 1 
    });
    list_markup += JST["app/integrations/box/search_bar"]({ 
      name: clip_filename(htmlEntities(folderName), 35), 
      pageDirection: pageDirectionTemplate 
    });
    itemCollection.each(function(entry, index){
      if(index == 0){
        page = 1;
        this.current_page_id = 'page-number_' + folder_id + '_'+ page;
        list_markup += '<div id="'+ this.current_page_id + '">';
      }else{
        if(index % 100 == 0){ 
          page++;          
          list_markup += '</div>';
          list_markup += '<div id="page-number_' + folder_id + '_'+ page + '" class="hide">';
        }
      }
      arrow_span_html = (entry.type=='folder'?'<span class="arrow-right"></span>':'');
      list_markup += JST["app/integrations/box/list_item"]({
        name: clip_filename(htmlEntities(entry.name), 35), 
        item_id: entry.id, type: entry.type, 
        arrow_span: arrow_span_html
      });
      entry.parent_id = folder_id;
      this.item_id_to_entry[entry.id] = entry;
      if (index == (itemCollection.length - 1)){
        list_markup += '</div>';
      }
    }.bind(this));
    list_markup += ( itemCollection.length > this.pageSize ) ? ('<div class= "bottom-nav"><div class="box-search inline-block"></div>' + pageDirectionTemplate + '</div>') : '';
    this.current_page_size = page;
    if(itemCollection.length == 0){
      list_markup = "<li><p class=\"empty-folder\">Folder Empty<br><span><!--This folder doesn't contain any file or folder.--></span></p></li>";
    }
    jQuery("#box-left-list").html(list_markup);
    this.path_collection = res.path_collection;
    max_depth = res.path_collection.total_count;
    min_depth = Math.max(0, max_depth-4);
    var navbar_html = '';
    if(min_depth){ navbar_html += this.navbar_item.evaluate({item_id: 'na', name: '...'}); }
    for(i=min_depth+1; i<max_depth; i++){
      entry = this.path_collection.entries[i];
      navbar_html += this.navbar_item.evaluate({item_id: entry.id, name: htmlEntities(entry.name) }); 
    }
    if(Number(res.id))
      navbar_html += this.navbar_item.evaluate({item_id: res.id, name:'<b>'+htmlEntities(res.name) +'</b>'});
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
  },

  checkItemisFolder: function(type){
    return (type == 'folder') ? -1 : 1 ;
  }

};

jQuery(document).on('click', '#box-error-button', function(){
  jQuery('.modal').modal('hide');
})

jQuery(document).on('click', 'div.box-header div.box-item span:not([data-item-id=na])', function(e) {
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

jQuery('.box-chooser-body').on('click', 'div#box-content-pane li.box-item', function(e){
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
