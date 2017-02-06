/*jslint browser: true */
/*global App */

/*
 * groups_index.js
 * author: Rajasegar
 */

window.App = window.App || {};

window.App.Groups = window.App.Groups || {};

(function($){
    'use strict';

    App.Groups.Index = {
        currentModule: '',

        onFirstVisit: function(data){
            this.onVisit(data);
        },

        init: function(){
  
        },

        onVisit: function(data){
            this.init();
            this.bindHandlers();
            if(this.currentModule !== ''){
                this[this.currentModule].onVisit();
            }
        },

        bindHandlers: function(){
           
        },

        onLeave: function(data){
            if(this.currentModule !== ''){
                this[this.currentModule].onLeave();
                this.currentModule = '';
            }
        }



    };
}(window.jQuery));
