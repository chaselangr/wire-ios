//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

extension ConversationContentViewController {

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return ColorScheme.default.statusBarStyle
    }

    @objc
    func setDataSource() {
        dataSource = ConversationTableViewDataSource(conversation: conversation, tableView: tableView, actionResponder: self, cellDelegate: self)
    }

    @objc
    func createMentionsResultsView() {
        mentionsSearchResultsViewController = UserSearchResultsViewController()
        mentionsSearchResultsViewController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(mentionsSearchResultsViewController)
        view.addSubview(mentionsSearchResultsViewController.view)

        mentionsSearchResultsViewController.view.fitInSuperview()
    }

    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return wr_supportedInterfaceOrientations
    }
}


