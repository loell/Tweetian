/*
    Copyright (C) 2012 Dickson Leong
    This file is part of Tweetian.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 1.1
import com.nokia.symbian 1.1
import "Services/Twitter.js" as Twitter
import "storage.js" as Storage
import "Component"
import "MainPageCom"
import UserStream 1.0
import "MainPageCom/UserStream.js" as StreamScript

Page {
    id: mainPage

    property Item timeline: timeline
    property Item mentions: mentions
    property Item directMsg: directMsg

    onStatusChanged: if(status == PageStatus.Activating) loadingRect.visible = false

    tools: ToolBarLayout{
        ToolButtonWithTip{
            property Component __exitDialog: null
            iconSource: platformInverted ? "Image/close_stop_inverse.svg" : "Image/close_stop.svg"
            toolTipText: "Exit"
            onClicked: {
                if(!__exitDialog) __exitDialog = Qt.createComponent("Dialog/ExitDialog.qml")
                __exitDialog.createObject(mainPage)
            }
        }
        ToolButtonWithTip{
            iconSource: platformInverted ? "Image/edit_inverse.svg" : "Image/edit.svg"
            toolTipText: qsTr("New Tweet")
            onClicked: pageStack.push(Qt.resolvedUrl("NewTweetPage.qml"), {type: "New"})
        }
        ToolButtonWithTip{
            iconSource: "toolbar-search"
            toolTipText: qsTr("Trends & Search")
            onClicked: pageStack.push(Qt.resolvedUrl("TrendsPage.qml"))
        }
        ToolButtonWithTip{
            iconSource: platformInverted ? "Image/contacts_inverse.svg" : "Image/contacts.svg"
            toolTipText: qsTr("My profile")
            onClicked: pageStack.push(Qt.resolvedUrl("UserPage.qml"), {screenName: settings.userScreenName})
        }
        ToolButtonWithTip{
            iconSource: "toolbar-menu"
            toolTipText: qsTr("Menu")
            onClicked: mainMenu.open()
        }
    }

    Menu{
        id: mainMenu
        platformInverted: settings.invertedTheme

        MenuLayout{
            MenuItem{
                text: qsTr("Refresh cache")
                enabled: !mainView.currentItem.busy
                platformInverted: mainMenu.platformInverted
                onClicked: mainView.currentItem.refresh("all")
            }
            MenuItem{
                text: qsTr("Settings")
                platformInverted: mainMenu.platformInverted
                onClicked: pageStack.push(Qt.resolvedUrl("SettingPage.qml"))
            }
            MenuItem{
                text: qsTr("About")
                platformInverted: mainMenu.platformInverted
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }
    }

    ListView{
        id: mainView

        function moveToColumn(index){
            columnMovingAnimation.to = index * mainView.width
            columnMovingAnimation.restart()
        }

        NumberAnimation{
            id: columnMovingAnimation
            target: mainView
            property: "contentX"
            duration: 500
            easing.type: Easing.InOutExpo
        }

        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        highlightRangeMode: ListView.StrictlyEnforceRange
        model: VisualItemModel{
            TweetListView{ id: timeline; type: "Timeline" }
            TweetListView{ id: mentions; type: "Mentions" }
            DirectMessage{ id: directMsg }
        }
        snapMode: ListView.SnapOneItem
        orientation: ListView.Horizontal
        boundsBehavior: Flickable.StopAtBounds
    }

    Connections{
        target: settings
        onSettingsLoaded: {
            Twitter.init(constant, settings.oauthToken, settings.oauthTokenSecret)
            if(settings.oauthToken == "" || settings.oauthTokenSecret == ""){
                pageStack.push(Qt.resolvedUrl("SignInPage.qml"))
            }
            else{
                timeline.initialize()
                mentions.initialize()
                directMsg.initialize()
                StreamScript.initialize()
                StreamScript.saveUserInfo()
            }
        }
    }

    MainPageHeader{ id: header }

    UserStream{
        id: userStream
        onDataRecieved: StreamScript.streamRecieved(rawData)
        onDisconnected: StreamScript.reconnectStream(statusCode, errorText)
        // make sure missed tweets is loaded after connected
        onStatusChanged: if(status === UserStream.Connected) StreamScript.refreshAll()

        property bool firstStart: true

        Timer{
            id: reconnectTimer
            interval: 30000
            onTriggered: {
                StreamScript.log("Timer triggered, connecting to user stream")
                if(userStream.firstStart){
                    interval = 5000
                    userStream.firstStart = false
                }
                var obj = Twitter.getUserStreamURLAndHeader()
                userStream.connectToStream(obj.url, obj.header)
            }
        }

        Timer{
            id: timeOutTimer
            interval: 90000 // 90 seconds as describe in <https://dev.twitter.com/docs/streaming-apis/connecting>
            running: userStream.status == UserStream.Connected
            onTriggered: {
                reconnectTimer.interval = 5000
                StreamScript.log("Timeout error, disconnect and reconnect in "+reconnectTimer.interval/1000+"s")
                userStream.disconnectFromStream()
                reconnectTimer.restart()
            }
        }

        // connect or disconnect stream when streaming settings is changed
        Connections{
            id: streamingSettingsConnection
            target: null
            onEnableStreamingChanged: {
                if(networkMonitor.online){
                    if(settings.enableStreaming){
                        reconnectTimer.interval = userStream.firstStart ? 30000 : 5000
                        StreamScript.log("Streaming enabled by user, connect to streaming in "+reconnectTimer.interval/1000+"s")
                        reconnectTimer.restart()
                    }
                    else{
                        StreamScript.log("Streaming disabled by user, disconnect from streaming")
                        reconnectTimer.stop()
                        userStream.disconnectFromStream()
                    }
                }
            }
        }

        // connect or disconnect stream when networkMonitor.online is changed
        Connections{
            id: onlineConnection
            target: null
            onOnlineChanged: {
                if(settings.enableStreaming){
                    if(networkMonitor.online){
                        reconnectTimer.interval = userStream.firstStart ? 30000 : 5000
                        StreamScript.log("App going online, connect to streaming in " + reconnectTimer.interval/1000+"s")
                        reconnectTimer.restart()
                    }
                    else{
                        StreamScript.log("App going offline, disconnect from streaming")
                        reconnectTimer.stop()
                        userStream.disconnectFromStream()
                    }
                }
            }
        }
    }
}
