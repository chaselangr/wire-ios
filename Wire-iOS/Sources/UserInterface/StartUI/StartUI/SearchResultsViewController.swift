//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import WireSyncEngine

@objc enum SearchGroup: Int {
    case people
    case services
}

extension SearchGroup {
    
    var accessible: Bool {
        switch self {
        case .people:
            return true
        case .services:
            return ZMUser.selfUser().canCreateService
        }
    }

#if ADD_SERVICE_DISABLED
    // remove service from the tab
    static let all: [SearchGroup] = [.people]
#else
    static var all: [SearchGroup] {
        return [.people, .services].filter { $0.accessible }
    }
#endif

    var name: String {
        switch self {
        case .people:
            return "peoplepicker.header.people".localized
        case .services:
            return "peoplepicker.header.services".localized
        }
    }
}

@objc
protocol SearchResultsViewControllerDelegate {
    
    func searchResultsViewController(_ searchResultsViewController: SearchResultsViewController, didTapOnUser user: UserType, indexPath: IndexPath, section: SearchResultsViewControllerSection)
    func searchResultsViewController(_ searchResultsViewController: SearchResultsViewController, didDoubleTapOnUser user: UserType, indexPath: IndexPath)
    func searchResultsViewController(_ searchResultsViewController: SearchResultsViewController, didTapOnConversation conversation: ZMConversation)
    func searchResultsViewController(_ searchResultsViewController: SearchResultsViewController, didTapOnSeviceUser user: ServiceUser)
    func searchResultsViewController(_ searchResultsViewController: SearchResultsViewController, wantsToPerformAction action: SearchResultsViewControllerAction)
}

@objc
public enum SearchResultsViewControllerAction : Int {
    case createGroup
    case createGuestRoom
}

@objc
public enum SearchResultsViewControllerMode : Int {
    case search
    case selection
    case list
}

@objc
public enum SearchResultsViewControllerSection : Int {
    case unknown
    case topPeople
    case contacts
    case teamMembers
    case conversations
    case directory
    case services
}

extension UIViewController {
    class ControllerHierarchyIterator: IteratorProtocol {
        private var current: UIViewController

        init(controller: UIViewController) {
            current = controller
        }

        func next() -> UIViewController? {
            var candidate: UIViewController? = .none
            if let controller = current.navigationController {
                candidate = controller
            }
            else if let controller = current.presentingViewController {
                candidate = controller
            }
            else if let controller = current.parent {
                candidate = controller
            }
            if let candidate = candidate {
                current = candidate
            }
            return candidate
        }
    }

    func isContainedInPopover() -> Bool {
        var hierarchy = ControllerHierarchyIterator(controller: self)

        return hierarchy.any {
            if let arrowDirection = $0.popoverPresentationController?.arrowDirection,
                arrowDirection != .unknown {
                return true
            }
            else {
                return false
            }
        }
    }
}

@objcMembers public class SearchResultsViewController : UIViewController {

    var searchResultsView: SearchResultsView?
    var searchDirectory: SearchDirectory!
    let userSelection: UserSelection

    let sectionController: SectionCollectionViewController
    let contactsSection: ContactsSectionController
    let teamMemberAndContactsSection: ContactsSectionController
    let directorySection = DirectorySectionController()
    let conversationsSection: GroupConversationsSectionController
    let topPeopleSection: TopPeopleSectionController
    let servicesSection: SearchServicesSectionController
    let inviteTeamMemberSection: InviteTeamMemberSection
    let createGroupSection = CreateGroupSection()

    var pendingSearchTask: SearchTask? = nil
    var isAddingParticipants: Bool
    var searchGroup: SearchGroup = .people {
        didSet {
            updateVisibleSections()
        }
    }

    public var filterConversation: ZMConversation? = nil
    public let shouldIncludeGuests: Bool

    weak var delegate: SearchResultsViewControllerDelegate? = nil

    public var mode: SearchResultsViewControllerMode = .search {
        didSet {
            updateVisibleSections()
        }
    }

    deinit {
        searchDirectory?.tearDown()
    }

