//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//


import Foundation
import SafariServices


private var lastPreviewURL: URL?


extension ConversationContentViewController: UIViewControllerPreviewingDelegate {

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {

        let cellLocation = view.convert(location, to: tableView)

        guard let cellIndexPath = tableView.indexPathForRow(at: cellLocation),
              let cell = tableView.cellForRow(at: cellIndexPath) as? SelectableView & UIView else {
            return .none
        }

        guard let message = self.dataSource?.messages[cellIndexPath.section],
                message.isObfuscated == false else {
            return nil
        }

        lastPreviewURL = nil
        var controller: UIViewController?

        if message.isText, cell.selectionView is ArticleView, let url = message.textMessageData?.linkPreview?.openableURL as URL? {
            lastPreviewURL = url
            controller = BrowserViewController(url: url)
        } else if message.isImage {
            controller = messagePresenter.viewController(forImageMessagePreview: message, actionResponder: self)
        } else if message.isLocation {
            controller = LocationPreviewController(message: message, actionResponder: self)
        }

        previewingContext.sourceRect = previewingContext.sourceView.convert(cell.selectionRect, from: cell.selectionView)
        return controller
    }

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {

        // If the previewed item is an image, show the previously hidden controls.
        if let imagesViewController = viewControllerToCommit as? ConversationImagesViewController {
            imagesViewController.isPreviewing = false
        }

        // If the previewed item is a location, open it in Maps.
        if let locationController = viewControllerToCommit as? LocationPreviewController {
            Message.openInMaps(locationController.message.locationMessageData!)
            return
        }

        // In case the user has set a 3rd party application to open the URL we do not 
        // want to commit the view controller but instead open the url.
        if let url = lastPreviewURL {
            url.open()
        } else {
            self.messagePresenter.modalTargetController?.present(viewControllerToCommit, animated: true, completion: .none)
        }
    }

}
