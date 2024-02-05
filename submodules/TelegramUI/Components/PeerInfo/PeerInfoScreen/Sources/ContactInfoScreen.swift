//
//  ContactInfoScreen.swift
//  PeerInfoScreen
//
//  Created by Rustam Khakhuk on 31.01.2024.
//

import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import Postbox
import TelegramPresentationData
import TelegramCore
import PhoneNumberFormat
import PeerInfoPaneNode
import SwiftSignalKit
import PeerInfoUI
import UndoUI
import ItemListUI
import ShareController
import ContextUI
import MessageUI
import Contacts
import TelegramStringFormatting
import PeerReportScreen
import PeerAvatarGalleryUI
import TelegramCallsUI
import AvatarNode

public final class ContactInfoScreen: ViewController {

    private var composer: MFMessageComposeViewController?

    private let context: AccountContext
    private var presentationData: PresentationData
    private let peer: Peer?
    private let contactInfo: TelegramMediaContact?
    private let hapticFeedback = HapticFeedback()
    private let scrollView: UIScrollView
    private var headerNode: PeerInfoHeaderNode!
    private var regularSections: [AnyHashable: PeerInfoScreenItemSectionContainerNode] = [:]
    private var canOpenAvatarByDragging: Bool = true
    private var validLayout: ContainerViewLayout?
    private(set) var data: PeerInfoScreenData?
    private var dataDisposable: Disposable?
    private let resolveUrlDisposable = MetaDisposable()

    public init(context: AccountContext, peer: Peer?, contactInfo: TelegramMediaContact?) {
        self.context = context
        self.peer = peer
        self.contactInfo = contactInfo

        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        self.scrollView = UIScrollView(frame: .zero)
        self.scrollView.isScrollEnabled = true
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.bounces = true
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.scrollsToTop = false

        super.init(navigationBarPresentationData: nil)

        self.headerNode = PeerInfoHeaderNode(
            context: context,
            controller: self,
            avatarInitiallyExpanded: peer == nil ? false : ((peer?.backgroundEmojiId != nil) ? false : (peer?.smallProfileImage == nil ? false : true)),
            isOpenedFromChat: false,
            isMediaOnly: false,
            isSettings: false,
            isPreview: true,
            forumTopicThreadId: nil,
            chatLocation: .peer(id: PeerId(0))
        )

        self.view.addSubview(scrollView)
        self.view.addSubview(headerNode.view)

        self.view.tag = 228

        if #available(iOS 13, *) {
            self.isModalInPresentation = true
        }

        self.scrollView.delegate = self

        headerNode.navigationButtonContainer.performAction = { [weak self] key, _, _ in
            self?.dismiss()
        }

        if let peer {
            let screenData = peerInfoScreenData(context: context, peerId: peer.id, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, isSettings: false, hintGroupInCommon: nil, existingRequestsContext: nil, chatLocation: .peer(id: PeerId(0)), chatLocationContextHolder: .init(value: nil))

            self.dataDisposable = screenData.startStrict(next: { [weak self] dataa in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.updateData(data: dataa)
            })
        }

        self.headerNode.avatarListNode.listContainerNode.currentIndexUpdated = { [weak self] in
            self?.updateNavigation(transition: .immediate, additive: true, animateHeader: true)
        }

        self.headerNode.requestAvatarExpansion = { [weak self] _, _, _, _ in
            self?.headerNode.updateIsAvatarExpanded(true, transition: .animated(duration: 0.3, curve: .spring))

            if let layout = self?.validLayout {
                self?.layout(layout: layout, transition: .animated(duration: 0.3, curve: .spring), additive: false)
            }
        }

        self.headerNode.displayAvatarContextMenu = { [weak self] node, gesture in
            guard let strongSelf = self, let peer = strongSelf.data?.peer else {
                return
            }

            var isPersonal = false
            var currentIsVideo = false
            let item = strongSelf.headerNode.avatarListNode.listContainerNode.currentItemNode?.item
            if let item = item, case let .image(_, representations, videoRepresentations, _, _, _) = item {
                if representations.first?.representation.isPersonal == true {
                    isPersonal = true
                }
                currentIsVideo = !videoRepresentations.isEmpty
            }
            guard !isPersonal else {
                return
            }

            let items: [ContextMenuItem] = [
                .action(ContextMenuActionItem(text: currentIsVideo ? strongSelf.presentationData.strings.PeerInfo_ReportProfileVideo : strongSelf.presentationData.strings.PeerInfo_ReportProfilePhoto, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Report"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] c, f in
                    if let strongSelf = self {
                        presentPeerReportOptions(context: context, parent: strongSelf, contextController: c, subject: .profilePhoto(peer.id, 0), completion: { _, _ in })
                    }
                }))
            ]

