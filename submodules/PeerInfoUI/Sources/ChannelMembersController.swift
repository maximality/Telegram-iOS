import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import ItemListPeerItem
import InviteLinksUI

private final class ChannelMembersControllerArguments {
    let context: AccountContext
    
    let addMember: () -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let removePeer: (PeerId) -> Void
    let openPeer: (Peer) -> Void
    let inviteViaLink: ()->Void
    init(context: AccountContext, addMember: @escaping () -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, removePeer: @escaping (PeerId) -> Void, openPeer: @escaping (Peer) -> Void, inviteViaLink: @escaping()->Void) {
        self.context = context
        self.addMember = addMember
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.openPeer = openPeer
        self.inviteViaLink = inviteViaLink
    }
}

private enum ChannelMembersSection: Int32 {
    case addMembers
    case peers
}

private enum ChannelMembersEntryStableId: Hashable {
    case index(Int32)
    case peer(PeerId)
}

private enum ChannelMembersEntry: ItemListNodeEntry {
    case addMember(PresentationTheme, String)
    case addMemberInfo(PresentationTheme, String)
    case inviteLink(PresentationTheme, String)
    case peerItem(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, PresentationPersonNameOrder, RenderedChannelParticipant, ItemListPeerItemEditing, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .addMember, .addMemberInfo, .inviteLink:
                return ChannelMembersSection.addMembers.rawValue
            case .peerItem:
                return ChannelMembersSection.peers.rawValue
        }
    }
    
    var stableId: ChannelMembersEntryStableId {
        switch self {
            case .addMember:
                return .index(0)
            case .addMemberInfo:
                return .index(1)
        case .inviteLink:
            return .index(2)
            case let .peerItem(_, _, _, _, _, participant, _, _):
                return .peer(participant.peer.id)
        }
    }
    
    static func ==(lhs: ChannelMembersEntry, rhs: ChannelMembersEntry) -> Bool {
        switch lhs {
            case let .addMember(lhsTheme, lhsText):
                if case let .addMember(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addMemberInfo(lhsTheme, lhsText):
                if case let .addMemberInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        case let .inviteLink(lhsTheme, lhsText):
            if case let .inviteLink(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
            case let .peerItem(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsParticipant, lhsEditing, lhsEnabled):
                if case let .peerItem(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsParticipant, rhsEditing, rhsEnabled) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if lhsNameOrder != rhsNameOrder {
                        return false
                    }
                    if lhsParticipant != rhsParticipant {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelMembersEntry, rhs: ChannelMembersEntry) -> Bool {
        switch lhs {
            case .addMember:
                return true
            case .inviteLink:
                switch rhs {
                case .addMember:
                    return false
                default:
                    return true
                }
            case .addMemberInfo:
                switch rhs {
                    case .addMember, .inviteLink:
                        return false
                    default:
                        return true
                }
            
            case let .peerItem(index, _, _, _, _, _, _, _):
                switch rhs {
                    case let .peerItem(rhsIndex, _, _, _, _, _, _, _):
                        return index < rhsIndex
                    case .addMember, .addMemberInfo, .inviteLink:
                        return false
                }
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ChannelMembersControllerArguments
        switch self {
            case let .addMember(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.addMember()
                })
            case let .inviteLink(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.inviteViaLink()
                })
            case let .addMemberInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .peerItem(_, _, strings, dateTimeFormat, nameDisplayOrder, participant, editing, enabled):
                let text: ItemListPeerItemText
                if let user = participant.peer as? TelegramUser, let _ = user.botInfo {
                    text = .text(strings.Bot_GenericBotStatus, .secondary)
                } else {
                    text = .presence
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: arguments.context, peer: participant.peer, presence: participant.presences[participant.peer.id], text: text, label: .none, editing: editing, switchValue: nil, enabled: enabled, selectable: participant.peer.id != arguments.context.account.peerId, sectionId: self.section, action: {
                    arguments.openPeer(participant.peer)
                }, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.removePeer(peerId)
                })
        }
    }
}

private struct ChannelMembersControllerState: Equatable {
    let editing: Bool
    let peerIdWithRevealedOptions: PeerId?
    let removingPeerId: PeerId?
    let searchingMembers: Bool

    init() {
        self.editing = false
        self.peerIdWithRevealedOptions = nil
        self.removingPeerId = nil
        self.searchingMembers = false
    }
    
    init(editing: Bool, peerIdWithRevealedOptions: PeerId?, removingPeerId: PeerId?, searchingMembers: Bool) {
        self.editing = editing
        self.peerIdWithRevealedOptions = peerIdWithRevealedOptions
        self.removingPeerId = removingPeerId
        self.searchingMembers = searchingMembers
    }
    
    static func ==(lhs: ChannelMembersControllerState, rhs: ChannelMembersControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.peerIdWithRevealedOptions != rhs.peerIdWithRevealedOptions {
            return false
        }
        if lhs.removingPeerId != rhs.removingPeerId {
            return false
        }
        if lhs.searchingMembers != rhs.searchingMembers {
            return false
        }
        return true
    }
    
    func withUpdatedSearchingMembers(_ searchingMembers: Bool) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: searchingMembers)
    }
    
    func withUpdatedEditing(_ editing: Bool) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedPeerIdWithRevealedOptions(_ peerIdWithRevealedOptions: PeerId?) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: self.editing, peerIdWithRevealedOptions: peerIdWithRevealedOptions, removingPeerId: self.removingPeerId, searchingMembers: self.searchingMembers)
    }
    
    func withUpdatedRemovingPeerId(_ removingPeerId: PeerId?) -> ChannelMembersControllerState {
        return ChannelMembersControllerState(editing: self.editing, peerIdWithRevealedOptions: self.peerIdWithRevealedOptions, removingPeerId: removingPeerId, searchingMembers: self.searchingMembers)
    }
}

