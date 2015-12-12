var IlosWidget = Class.create();
IlosWidget.prototype= {
    
  initialize : function( ilosEntityId, ilosUserId ){
    this.ilosEntityId = ilosEntityId;
    this.ilosUserId = ilosUserId;
    this.freshdeskWidget = new Freshdesk.Widget({
      app_name: 'ilos',
      use_server_password: false,
      auth_type: 'NoAuth',
      domain: "https://www.ilosvideos.com",
    });
  },

  ticketPageParams: function(options){
    var privateNote = jQuery('#ilos_private_note').is(':checked') ? true : false,
        videoEndPoint = location.origin + "/integrations/ilos/ticket_note", 
        ticketDisplayId = this.ilosEntityId,
        videoDesc = jQuery.trim(jQuery('#ilos-desc').val()),
        videoTitle = jQuery.trim(jQuery('#ilos-title').val());
    if( videoTitle == "" ){
      videoTitle = jQuery('#ilos-title').attr('placeholder');
    }        
    var extras = {'video_desc':videoDesc,'video_title':videoTitle,"resource_id":ticketDisplayId,"user_id":this.ilosUserId,"private_note":privateNote,"incoming":options.incoming};

    this.getRecorderToken( videoEndPoint, videoTitle, extras);  
  },

  forumPageParams: function(options){
    var videoEndPoint = location.origin + "/integrations/ilos/forum_topic", 
        topicId = this.ilosEntityId,
        videoDesc = jQuery.trim(jQuery('#ilos-desc').val()),
        videoTitle = jQuery.trim(jQuery('#ilos-title').val());
    if( videoTitle == "" ){
        videoTitle = jQuery('#ilos-title').attr('placeholder');
    }
    var extras = {'video_desc':videoDesc,"resource_id":topicId,"user_id":this.ilosUserId, 'user_location':options.location};        

    this.getRecorderToken( videoEndPoint, videoTitle, extras);  
  },  

  solutionPageParams: function() {
    var videoEndPoint = location.origin + "/integrations/ilos/solution_article",
        articleId = this.ilosEntityId,
        videoDesc = jQuery.trim(jQuery('#ilos-desc').val()),
        videoTitle = jQuery.trim(jQuery('#ilos-title').val());
    if( videoTitle == "" ){
        videoTitle = jQuery('#ilos-title').attr('placeholder');
    }
    var extras = {'video_desc':videoDesc,"resource_id":articleId,"user_id":this.ilosUserId}; 
    this.getRecorderToken( videoEndPoint, videoTitle, extras);       
  },

  getRequestParams: function(requestBody){
    this.afterTokenEvent();
    return {
      rest_url: "api/auth/token",
      body: requestBody,
      content_type: 'application/x-www-form-urlencoded',
      method: "post",
      source_url: "/integrations/ilos/get_recorder_token",
      on_success: function(res){
        var resData = res.responseJSON;
        window.location.href = resData['recorderLaunchURI'];
      }
    }
  },

  afterTokenEvent: function(){
    jQuery("#disablingDiv").detach().appendTo('body');
    jQuery('#disablingDiv')[0].style.height = document.body.offsetHeight+"px";
    jQuery('#disablingDiv')[0].style.display='block';
    jQuery("#ilos-back-btn").on("click", function(){
      window.location.reload();
    })
    jQuery(window).on('popstate', function(){
      jQuery('#disablingDiv').remove();
    })
  },

  getRecorderToken: function( videoEndPoint, videoTitle, extras ){
    var requestBody =  
      { 'api_key_type':'user',
        'video_endpoint':videoEndPoint,
        'video_endpoint_extras':extras,
        'video_set_public':'true',
        'video_title':videoTitle,
        'record_single_video':'true'
      }
    this.freshdeskWidget.request(this.getRequestParams(JSON.stringify(requestBody)));
  },

  agent_ticket: function(){
    this.ticketPageParams({incoming:false});
  },

  agent_forum: function(){
    this.forumPageParams({location:"agent_forum"});
  },

  solution: function(){
    this.solutionPageParams();
  },

  portal_ticket: function(){
    this.ticketPageParams({incoming:true});
  },

  portal_forum: function(){
    this.forumPageParams({location:"portal_forum"});
  }
}

