
document.addEventListener('chat onConnect', function(){
    bindEvent();
}, false);

document.addEventListener('chat disConnect', function(){
    unbindEvent();
}, false);
var bindEvent = function(){
    window.freshchat.chatIcon = true;
    jQuery('.list_agents_replying').on('click','.agent_detail',function (){
        if(!jQuery('.agent_detail').hasClass('clickDisable')){
            jQuery('.agent_detail').addClass('clickDisable');
            var id = jQuery('.agent_detail').attr('id');
            window.agentCollision.Chat(id);
            setTimeout(function() {
                jQuery('.agent_detail').removeClass('clickDisable');
            },3500);
        }
    });

    jQuery('.list_agents_replying').live('hover','.agent_detail',function (){
        jQuery('.agent_detail').css({'cursor':'pointer'});
        jQuery('.more_agents').css({'cursor':'pointer'});
    });

    jQuery('.list_agents_replying').live('mouseleave','.agent_detail a',function(){
        jQuery('.twipsy.in').hide();
    })

    jQuery('body').on('hover','.hover_card .agent_name',function(e){
        jQuery('.agent_name').css({'cursor':'pointer'});
    });

    jQuery('body').on('click','.hover_card .agent_name',function(e){
        var id = jQuery(this).attr('id');
        window.agentCollision.Chat(id);
        jQuery('.hover-card-agent').parent().remove();
        jQuery('.twipsy.in').hide();
    }) ;  
};

var unbindEvent = function(){
    jQuery('body').off('click','.hover_card .agent_name');
    jQuery('.list_agents_replying').off('click','.agent_detail');
    window.freshchat.chatIcon = false;
}; 



  