            let galleryController = AvatarGalleryController(context: strongSelf.context, peer: EnginePeer(peer), remoteEntries: nil, replaceRootController: { controller, ready in
            }, synchronousLoad: true)
            galleryController.setHintWillBePresentedInPreviewingContext(true)

            let contextController = ContextController(presentationData: strongSelf.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: galleryController, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            strongSelf.presentInGlobalOverlay(contextController)
        }
    }

    deinit {
        self.dataDisposable?.dispose()
        self.resolveUrlDisposable.dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        self.layout(layout: layout, transition: transition, additive: false)
    }

    private func updateData(data: PeerInfoScreenData) {
        self.data = data
        if let layout = validLayout {
            DispatchQueue.main.async{
                self.layout(layout: layout, transition: .immediate, additive: false)
            }
        }
    }

    private func layout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition, additive: Bool) {
        presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let navigationBarHeight: CGFloat = 56.0
        self.view.backgroundColor = presentationData.theme.list.blocksBackgroundColor

        transition.updateFrame(view: scrollView, frame: CGRect(origin: .zero, size: layout.size))

        let state = PeerInfoState(isEditing: false, selectedMessageIds: nil, updatingAvatar: nil, updatingBio: nil, avatarUploadProgress: nil, highlightedButton: nil)

        let headerHeight = headerNode.update(
            width: layout.size.width,
            containerHeight: layout.size.height,
            containerInset: .zero,
            statusBarHeight: 0,
            navigationHeight: navigationBarHeight,
            isModalOverlay: false,
            isMediaOnly: false,
            contentOffset: scrollView.contentOffset.y,
            paneContainerY: 0,
            presentationData: self.presentationData,
            peer: peer,
            contactInfo: contactInfo,
            cachedData: data?.cachedData,
            threadData: nil,
            peerNotificationSettings: nil,
            threadNotificationSettings: nil,
            globalNotificationSettings: nil,
            statusData: (peer == nil ? PeerInfoStatusData(text: "not in Telegram", isActivity: false, isHiddenStatus: false, key: nil) : data?.status),
            panelStatusData: (nil, nil, nil),
            isSecretChat: false,
            isContact: false,
            isSettings: false,
            isPreview: true,
            state: state,
            metrics: layout.metrics,
            deviceMetrics: layout.deviceMetrics,
            transition: transition,
            additive: additive,
            animateHeader: transition.isAnimated
        )
        let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: headerHeight))

        if additive {
            transition.updateFrameAdditive(node: headerNode, frame: headerFrame)
        } else {
            transition.updateFrame(node: headerNode, frame: headerFrame)
        }
        transition.updateFrame(
            node: headerNode.navigationButtonContainer,
            frame: CGRect(
                origin: CGPoint(x: 0, y: 0.0),
                size: CGSize(
                    width: view.bounds.width,
                    height: navigationBarHeight
                )
            )
        )

        headerNode.navigationButtonContainer.update(
            size: CGSize(width: layout.size.width, height: navigationBarHeight),
            presentationData: self.presentationData,
            leftButtons: [.init(key: .close, isForExpandedView: false)],
            rightButtons: [],
            expandFraction: 0,
            transition: transition
        )

        let items = previewItems()

        var contentHeight: CGFloat = 0.0
        let sectionSpacing: CGFloat = 24

        contentHeight += headerHeight + sectionSpacing + 12

        for (sectionId, sectionItems) in items {
            let sectionNode: PeerInfoScreenItemSectionContainerNode
            if let current = regularSections[sectionId] {
                sectionNode = current
            } else {
                sectionNode = PeerInfoScreenItemSectionContainerNode()
                regularSections[sectionId] = sectionNode
                scrollView.addSubview(sectionNode.view)
            }

            let sectionWidth = layout.size.width - 24
            let sectionHeight = sectionNode.update(
                width: sectionWidth,
                safeInsets: .zero,
                hasCorners: true,
                presentationData: self.presentationData,
                items: sectionItems,
                transition: transition
            )

            let sectionFrame = CGRect(
                origin: CGPoint(x: 12, y: contentHeight),
                size: CGSize(width: sectionWidth, height: sectionHeight)
            )
            transition.updateFrame(node: sectionNode, frame: sectionFrame)

            if !sectionHeight.isZero {
                contentHeight += sectionHeight
                contentHeight += sectionSpacing
            }
        }

        scrollView.contentSize = CGSize(width: layout.size.width, height: max(layout.size.height + 2, contentHeight + view.safeAreaInsets.bottom))

        updateNavigation(transition: transition, additive: false, animateHeader: true)
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError()
    }

    fileprivate func updateNavigation(transition: ContainedViewLayoutTransition, additive: Bool, animateHeader: Bool) {
        guard let layout = validLayout else { return }

        let offsetY = scrollView.contentOffset.y
        let navigationHeight = 56.0

        if !additive {
            let sectionInset: CGFloat
            if layout.size.width >= 375.0 {
                sectionInset = max(16.0, floor((view.bounds.width - 674.0) / 2.0))
            } else {
                sectionInset = 0.0
            }
            let headerInset = sectionInset

            let _ = headerNode.update(
                width: layout.size.width,
                containerHeight: layout.size.height,
                containerInset: headerInset,
                statusBarHeight: 0.0,
                navigationHeight: navigationHeight,
                isModalOverlay: false,
                isMediaOnly: false,
                contentOffset: offsetY,
                paneContainerY: 0,
                presentationData: self.presentationData,
                peer: self.peer,
                contactInfo: contactInfo,
                cachedData: data?.cachedData,
                threadData: nil,
                peerNotificationSettings: nil,
                threadNotificationSettings: nil,
                globalNotificationSettings: nil,
                statusData: (peer == nil ? PeerInfoStatusData(text: "not in Telegram", isActivity: false, isHiddenStatus: false, key: nil) : data?.status),
                panelStatusData: (nil, nil, nil),
                isSecretChat: false,
                isContact: false,
                isSettings: false,
                isPreview: true,
                state: PeerInfoState(isEditing: false, selectedMessageIds: nil, updatingAvatar: nil, updatingBio: nil, avatarUploadProgress: nil, highlightedButton: nil),
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                transition: transition,
                additive: additive,
                animateHeader: animateHeader
            )
        }

        headerNode.navigationButtonContainer.update(size: CGSize(width: layout.size.width, height: navigationHeight), presentationData: self.presentationData, leftButtons: [.init(key: .close, isForExpandedView: false)], rightButtons: [], expandFraction: 0, transition: transition)
    }

    private func previewItems() -> [(AnyHashable, [PeerInfoScreenItem])] {
        enum Section: Int, CaseIterable {
            case actions
            case info
            case additionalInfo
        }

        let replaceControllerImpl = { [weak self] value in
            guard let self else { return }
            (navigationController as? NavigationController)?.replaceTopController(value, animated: true)
        }

        let presentControllerImpl = { [weak self] value, presentationArguments in
            guard let self else { return }

            self.present(value, in: .window(.root), with: presentationArguments)
        }

        let displayCopyContextMenuImpl: (String, ASDisplayNode) -> Void = { [weak self] value, view in
            guard let self else { return }

            let contextMenuController = makeContextMenuController(
                actions: [
                    ContextMenuAction(content: .text(title: self.presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: self.presentationData.strings.Conversation_ContextMenuCopy), action: {
                UIPasteboard.general.string = value

                        let content: UndoOverlayContent = .copy(text: self.presentationData.strings.Conversation_TextCopied)
                presentControllerImpl(
                    UndoOverlayController(
                        presentationData: self.presentationData,
                        content: content,
                        elevatedLayout: false,
                        animateInAsReplacement: false,
                        action: { _ in return false }
                    ),
                    nil
                )
            })])

            self.present(
                contextMenuController,
                in: .window(.root),
                with: ContextMenuControllerPresentationArguments(
                    sourceNodeAndRect: {
                        return (
                            view,
                            view.bounds.insetBy(dx: 0.0, dy: -2.0),
                            self.displayNode,
                            self.view.bounds
                        )
                    }
                )
            )
        }

        var items: [Section: [PeerInfoScreenItem]] = [:]
        for section in Section.allCases {
            items[section] = []
        }

        var itemIndex = 0

        if let peer {
            items[.actions]!.append(
                PeerInfoScreenActionItem(id: itemIndex, text: presentationData.strings.UserInfo_SendMessage, action: { [weak self] in
                    guard let self else { return }

                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id))
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let peer = peer else {
                            return
                        }

                        if let navigationController = (self.navigationController as? NavigationController) {
                            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
                        }
                    })
                })
            )
        } else if let contactInfo, let vCard = contactInfo.vCardData?.data(using: .utf8), let contactData = DeviceContactExtendedData(vcard: vCard) {
            items[.actions]!.append(
                PeerInfoScreenActionItem(id: itemIndex, text: presentationData.strings.Contacts_InviteToTelegram, action: { [weak self] in
                    guard let self else { return }

                    inviteContact(presentationData: context.sharedContext.currentPresentationData.with { $0 }, numbers: contactData.basicData.phoneNumbers.map { $0.value })
                })
            )
        }

        itemIndex += 1
        items[.actions]!.append(
            PeerInfoScreenActionItem(id: itemIndex, text: presentationData.strings.UserInfo_CreateNewContact, action: { [weak self] in
                guard let self else { return }

                var contactData: DeviceContactExtendedData?
                if let contactInfo, let vCard = contactInfo.vCardData?.data(using: .utf8) {
                    contactData = DeviceContactExtendedData(vcard: vCard)
                } else if let peer = peer as? TelegramUser {
                    contactData = DeviceContactExtendedData(
                        basicData: DeviceContactBasicData(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumbers: [
                            .init(label: "", value: peer.phone ?? "")
                        ]),
                        middleName: "",
                        prefix: "",
                        suffix: "",
                        organization: "",
                        jobTitle: "",
                        department: "",
                        emailAddresses: [],
                        urls: [],
                        addresses: [],
                        birthdayDate: nil,
                        socialProfiles: [],
                        instantMessagingProfiles: [],
                        note: ""
                    )
                }
                guard let contactData else { return }


                self.present(
                    context.sharedContext.makeDeviceContactInfoController(
                        context: context,
                        subject: .create(peer: peer, contactData: contactData, isSharing: peer != nil, shareViaException: false, completion: { _, _, _ in }),
                        completed: nil,
                        cancelled: nil
                    ), 
                    in: .window(.root),
                    with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet)
                )
            })
        )
        itemIndex += 1

        items[.actions]!.append(
            PeerInfoScreenActionItem(id: itemIndex, text: presentationData.strings.UserInfo_AddToExisting, action: { [weak self] in
                guard let self, let contactInfo else { return }

                var contactData: DeviceContactExtendedData?
                if let vCard = contactInfo.vCardData?.data(using: .utf8) {
                    contactData = DeviceContactExtendedData(vcard: vCard)
                } else if let peer = peer as? TelegramUser {
                    contactData = DeviceContactExtendedData(
                        basicData: DeviceContactBasicData(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumbers: [
                            .init(label: "", value: peer.phone ?? "")
                        ]),
                        middleName: "",
                        prefix: "",
                        suffix: "",
                        organization: "",
                        jobTitle: "",
                        department: "",
                        emailAddresses: [],
                        urls: [],
                        addresses: [],
                        birthdayDate: nil,
                        socialProfiles: [],
                        instantMessagingProfiles: [],
                        note: ""
                    )
                }
                guard let contactData else { return }

                addContactToExisting(
                    context: context,
                    parentController: self,
                    contactData: contactData,
                    completion: { [weak self] peer, contactId, contactData in
                        guard let self else { return }
                        replaceControllerImpl(
                            deviceContactInfoController(
                                context: context,
                                subject: .vcard(peer?._asPeer(), contactId, contactData),
                                completed: nil,
                                cancelled: nil
                            )
                        )
                    }
                )
            })
        )
        itemIndex += 1

        if let user = peer as? TelegramUser {
            if let mainUsername = user.addressName {
                var additionalUsernames: String?
                let usernames = user.usernames.filter { $0.isActive && $0.username != mainUsername }
                if !usernames.isEmpty {
                    additionalUsernames = presentationData.strings.Profile_AdditionalUsernames(String(usernames.map { "@\($0.username)" }.joined(separator: ", "))).string
                }

                items[.info]!.append(
                    PeerInfoScreenLabeledValueItem(
                        id: itemIndex,
                        label: presentationData.strings.Profile_Username,
                        text: "@\(mainUsername)",
                        additionalText: additionalUsernames,
                        textColor: .accent,
                        icon: .qrCode,
                        action: { [weak self] _ in
                            guard let self else { return }
                            openUsername(value: "@\(mainUsername)")
                        },
                        longTapAction: { sourceNode in
                            displayCopyContextMenuImpl(
                                "@\(mainUsername)",
                                sourceNode
                            )
                        }, linkItemAction: { type, item, _, _ in
                        }, iconAction: { [weak self] in
                            guard let self else { return }
                            self.openQrCode()
                        }, requestLayout: {
                        }
                    )
                )
                itemIndex += 1
            }

            if let phone = user.phone {
                let formattedPhone = formatPhoneNumber(context: context, number: phone)
                let label: String
                if formattedPhone.hasPrefix("+888 ") {
                    label = presentationData.strings.UserInfo_AnonymousNumberLabel
                } else {
                    label = presentationData.strings.ContactInfo_PhoneLabelMobile
                }
                items[.info]!.append(
                    PeerInfoScreenLabeledValueItem(
                        id: itemIndex,
                        label: label,
                        text: formattedPhone,
                        textColor: .accent,
                        action: { [weak self] node in
                            guard let self else { return }
                            self.openPhone(value: formattedPhone, node: node, gesture: nil)
                        },
                        contextAction: { [weak self] node, gesture, _ in
                            guard let self else { return }
                            self.openPhone(value: formattedPhone, node: node, gesture: gesture)
                        },
                        requestLayout: {}
                    )
                )
                itemIndex += 1
            }

            if let contactInfo, let vCard = contactInfo.vCardData?.data(using: .utf8), let contactData = DeviceContactExtendedData(vcard: vCard) {
                for phone in contactData.basicData.phoneNumbers {
                    items[.info]!.append(
                        PeerInfoScreenLabeledValueItem(
                            id: itemIndex,
                            label: localizedPhoneNumberLabel(label: phone.label, strings: presentationData.strings),
                            text: phone.value,
                            textColor: .accent,
                            action: { [weak self] node in
                                guard let self else { return }
                                self.openPhone(value: phone.value, node: node, gesture: nil)
                            },
                            contextAction: { [weak self] node, gesture, _ in
                                guard let self else { return }
                                self.openPhone(value: phone.value, node: node, gesture: gesture)
                            },
                            requestLayout: {}
                        )
                    )
                    itemIndex += 1
                }
            }

            if let cachedData = data?.cachedData as? CachedUserData, let about = cachedData.about, !about.isEmpty {
                 items[.info]!.append(
                     PeerInfoScreenLabeledValueItem(
                         id: itemIndex,
                         label: presentationData.strings.Profile_About,
                         text: about,
                         action: { node in },
                         longTapAction: { node in
                             displayCopyContextMenuImpl(
                                about,
                                node
                             )
                         },
                         linkItemAction: { [weak self] action, item, _, _ in
                             guard let self, let peer = peer else {
                                 return
                             }
                             self.context.sharedContext.handleTextLinkAction(context: self.context, peerId: peer.id, navigateDisposable: self.resolveUrlDisposable, controller: self, action: action, itemLink: item)
                         },
                         requestLayout: {}
                     )
                 )
                 itemIndex += 1
             }
        } else if let contactInfo, let vCard = contactInfo.vCardData?.data(using: .utf8), let contactData = DeviceContactExtendedData(vcard: vCard) {
            for phone in contactData.basicData.phoneNumbers {
                items[.info]!.append(
                    PeerInfoScreenLabeledValueItem(
                        id: itemIndex,
                        label: localizedPhoneNumberLabel(label: phone.label, strings: presentationData.strings),
                        text: phone.value,
                        textColor: .accent,
                        action: { [weak self] node in
                            guard let self else { return }
                            self.openPhone(value: phone.value, node: node, gesture: nil)
                        },
                        contextAction: { [weak self] node, gesture, _ in
                            guard let self else { return }
                            self.openPhone(value: phone.value, node: node, gesture: gesture)
                        },
                        requestLayout: {}
                    )
                )

                itemIndex += 1
            }
        }

        if let contactInfo {
            if let vCard = contactInfo.vCardData, let vCardData = vCard.data(using: .utf8), let parsed = DeviceContactExtendedData(vcard: vCardData) {
                let parsedInfo = parsed
                print(parsedInfo)

                if let birthday = parsedInfo.birthdayDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium

                    items[.additionalInfo]?.append(
                        PeerInfoScreenLabeledValueItem(
                            id: itemIndex,
                            label: presentationData.strings.ContactInfo_BirthdayLabel,
                            text: dateFormatter.string(from: birthday),
                            textColor: .accent,
                            action: { _ in },
                            longTapAction: { node in
                                displayCopyContextMenuImpl(
                                    dateFormatter.string(from: birthday),
                                    node
                                )
                            },
                            requestLayout: {}
                        )
                    )
                    itemIndex += 1
                }

                for socialProfile in parsedInfo.socialProfiles.enumerated() {
                    items[.additionalInfo]?.append(
                        PeerInfoScreenLabeledValueItem(
                            id: itemIndex,
                            label: socialProfile.element.service,
                            text: socialProfile.element.username,
                            textColor: .accent,
                            action: { _ in },
                            longTapAction: { node in
                                displayCopyContextMenuImpl(
                                    socialProfile.element.username,
                                    node
                                )
                            },
                            requestLayout: {}
                        )
                    )
                    itemIndex += 1
                }
            }
        }

        var result: [(AnyHashable, [PeerInfoScreenItem])] = []
        for section in Section.allCases {
            if let sectionItems = items[section], !sectionItems.isEmpty {
                result.append((section, sectionItems))
            }
        }

        return result
    }

    private func openQrCode() {
        guard let peer else {
            return
        }

        present(context.sharedContext.makeChatQrCodeScreen(context: context, peer: peer, threadId: nil, temporary: false), in: .window(.root))
    }

    private func openUsername(value: String) {
        let url: String
        if value.hasPrefix("https://") {
            url = value
        } else {
            url = "https://t.me/\(value)"
        }

        let shareController = ShareController(context: context, subject: .url(url), updatedPresentationData: nil)
        shareController.completed = { [weak self] peerIds in
            guard let strongSelf = self else {
                return
            }
            let _ = (strongSelf.context.engine.data.get(
                EngineDataList(
                    peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                )
            ) |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                guard let strongSelf = self else {
                    return
                }
                let peers = peerList.compactMap { $0 }
                let text: String
                var savedMessages = false
                let presentationData = strongSelf.presentationData
                if peerIds.count == 1, let peerId = peerIds.first, peerId == strongSelf.context.account.peerId {
                    text = presentationData.strings.UserInfo_LinkForwardTooltip_SavedMessages_One
                    savedMessages = true
                } else {
                    if peers.count == 1, let peer = peers.first {
                        let peerName = peer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.UserInfo_LinkForwardTooltip_Chat_One(peerName).string
                    } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                        let firstPeerName = firstPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        let secondPeerName = secondPeer.id == strongSelf.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.UserInfo_LinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                    } else if let peer = peers.first {
                        let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.UserInfo_LinkForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                    } else {
                        text = ""
                    }
                }

                strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                    if savedMessages, let self, action == .info {
                        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                            guard let self, let peer else {
                                return
                            }
                            guard let navigationController = self.navigationController as? NavigationController else {
                                return
                            }
                            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
                        })
                    }
                    return false
                }), in: .current)

            })
        }

        shareController.actionCompleted = { [weak self] in
            if let strongSelf = self {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }
        }
        self.view.endEditing(true)
        self.present(shareController, in: .window(.root))
    }

    private func openPhone(value: String, node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }

        var signal: Signal<EnginePeer?, NoError>

        if let peer {
            signal = getUserPeer(engine: self.context.engine, peerId: peer.id)
        } else {
            signal = Signal<EnginePeer?, NoError>.single(nil)
        }

        let _ = (combineLatest(
            signal,
            getUserPeer(engine: self.context.engine, peerId: self.context.account.peerId)
        ) |> deliverOnMainQueue).startStandalone(next: { [weak self] peer, accountPeer in
            guard let strongSelf = self else {
                return
            }
            let presentationData = strongSelf.presentationData

            let telegramCallAction: (Bool) -> Void = { [weak self] isVideo in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.requestCall(isVideo: isVideo)
            }

            let phoneCallAction = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(context: strongSelf.context, number: value).replacingOccurrences(of: " ", with: ""))")
            }

            let copyAction = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                UIPasteboard.general.string = formatPhoneNumber(context: strongSelf.context, number: value)

                strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }

            var accountIsFromUS = false
            if let accountPeer, case let .user(user) = accountPeer, let phone = user.phone {
                if let (country, _) = lookupCountryIdByNumber(phone, configuration: strongSelf.context.currentCountriesConfiguration.with { $0 }) {
                    if country.id == "US" {
                        accountIsFromUS = true
                    }
                }
            }

            let formattedPhoneNumber = formatPhoneNumber(context: strongSelf.context, number: value)
            var isAnonymousNumber = false
            var items: [ContextMenuItem] = []
            if case let .user(peer) = peer, let peerPhoneNumber = peer.phone, formattedPhoneNumber == formatPhoneNumber(context: strongSelf.context, number: peerPhoneNumber) {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_TelegramCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Call"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c.dismiss {
                        telegramCallAction(false)
                    }
                })))
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_TelegramVideoCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VideoCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c.dismiss {
                        telegramCallAction(true)
                    }
                })))
                if !formattedPhoneNumber.hasPrefix("+888") {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.UserInfo_PhoneCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PhoneCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c.dismiss {
                            phoneCallAction()
                        }
                    })))
                } else {
                    isAnonymousNumber = true
                }
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                    c.dismiss {
                        copyAction()
                    }
                })))
            } else {
                if !formattedPhoneNumber.hasPrefix("+888") {
                    items.append(
                        .action(ContextMenuActionItem(text: presentationData.strings.UserInfo_PhoneCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PhoneCall"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                            c.dismiss {
                                phoneCallAction()
                            }
                        }))
                    )
                } else {
                    isAnonymousNumber = true
                }
                items.append(
                    .action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
                        c.dismiss {
                            copyAction()
                        }
                    }))
                )
            }
            var actions = ContextController.Items(content: .list(items))
            if isAnonymousNumber && !accountIsFromUS {
                actions.tip = .animatedEmoji(text: strongSelf.presentationData.strings.UserInfo_AnonymousNumberInfo, arguments: nil, file: nil, action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: "https://fragment.com/numbers", forceExternal: true, presentationData: strongSelf.presentationData, navigationController: nil, dismissInput: {})
                    }
                })
            }
            let contextController = ContextController(presentationData: strongSelf.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
            strongSelf.present(contextController, in: .window(.root))
        })
    }

    private func getUserPeer(engine: TelegramEngine, peerId: EnginePeer.Id) -> Signal<EnginePeer?, NoError> {
        return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> mapToSignal { peer -> Signal<EnginePeer?, NoError> in
            guard let peer = peer else {
                return .single(nil)
            }
            if case let .secretChat(secretChat) = peer {
                return engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: secretChat.regularPeerId))
            } else {
                return .single(peer)
            }
        }
    }

    private func requestCall(isVideo: Bool, gesture: ContextGesture? = nil, contextController: ContextControllerProtocol? = nil, result: ((ContextMenuActionResult) -> Void)? = nil, backAction: ((ContextControllerProtocol) -> Void)? = nil) {
        guard let peer = self.data?.peer as? TelegramUser, let cachedUserData = self.data?.cachedData as? CachedUserData else {
            return
        }
        if cachedUserData.callsPrivate {
            self.present(textAlertController(theme: .init(presentationData: self.presentationData), title: .init(string: self.presentationData.strings.Call_ConnectionErrorTitle), text: .init(string: self.presentationData.strings.Call_PrivacyErrorMessage(EnginePeer(peer).compactDisplayTitle).string), actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            return
        }

        self.context.requestCall(peerId: peer.id, isVideo: isVideo, completion: {})
    }
}

extension ContactInfoScreen: ModalDismissableDelegate {
    public var isDismissable: Bool {
        if let peer {
            if peer.smallProfileImage == nil {
                return true
            }
            return headerNode.isAvatarExpanded

        } else {
            return true
        }
    }
}

extension ContactInfoScreen: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.canOpenAvatarByDragging = headerNode.isAvatarExpanded
        
    }


    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        var shouldBeExpanded: Bool?

        var isLandscape = false
        if view.bounds.width > view.bounds.height {
            isLandscape = true
        }
        if offsetY <= -32.0 && scrollView.isDragging && scrollView.isTracking {
            if let peer = self.peer, peer.smallProfileImage != nil && !isLandscape {
                shouldBeExpanded = true

                if self.canOpenAvatarByDragging && headerNode.isAvatarExpanded && offsetY <= -32.0 {
                    self.hapticFeedback.impact()

                    self.canOpenAvatarByDragging = false
                    let contentOffset = scrollView.contentOffset.y
                    scrollView.panGestureRecognizer.isEnabled = false
                    headerNode.initiateAvatarExpansion(gallery: true, first: false)
                    scrollView.panGestureRecognizer.isEnabled = true
                    scrollView.contentOffset = CGPoint(x: 0.0, y: contentOffset)
                    UIView.animate(withDuration: 0.1) {
                        scrollView.contentOffset = CGPoint()
                    }
                }
            }
        } else if offsetY >= 1.0 {
            shouldBeExpanded = false
            self.canOpenAvatarByDragging = false
        }

        if let shouldBeExpanded = shouldBeExpanded, shouldBeExpanded != headerNode.isAvatarExpanded {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.35, curve: .spring)

            if shouldBeExpanded {
                self.hapticFeedback.impact()
            } else {
                self.hapticFeedback.tap()
            }

            headerNode.updateIsAvatarExpanded(shouldBeExpanded, transition: transition)

            if let layout = validLayout {
                self.layout(layout: layout, transition: transition, additive: true)
            }
        }

        self.updateNavigation(transition: .immediate, additive: false, animateHeader: true)
    }
}

