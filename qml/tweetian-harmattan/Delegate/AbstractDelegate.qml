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
import com.nokia.meego 1.0
import com.nokia.extras 1.1

Item{
    id: root

    property string sideRectColor: ""
    property string imageSource: profileImageUrl

    // read-only
    property bool highlighted: highlight.visible
    property Item profileImage: profileImageItem

    signal clicked
    signal pressAndHold

    property int __originalHeight: height

    implicitWidth: ListView.view ? ListView.view.width : 0
    implicitHeight: constant.graphicSizeLarge // should be override by height

    Image {
        id: highlight
        anchors.fill: parent
        visible: delegateMouseArea.pressed
        source: settings.invertedTheme ? "image://theme/meegotouch-panel-background-pressed"
                                       : "image://theme/meegotouch-panel-inverted-background-pressed"
    }

    Rectangle{
        id: bottomLine
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: constant.colorDisabled
    }

    Loader{
        id: sideRectLoader
        anchors{ left: parent.left; top: parent.top }
        sourceComponent: sideRectColor ? sideRect : undefined
    }

    Component{
        id: sideRect
        Rectangle{
            height: root.height - bottomLine.height
            width: constant.paddingSmall
            color: sideRectColor ? sideRectColor : "transparent"
        }
    }

    MaskedItem{
        id: profileImageItem
        anchors { left: parent.left; top: parent.top; margins: constant.paddingMedium }
        width: constant.graphicSizeMedium; height: constant.graphicSizeMedium
        mask: Image{ source: "../Image/pic_mask.png"}

        Image{
            id: profileImage
            anchors.fill: parent
            sourceSize{ width: parent.width; height: parent.height }
            asynchronous: true

            NumberAnimation {
                id: imageLoadedEffect
                target: profileImage
                property: "opacity"
                from: 0; to: 1
                duration: 250
            }

            Binding{
                id: imageSourceBinding
                target: profileImage
                property: "source"
                value: thumbnailCacher.get(root.imageSource)
                       || (networkMonitor.online ? root.imageSource : constant.twitterBirdIcon)
                when: false
            }

            Connections{
                id: movementEndedSignal
                target: null
                onMovementEnded: {
                    imageSourceBinding.when = true
                    movementEndedSignal.target = null
                }
            }

            onStatusChanged: {
                if(status == Image.Ready){
                    imageLoadedEffect.start()
                    if(source == root.imageSource) thumbnailCacher.store(root.imageSource, profileImage)
                }
                else if(status == Image.Error) source = constant.twitterBirdIcon
            }

            Component.onCompleted: {
                if(!root.ListView.view || !root.ListView.view.moving) imageSourceBinding.when = true
                else movementEndedSignal.target = root.ListView.view
            }
        }
    }

    MouseArea{
        id: delegateMouseArea
        anchors.fill: parent
        enabled: root.enabled
        z: 1
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
    }

    Timer {
        id: pause
        interval: 250
        onTriggered: height = __originalHeight
    }

    NumberAnimation {
        id: onAddAnimation
        target: root
        property: "scale"
        duration: 250
        from: 0.25; to: 1
        easing.type: Easing.OutBack
    }

    ListView.onAdd: {
        if(root.ListView.view.stayAtCurrentPosition) {
            if(root.ListView.view.atYBeginning) root.ListView.view.contentY += 1
            __originalHeight = height
            height = 0
            pause.start()
        }
        else onAddAnimation.start()
    }
}