    @objc
    public init(userSelection: UserSelection, isAddingParticipants: Bool = false, shouldIncludeGuests: Bool) {
        self.userSelection = userSelection
        self.isAddingParticipants = isAddingParticipants
        self.mode = .list
        self.shouldIncludeGuests = shouldIncludeGuests

        let team = ZMUser.selfUser().team
        let teamName = team?.name

        sectionController = SectionCollectionViewController()
        contactsSection = ContactsSectionController()
        contactsSection.selection = userSelection
        contactsSection.title = team != nil ? "peoplepicker.header.contacts_personal".localized : "peoplepicker.header.contacts".localized
        contactsSection.allowsSelection = isAddingParticipants
        teamMemberAndContactsSection = ContactsSectionController()
        teamMemberAndContactsSection.allowsSelection = isAddingParticipants
        teamMemberAndContactsSection.selection = userSelection
        teamMemberAndContactsSection.title = "peoplepicker.header.contacts".localized
        servicesSection = SearchServicesSectionController(canSelfUserManageTeam: ZMUser.selfUser().canManageTeam)
        conversationsSection = GroupConversationsSectionController()
        conversationsSection.title = team != nil ? "peoplepicker.header.team_conversations".localized(args: teamName ?? "") : "peoplepicker.header.conversations".localized
        if let session = ZMUserSession.shared() {
            searchDirectory = SearchDirectory(userSession: session)
            topPeopleSection = TopPeopleSectionController(topConversationsDirectory: session.topConversationsDirectory)
        } else {
            topPeopleSection = TopPeopleSectionController(topConversationsDirectory:nil)
        }
        inviteTeamMemberSection = InviteTeamMemberSection(team: team)

        super.init(nibName: nil, bundle: nil)

        contactsSection.delegate = self
        teamMemberAndContactsSection.delegate = self
        directorySection.delegate = self
        topPeopleSection.delegate = self
        conversationsSection.delegate = self
        servicesSection.delegate = self
        createGroupSection.delegate = self
        inviteTeamMemberSection.delegate = self
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        searchResultsView  = SearchResultsView()
        searchResultsView?.parentViewController = self
        view = searchResultsView
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sectionController.collectionView?.reloadData()
        sectionController.collectionView?.collectionViewLayout.invalidateLayout()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        sectionController.collectionView = searchResultsView?.collectionView

        updateVisibleSections()

        searchResultsView?.emptyResultContainer.isHidden = !isResultEmpty
    }

    @objc
    public func cancelPreviousSearch() {
        pendingSearchTask?.cancel()
        pendingSearchTask = nil
    }

    private func performSearch(query: String, options: SearchOptions) {

        pendingSearchTask?.cancel()
        searchResultsView?.emptyResultContainer.isHidden = true

        var options = options
        options.updateForSelfUserTeamRole(selfUser: ZMUser.selfUser())

        let request = SearchRequest(query: query, searchOptions: options, team: ZMUser.selfUser().team)
        if let task = searchDirectory?.perform(request) {
            task.onResult({ [weak self] in self?.handleSearchResult(result: $0, isCompleted: $1)})
            task.start()

            pendingSearchTask = task
        }
    }

    @objc
    public func searchForUsers(withQuery query: String) {
        self.performSearch(query: query, options: [.conversations, .contacts, .teamMembers, .directory])
    }

    @objc
    public func searchForLocalUsers(withQuery query: String) {
        self.performSearch(query: query, options: [.contacts, .teamMembers])
    }

    @objc
    public func searchForServices(withQuery query: String) {
        self.performSearch(query: query, options: [.services])
    }

    @objc
    func searchContactList() {
        searchForLocalUsers(withQuery: "")
    }

    var isResultEmpty: Bool = true {
        didSet {
            searchResultsView?.emptyResultContainer.isHidden = !isResultEmpty
        }
    }

    func handleSearchResult(result: SearchResult, isCompleted: Bool) {
        self.updateSections(withSearchResult: result)

        if isCompleted {
            isResultEmpty = sectionController.visibleSections.isEmpty
        }
    }