private func addContactToExisting(context: AccountContext, parentController: ViewController, contactData: DeviceContactExtendedData, completion: @escaping (EnginePeer?, DeviceContactStableId, DeviceContactExtendedData) -> Void) {
    let contactsController = context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: context, title: { $0.Contacts_Title }, displayDeviceContacts: true))
    contactsController.navigationPresentation = .modal
    (parentController.navigationController as? NavigationController)?.pushViewController(contactsController)
    let _ = (contactsController.result
    |> deliverOnMainQueue).start(next: { result in
        if let (peers, _, _, _, _) = result, let peer = peers.first {
            let dataSignal: Signal<(EnginePeer?, DeviceContactStableId?), NoError>
            switch peer {
                case let .peer(contact, _, _):
                    guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                        return
                    }
                    dataSignal = (context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                    |> take(1)
                    |> mapToSignal { basicData -> Signal<(EnginePeer?, DeviceContactStableId?), NoError> in
                        var stableId: String?
                        let queryPhoneNumber = formatPhoneNumber(phoneNumber)
                        outer: for (id, data) in basicData {
                            for phoneNumber in data.phoneNumbers {
                                if formatPhoneNumber(phoneNumber.value) == queryPhoneNumber {
                                    stableId = id
                                    break outer
                                }
                            }
                        }
                        return .single((EnginePeer.user(contact), stableId))
                    }
                case let .deviceContact(id, _):
                    dataSignal = .single((nil, id))
            }
            let _ = (dataSignal
            |> deliverOnMainQueue).start(next: { peer, stableId in
                guard let stableId = stableId else {
                    parentController.present(deviceContactInfoController(context: context, subject: .create(peer: peer?._asPeer(), contactData: contactData, isSharing: false, shareViaException: false, completion: { peer, stableId, contactData in
                    }), completed: nil, cancelled: nil), in: .window(.root))
                    return
                }
                if let contactDataManager = context.sharedContext.contactDataManager {
                    let _ = (contactDataManager.appendContactData(contactData, to: stableId)
                    |> deliverOnMainQueue).start(next: { contactData in
                        guard let contactData = contactData else {
                            return
                        }
                        let _ = (context.engine.data.get(
                            TelegramEngine.EngineData.Item.Contacts.List(includePresences: false)
                        )
                        |> deliverOnMainQueue).start(next: { view in
                            let phones = Set<String>(contactData.basicData.phoneNumbers.map {
                                return formatPhoneNumber($0.value)
                            })
                            var foundPeer: EnginePeer?
                            for peer in view.peers {
                                if case let .user(user) = peer, let phone = user.phone {
                                    let phone = formatPhoneNumber(phone)
                                    if phones.contains(phone) {
                                        foundPeer = peer
                                        break
                                    }
                                }
                            }
                            completion(foundPeer, stableId, contactData)
                        })
                    })
                }
            })
        }
    })
}

extension ContactInfoScreen: MFMessageComposeViewControllerDelegate {
    func inviteContact(presentationData: PresentationData, numbers: [String]) {
        if MFMessageComposeViewController.canSendText() {
            let composer = MFMessageComposeViewController()
            composer.messageComposeDelegate = self
            composer.recipients = Array(Set(numbers))
            let url = presentationData.strings.InviteText_URL
            let body = presentationData.strings.InviteText_SingleContact(url).string
            composer.body = body
            self.composer = composer
            if let window = self.view.window {
                window.rootViewController?.present(composer, animated: true)
            }
        }
    }

    @objc public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        self.composer = nil

        controller.dismiss(animated: true, completion: nil)

        guard case .sent = result else {
            return
        }
    }
}
