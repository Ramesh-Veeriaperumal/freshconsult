/*jslint browser: true, devel: true */
/*global  App:true */

DataStore = DataStore || {};

(function ($) {
    "use strict";
    var badges = [
        { 'badges' : { "name" : "Support hero",      "classname" : "badges-a-small-call",          "id" :  1 } },
        { 'badges' : { "name" : "Explorer",          "classname" : "badges-a-small-elephant",      "id" :  2 } },
        { 'badges' : { "name" : "Social supporter",  "classname" : "badges-small-fb",              "id" :  3 } },
        { 'badges' : { "name" : "Zeus",              "classname" : "badges-small-fcr",             "id" :  4 } },
        { 'badges' : { "name" : "Commentor",         "classname" : "badges-small-forum",           "id" :  5 } },
        { 'badges' : { "name" : "Heart",             "classname" : "badges-small-love",            "id" :  6 } },
        { 'badges' : { "name" : "Local",             "classname" : "badges-a-small-priority",      "id" :  7 } },
        { 'badges' : { "name" : "The fixer",         "classname" : "badges-small-settings",        "id" :  8 } },
        { 'badges' : { "name" : "Bulls eye",         "classname" : "badges-small-shooter",         "id" :  9 } },
        { 'badges' : { "name" : "Smile collector",   "classname" : "badges-a-smiley",              "id" : 10 } },
        { 'badges' : { "name" : "Timekeeper",        "classname" : "badges-small-time",            "id" : 11 } },
        { 'badges' : { "name" : "Champion",          "classname" : "badges-small-trophy",          "id" : 12 } },
        { 'badges' : { "name" : "Super commentor",   "classname" : "badges-small-forum-comment",   "id" : 13 } },
        { 'badges' : { "name" : "Guest of honor",    "classname" : "badges-small-winner",          "id" : 14 } },
        { 'badges' : { "name" : "Banker",            "classname" : "badges-a-small-money",         "id" : 15 } },
        { 'badges' : { "name" : "Perfectionist",     "classname" : "badges-a-small-glasses",       "id" : 16 } },
        { 'badges' : { "name" : "Bibliophile",       "classname" : "badges-a-small-closed-book",   "id" : 17 } },
        { 'badges' : { "name" : "Druid",             "classname" : "badges-a-small-experiment",    "id" : 18 } },
        { 'badges' : { "name" : "Statistician",      "classname" : "badges-a-small-chart",         "id" : 19 } },
        { 'badges' : { "name" : "Sweet-tooth",       "classname" : "badges-a-small-cake",          "id" : 20 } },
        { 'badges' : { "name" : "Socialite",         "classname" : "badges-a-small-martini",       "id" : 21 } },
        { 'badges' : { "name" : "Rocket scientist",  "classname" : "badges-a-small-rocket",        "id" : 22 } },
        { 'badges' : { "name" : "Anchor",            "classname" : "badges-a-small-sailor",        "id" : 23 } },
        { 'badges' : { "name" : "Ace",               "classname" : "badges-a-small-spade",         "id" : 24 } },
        { 'badges' : { "name" : "Speed eater",       "classname" : "badges-small-gamer",           "id" : 25 } },
        { 'badges' : { "name" : "Night owl",         "classname" : "badges-a-small-late-worker",   "id" : 26 } },
        { 'badges' : { "name" : "Gentleman",         "classname" : "badges-small-the-professional","id" : 27 } },
        { 'badges' : { "name" : "Traveller",         "classname" : "badges-a-small-traveller",     "id" : 28 } },
        { 'badges' : { "name" : "Writer",            "classname" : "badges-small-writer",          "id" : 29 } },
        { 'badges' : { "name" : "Performer",         "classname" : "badges-a-small-performer",     "id" : 30 } },
        { 'badges' : { "name" : "Best seller",       "classname" : "badges-small-open-book",       "id" : 31 } },
        { 'badges' : { "name" : "Tweet supporter",   "classname" : "badges-small-tweet",           "id" : 32 } },
        { 'badges' : { "name" : "Bomber man",        "classname" : "badges-a-small-radiation",     "id" : 33 } },
        { 'badges' : { "name" : "Striker",           "classname" : "badges-a-small-player",        "id" : 34 } },
        { 'badges' : { "name" : "Conversationalist", "classname" : "badges-a-small-messenger",     "id" : 35 } },
        { 'badges' : { "name" : "The Diamond",       "classname" : "badges-a-small-diamond",       "id" : 36 } },
        { 'badges' : { "name" : "Super writer",      "classname" : "badges-small-scribe",          "id" : 37 } },
        { 'badges' : { "name" : "Lucky clover",      "classname" : "badges-a-small-clover",        "id" : 38 } },
        { 'badges' : { "name" : "Gameboy",           "classname" : "badges-small-joystick",        "id" : 39 } },
        { 'badges' : { "name" : "Beacon",            "classname" : "badges-a-small-lamp",          "id" : 40 } },
        { 'badges' : { "name" : "Flag bearer",       "classname" : "badges-a-small-flag",          "id" : 41 } },
        { 'badges' : { "name" : "Cafeholic",         "classname" : "badges-a-small-coffee",        "id" : 42 } },
        { 'badges' : { "name" : "Bureaucrat",        "classname" : "badges-a-small-business-man",  "id" : 43 } },
        { 'badges' : { "name" : "Artist",            "classname" : "badges-a-small-artist",        "id" : 44 } },
        { 'badges' : { "name" : "Minute-man",        "classname" : "badges-a-small-calendar",      "id" : 45 } }
    ]

    DataStore.set('badges', badges);

}(window.jQuery));