    func updateVisibleSections() {
        var sections : [CollectionViewSectionController]
        let team = ZMUser.selfUser().team

        switch(self.searchGroup, isAddingParticipants) {
        case (.services, _):
            sections = [servicesSection]
        case (.people, true):
            switch (mode, team != nil) {
            case (.search, false):
                sections = [contactsSection]
            case (.search, true):
                sections = [teamMemberAndContactsSection]
            case (.selection, false):
                sections = [contactsSection]
            case (.selection, true):
                sections = [teamMemberAndContactsSection]
            case (.list, false):
                sections = [contactsSection]
            case (.list, true):
                sections = [teamMemberAndContactsSection]
            }
        case (.people, false):
            switch (mode, team != nil) {
            case (.search, false):
                sections = [contactsSection, conversationsSection, directorySection]
            case (.search, true):
                sections = [teamMemberAndContactsSection, conversationsSection, directorySection]
            case (.selection, false):
                sections = [contactsSection]
            case (.selection, true):
                sections = [teamMemberAndContactsSection]
            case (.list, false):
                sections = [createGroupSection, topPeopleSection, contactsSection]
            case (.list, true):
                sections = [createGroupSection, inviteTeamMemberSection, teamMemberAndContactsSection]
            }
        }

        sectionController.sections = sections
    }

    func updateSections(withSearchResult searchResult: SearchResult) {

        var contacts = searchResult.contacts
        var teamContacts = searchResult.teamMembers.compactMap({ $0.user })

        if let filteredParticpants = filterConversation?.activeParticipants {
            contacts = contacts.filter({ !filteredParticpants.contains($0) })
            teamContacts = teamContacts.filter({ !filteredParticpants.contains($0) })
        }

        contactsSection.contacts = contacts

        // Access mode is not set, or the guests are allowed.
        if shouldIncludeGuests {
            teamMemberAndContactsSection.contacts = Set(teamContacts + contacts).sorted {
                let name0 = $0.name ?? ""
                let name1 = $1.name ?? ""

                return name0.compare(name1) == .orderedAscending
            }
        }
        else {
            teamMemberAndContactsSection.contacts = teamContacts
        }

        directorySection.suggestions = searchResult.directory
        conversationsSection.groupConversations = searchResult.conversations
        servicesSection.services = searchResult.services

        sectionController.collectionView?.reloadData()
    }

    func sectionFor(controller: CollectionViewSectionController) -> SearchResultsViewControllerSection {
        if controller === topPeopleSection {
            return .topPeople
        } else if controller === contactsSection {
            return .contacts
        } else if controller === teamMemberAndContactsSection {
            return .teamMembers
        } else if  controller === conversationsSection {
            return .conversations
        } else if controller === directorySection {
            return .directory
        } else if controller === servicesSection {
            return .services
        } else {
            return .unknown
        }
    }

}

extension SearchResultsViewController : SearchSectionControllerDelegate {

    func searchSectionController(_ searchSectionController: CollectionViewSectionController, didSelectUser user: UserType, at indexPath: IndexPath) {
        if let user = user as? ZMUser {
            delegate?.searchResultsViewController(self, didTapOnUser: user, indexPath: indexPath, section: sectionFor(controller: searchSectionController))
        }
        else if let service = user as? ServiceUser, service.isServiceUser {
            delegate?.searchResultsViewController(self, didTapOnSeviceUser: service)
        }
        else if let searchUser = user as? ZMSearchUser {
            delegate?.searchResultsViewController(self, didTapOnUser: searchUser, indexPath: indexPath, section: sectionFor(controller: searchSectionController))
        }
    }

    func searchSectionController(_ searchSectionController: CollectionViewSectionController, didSelectConversation conversation: ZMConversation, at indexPath: IndexPath) {
        delegate?.searchResultsViewController(self, didTapOnConversation: conversation)
    }

    func searchSectionController(_ searchSectionController: CollectionViewSectionController, didSelectRow row: CreateGroupSection.Row, at indexPath: IndexPath) {
        switch row {
        case .createGroup:
            delegate?.searchResultsViewController(self, wantsToPerformAction: .createGroup)
        case .createGuestRoom:
            delegate?.searchResultsViewController(self, wantsToPerformAction: .createGuestRoom)
        }

    }

}

extension SearchResultsViewController : InviteTeamMemberSectionDelegate {
    func inviteSectionDidRequestTeamManagement() {
        URL.manageTeam(source: .onboarding).openInApp(above: self)
    }
}

extension SearchResultsViewController : SearchServicesSectionDelegate {
    func addServicesSectionDidRequestOpenServicesAdmin() {
        URL.manageTeam(source: .settings).openInApp(above: self)
    }
}