private func channelMembersControllerEntries(context: AccountContext, presentationData: PresentationData, view: PeerView, state: ChannelMembersControllerState, participants: [RenderedChannelParticipant]?, isGroup: Bool) -> [ChannelMembersEntry] {
    if participants == nil || participants?.count == nil {
        return []
    }
    
    var entries: [ChannelMembersEntry] = []
    
    if let participants = participants {
        var canAddMember: Bool = false
        if let peer = view.peers[view.peerId] as? TelegramChannel {
            canAddMember = peer.hasPermission(.inviteMembers)
        }
        
        if canAddMember {
            entries.append(.addMember(presentationData.theme, isGroup ? presentationData.strings.Group_Members_AddMembers : presentationData.strings.Channel_Members_AddMembers))
            if let peer = view.peers[view.peerId] as? TelegramChannel, peer.addressName == nil {
                entries.append(.inviteLink(presentationData.theme, presentationData.strings.Channel_Members_InviteLink))
            }
            if let peer = view.peers[view.peerId] as? TelegramChannel {
                if peer.flags.contains(.isGigagroup) {
                    entries.append(.addMemberInfo(presentationData.theme, presentationData.strings.Group_Members_AddMembersHelp))
                } else if case .broadcast = peer.info {
                    entries.append(.addMemberInfo(presentationData.theme, presentationData.strings.Channel_Members_AddMembersHelp))
                }
            }
        }

        
        var index: Int32 = 0
        let sortedParticipants = participants
        for participant in sortedParticipants {
            var editable = true
            var canEditMembers = false
            if let peer = view.peers[view.peerId] as? TelegramChannel {
                canEditMembers = peer.hasPermission(.banMembers)
            }
            
            if participant.peer.id == context.account.peerId {
                editable = false
            } else {
                switch participant.participant {
                    case .creator:
                        editable = false
                    case .member:
                        editable = canEditMembers
                }
            }
            entries.append(.peerItem(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, presentationData.nameDisplayOrder, participant, ItemListPeerItemEditing(editable: editable, editing: state.editing, revealed: participant.peer.id == state.peerIdWithRevealedOptions), state.removingPeerId != participant.peer.id))
            index += 1
        }
    }
    
    return entries
}

