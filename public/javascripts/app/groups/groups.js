/*jslint browser: true */
/*global App */

/*
*  groups.js
*  author: Rajasegar
*  Common script for manipulating Groups - new, edit
*/

window.App = window.App || {};

window.App.Groups = window.App.Groups || {};
window.App.Channel = window.App.Channel || new MessageChannel();

(function($) {
    'use strict';


    App.Groups = {
        currentModule: '',

        onFirstVisit: function(data){
            this.onVisit(data);
        },

        onVisit: function(data){
            this.setSubModule();
            this.bindHandlers();
            if(this.currentModule !== ''){
                this[this.currentModule].onVisit();
            }
        },

        setSubModule: function(){
            switch(App.namespace){
                case 'groups/index':
                    this.currentModule = 'Index';
                    break;
                case 'groups/edit':
                    this.currentModule = 'Edit';
                    break;
                case 'groups/new':
                    this.currentModule = 'New';
                    break;
                default:
                    break;
            }
        },

        bindHandlers: function(){
            this.startWatchRoutes();
        },

        startWatchRoutes: function () {
          jQuery(document).one('pjax:success', function() {
            var isIframe = (window !== window.top);
            if (isIframe) {
              // Transfer data through the channel
              window.App.Channel.port1.postMessage({ action: "update_iframe_url", path: location.pathname });
            }
          });
        },

        onLeave: function(data){
            if(this.currentModule !== ''){
                this[this.currentModule].onLeave();
                this.currentModule = '';
            }
        }
    };


}(window.jQuery));