public func channelMembersController(context: AccountContext, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelMembersControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelMembersControllerState())
    let updateState: ((ChannelMembersControllerState) -> ChannelMembersControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissInputImpl: (() -> Void)?
    
    var getControllerImpl: (() -> ViewController?)?
    
    let actionsDisposable = DisposableSet()
    
    let addMembersDisposable = MetaDisposable()
    actionsDisposable.add(addMembersDisposable)
    
    let removePeerDisposable = MetaDisposable()
    actionsDisposable.add(removePeerDisposable)
    
    let peersPromise = Promise<[RenderedChannelParticipant]?>(nil)
    
    let arguments = ChannelMembersControllerArguments(context: context, addMember: {
        actionsDisposable.add((peersPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { members in
            let disabledIds = members?.compactMap({$0.peer.id}) ?? []
            let contactsController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .peerSelection(searchChatList: false, searchGroups: false, searchChannels: false), options: [], filters: [.excludeSelf, .disable(disabledIds)]))
            
            addMembersDisposable.set((contactsController.result
            |> deliverOnMainQueue
            |> castError(AddChannelMemberError.self)
            |> mapToSignal { [weak contactsController] result -> Signal<Never, AddChannelMemberError> in
                contactsController?.displayProgress = true
                
                var contacts: [ContactListPeerId] = []
                if case let .result(peerIdsValue, _) = result {
                    contacts = peerIdsValue
                }
                
                let signal = context.peerChannelMemberCategoriesContextsManager.addMembers(engine: context.engine, peerId: peerId, memberIds: contacts.compactMap({ contact -> PeerId? in
                    switch contact {
                        case let .peer(contactId):
                            return contactId
                        default:
                            return nil
                    }
                }))
                
                return signal
                |> ignoreValues
                |> deliverOnMainQueue
                |> afterCompleted {
                    contactsController?.dismiss()
                }
            }).start(error: { [weak contactsController] error in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let _ = (context.account.postbox.transaction { transaction in
                    return transaction.getPeer(peerId)
                }
                |> deliverOnMainQueue).start(next: { peer in
                    let text: String
                    switch error {
                        case .limitExceeded:
                            text = presentationData.strings.Channel_ErrorAddTooMuch
                        case .tooMuchJoined:
                            text = presentationData.strings.Invite_ChannelsTooMuch
                        case .generic:
                            text = presentationData.strings.Login_UnknownError
                        case .restricted:
                            text = presentationData.strings.Channel_ErrorAddBlocked
                        case .notMutualContact:
                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                text = presentationData.strings.Channel_AddUserLeftError
                            } else {
                                text = presentationData.strings.GroupInfo_AddUserLeftError
                            }
                        case let .bot(memberId):
                            guard let peer = peer as? TelegramChannel else {
                                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                                contactsController?.dismiss()
                                return
                            }
                            
                            if peer.hasPermission(.addAdmins) {
                                contactsController?.displayProgress = false
                                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Channel_AddBotErrorHaveRights, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Channel_AddBotAsAdmin, action: {
                                    contactsController?.dismiss()
                                    
                                    pushControllerImpl?(channelAdminController(context: context, peerId: peerId, adminId: memberId, initialParticipant: nil, updated: { _ in
                                    }, upgradedToSupergroup: { _, f in f () }, transferedOwnership: { _ in }))
                                })]), nil)
                            } else {
                                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Channel_AddBotErrorHaveRights, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                            }
                            
                            contactsController?.dismiss()
                            return
                        case .botDoesntSupportGroups:
                            text = presentationData.strings.Channel_BotDoesntSupportGroups
                        case .tooMuchBots:
                            text = presentationData.strings.Channel_TooMuchBots
                    }
                    presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                    contactsController?.dismiss()
                })
            }))
            
            presentControllerImpl?(contactsController, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        }))
        
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.peerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, removePeer: { memberId in
        updateState {
            return $0.withUpdatedRemovingPeerId(memberId)
        }
        
        removePeerDisposable.set((context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: context.engine, peerId: peerId, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max))
        |> deliverOnMainQueue).start(completed: {
            updateState {
                return $0.withUpdatedRemovingPeerId(nil)
            }
        }))
    }, openPeer: { peer in
        if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) {
            pushControllerImpl?(controller)
        }
    }, inviteViaLink: {
        if let controller = getControllerImpl?() {
            dismissInputImpl?()
            presentControllerImpl?(InviteLinkInviteController(context: context, peerId: peerId, parentNavigationController: controller.navigationController as? NavigationController), nil)
        }
    })
    
    let peerView = context.account.viewTracker.peerView(peerId)
    
    let (disposable, loadMoreControl) = context.peerChannelMemberCategoriesContextsManager.recent(engine: context.engine, postbox: context.account.postbox, network: context.account.network, accountPeerId: context.account.peerId, peerId: peerId, updated: { state in
        peersPromise.set(.single(state.list))
    })
    actionsDisposable.add(disposable)
    
    var previousPeers: [RenderedChannelParticipant]?
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), peerView, peersPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state, view, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var isGroup = true
        if let peer = peerViewMainPeer(view) as? TelegramChannel, case .broadcast = peer.info {
            isGroup = false
        }
        
        var rightNavigationButton: ItemListNavigationButton?
        var secondaryRightNavigationButton: ItemListNavigationButton?
        if let peers = peers, !peers.isEmpty {
            if state.editing {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedEditing(false)
                    }
                })
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedEditing(true)
                    }
                })
                if let cachedData = view.cachedData as? CachedChannelData, cachedData.participantsSummary.memberCount ?? 0 >= 200 {
                    secondaryRightNavigationButton = ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedSearchingMembers(true)
                        }
                    })
                }
                
            }
        }
        
        var searchItem: ItemListControllerSearch?
        if state.searchingMembers {
            searchItem = ChannelMembersSearchItem(context: context, peerId: peerId, searchContext: nil, cancel: {
                updateState { state in
                    return state.withUpdatedSearchingMembers(false)
                }
            }, openPeer: { peer, _ in
                if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) {
                    pushControllerImpl?(infoController)
                }
            }, pushController: { c in
                pushControllerImpl?(c)
            }, dismissInput: {
                dismissInputImpl?()
            })
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if peers == nil || peers?.count == 0 {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        }
        
        let previous = previousPeers
        previousPeers = peers
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(isGroup ? presentationData.strings.Group_Members_Title : presentationData.strings.Channel_Subscribers_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, secondaryRightNavigationButton: secondaryRightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelMembersControllerEntries(context: context, presentationData: presentationData, view: view, state: state, participants: peers, isGroup: isGroup), style: .blocks, emptyStateItem: emptyStateItem, searchItem: searchItem, animateChanges: previous != nil && peers != nil && previous!.count >= peers!.count)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c)
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    getControllerImpl =  { [weak controller] in
        return controller
    }
    controller.visibleBottomContentOffsetChanged = { offset in
        if let loadMoreControl = loadMoreControl, case let .known(value) = offset, value < 40.0 {
            context.peerChannelMemberCategoriesContextsManager.loadMore(peerId: peerId, control: loadMoreControl)
        }
    }
    return controller
}
