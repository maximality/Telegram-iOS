import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import CoreLocation
import DeviceLocationManager
import AccountContext

public final class LiveLocationManagerImpl: LiveLocationManager {
    private let queue = Queue.mainQueue()
    
    private let account: Account
    private let locationManager: DeviceLocationManager
    
    private let summaryManagerImpl: LiveLocationSummaryManagerImpl
    public var summaryManager: LiveLocationSummaryManager {
        return self.summaryManagerImpl
    }
    
    private var requiredLocationTypeDisposable: Disposable?
    private let hasActiveMessagesToBroadcast = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    public var isPolling: Signal<Bool, NoError> {
        return self.pollingOnce.get()
    }
    private let pollingOnce = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var pollingOnceValue = false {
        didSet {
            self.pollingOnce.set(self.pollingOnceValue)
        }
    }
    
    private let deviceLocationDisposable = MetaDisposable()
    private let updateCoordinateDisposable = MetaDisposable()
    private var messagesDisposable: Disposable?
    
    private var deviceLocationPromise = Promise<(CLLocation, Double?)>()
    
    private var broadcastToMessageIds: [MessageId: Int32] = [:]
    private var stopMessageIds = Set<MessageId>()
    
    private let editMessageDisposables = DisposableDict<MessageId>()
    
    private var invalidationTimer: (SwiftSignalKit.Timer, Int32)?
    
    public init(engine: TelegramEngine, account: Account, locationManager: DeviceLocationManager, inForeground: Signal<Bool, NoError>) {
        self.account = account
        self.locationManager = locationManager
        
        self.summaryManagerImpl = LiveLocationSummaryManagerImpl(queue: self.queue, engine: engine, postbox: account.postbox, accountPeerId: account.peerId, viewTracker: account.viewTracker)
        
        let viewKey: PostboxViewKey = .localMessageTag(.OutgoingLiveLocation)
        self.messagesDisposable = (account.postbox.combinedView(keys: [viewKey])
        |> deliverOn(self.queue)).start(next: { [weak self] view in
            if let strongSelf = self {
                let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                
                var broadcastToMessageIds: [MessageId: Int32] = [:]
                var stopMessageIds = Set<MessageId>()
                
                if let view = view.views[viewKey] as? LocalMessageTagsView {
                    for message in view.messages.values {
                        if !message.flags.contains(.Incoming) {
                            if message.flags.intersection([.Failed, .Unsent]).isEmpty {
                                var activeLiveBroadcastingTimeout: Int32?
                                for media in message.media {
                                    if let telegramMap = media as? TelegramMediaMap {
                                        if let liveBroadcastingTimeout = telegramMap.liveBroadcastingTimeout {
                                            if message.timestamp + liveBroadcastingTimeout > timestamp {
                                                activeLiveBroadcastingTimeout = liveBroadcastingTimeout
                                            }
                                        }
                                    }
                                }
                                if let activeLiveBroadcastingTimeout = activeLiveBroadcastingTimeout {
                                    broadcastToMessageIds[message.id] = message.timestamp + activeLiveBroadcastingTimeout
                                } else {
                                    stopMessageIds.insert(message.id)
                                }
                            }
                        } else {
                            assertionFailure()
                        }
                    }
                }
                
                strongSelf.update(broadcastToMessageIds: broadcastToMessageIds, stopMessageIds: stopMessageIds)
            }
        })
        
        self.requiredLocationTypeDisposable = (combineLatest(
            inForeground |> deliverOn(self.queue),
            self.hasActiveMessagesToBroadcast.get() |> deliverOn(self.queue),
            self.pollingOnce.get() |> deliverOn(self.queue)
        )
        |> map { inForeground, hasActiveMessagesToBroadcast, pollingOnce -> Bool in
            if (inForeground || pollingOnce) && hasActiveMessagesToBroadcast {
                return true
            } else {
                return false
            }
        }
        |> distinctUntilChanged
        |> deliverOn(self.queue)).start(next: { [weak self] value in
            if let strongSelf = self {
                if value {
                    strongSelf.deviceLocationDisposable.set(strongSelf.locationManager.push(mode: .precise, updated: { [weak self] location, heading in
                        self?.deviceLocationPromise.set(.single((location, heading)))
                    }))
                } else {
                    strongSelf.deviceLocationDisposable.set(nil)
                }
            }
        })
        
        let throttledDeviceLocation = self.deviceLocationPromise.get()
        |> mapToThrottled { next -> Signal<(CLLocation, Double?), NoError> in
            return .single(next) |> then(.complete() |> delay(4.0, queue: Queue.concurrentDefaultQueue()))
        }
        
        self.updateCoordinateDisposable.set((throttledDeviceLocation
        |> deliverOn(self.queue)).start(next: { [weak self] location, heading in
            if let strongSelf = self {
                var effectiveHeading = heading ?? location.course
                if location.speed > 1.0 {
                    effectiveHeading = location.course
                }
                strongSelf.updateDeviceCoordinate(location.coordinate, accuracyRadius: location.horizontalAccuracy, heading: effectiveHeading)
            }
        }))
    }
    
    deinit {
        self.requiredLocationTypeDisposable?.dispose()
        self.deviceLocationDisposable.dispose()
        self.updateCoordinateDisposable.dispose()
        self.messagesDisposable?.dispose()
        self.editMessageDisposables.dispose()
        self.invalidationTimer?.0.invalidate()
    }
    
    private func update(broadcastToMessageIds: [MessageId: Int32], stopMessageIds: Set<MessageId>) {
        assert(self.queue.isCurrent())
        
        if self.broadcastToMessageIds == broadcastToMessageIds && self.stopMessageIds == stopMessageIds {
            return
        }
        
        let validBroadcastToMessageIds = Set(broadcastToMessageIds.keys)
        if self.broadcastToMessageIds != broadcastToMessageIds {
            self.summaryManagerImpl.update(messageIds: validBroadcastToMessageIds)
        }
        
        let wasEmpty = self.broadcastToMessageIds.isEmpty
        self.broadcastToMessageIds = broadcastToMessageIds
        
        let removedFromActions = Set(self.broadcastToMessageIds.keys).union(self.stopMessageIds).subtracting(validBroadcastToMessageIds.union(stopMessageIds))
        for id in removedFromActions {
            self.editMessageDisposables.set(nil, forKey: id)
        }
        
        if !broadcastToMessageIds.isEmpty {
            if wasEmpty {
               self.hasActiveMessagesToBroadcast.set(true)
            }
        } else if !wasEmpty {
            self.hasActiveMessagesToBroadcast.set(false)
        }
        
        let addedStopped = stopMessageIds.subtracting(self.stopMessageIds)
        self.stopMessageIds = stopMessageIds
        for id in addedStopped {
            self.editMessageDisposables.set((TelegramEngine(account: self.account).messages.requestEditLiveLocation(messageId: id, stop: true, coordinate: nil, heading: nil, proximityNotificationRadius: nil)
                |> deliverOn(self.queue)).start(completed: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.editMessageDisposables.set(nil, forKey: id)
                    }
                }), forKey: id)
        }
        
        self.rescheduleTimer()
    }
    
    private func rescheduleTimer() {
        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        
        var updatedBroadcastToMessageIds = self.broadcastToMessageIds
        var updatedStopMessageIds = self.stopMessageIds
        
        var earliestCancelIdAndTimestamp: (MessageId, Int32)?
        for (id, timestamp) in self.broadcastToMessageIds {
            if currentTimestamp >= timestamp {
                updatedBroadcastToMessageIds.removeValue(forKey: id)
                updatedStopMessageIds.insert(id)
            } else {
                if earliestCancelIdAndTimestamp == nil || timestamp < earliestCancelIdAndTimestamp!.1 {
                    earliestCancelIdAndTimestamp = (id, timestamp)
                }
            }
        }
        
        if let (_, timestamp) = earliestCancelIdAndTimestamp {
            if self.invalidationTimer?.1 != timestamp {
                self.invalidationTimer?.0.invalidate()
                
                let timer = SwiftSignalKit.Timer(timeout: Double(max(0, timestamp - currentTimestamp)), repeat: false, completion: { [weak self] in
                    self?.invalidationTimer?.0.invalidate()
                    self?.invalidationTimer = nil
                    self?.rescheduleTimer()
                }, queue: self.queue)
                self.invalidationTimer = (timer, timestamp)
                timer.start()
            }
        } else if let (timer, _) = self.invalidationTimer {
            self.invalidationTimer = nil
            timer.invalidate()
        }
        
        self.update(broadcastToMessageIds: updatedBroadcastToMessageIds, stopMessageIds: updatedStopMessageIds)
    }
    
    private func updateDeviceCoordinate(_ coordinate: CLLocationCoordinate2D, accuracyRadius: Double, heading: Double?) {
        assert(self.queue.isCurrent())
        
        let ids = self.broadcastToMessageIds
        let remainingIds = Atomic<Set<MessageId>>(value: Set(ids.keys))
        for id in ids.keys {
            self.editMessageDisposables.set((TelegramEngine(account: self.account).messages.requestEditLiveLocation(messageId: id, stop: false, coordinate: (latitude: coordinate.latitude, longitude: coordinate.longitude, accuracyRadius: Int32(accuracyRadius)), heading: heading.flatMap { Int32($0) }, proximityNotificationRadius: nil)
            |> deliverOn(self.queue)).start(completed: { [weak self] in
                if let strongSelf = self {
                    strongSelf.editMessageDisposables.set(nil, forKey: id)
                    
                    let result = remainingIds.modify { current in
                        var current = current
                        current.remove(id)
                        return current
                    }
                    if result.isEmpty {
                        strongSelf.pollingOnceValue = false
                    }
                }
            }), forKey: id)
        }
    }
    
    public func cancelLiveLocation(peerId: PeerId) {
        assert(self.queue.isCurrent())
        
        let ids = self.broadcastToMessageIds.keys.filter({ $0.peerId == peerId })
        if !ids.isEmpty {
            let _ = self.account.postbox.transaction({ transaction -> Void in
                for id in ids {
                    transaction.updateMessage(id, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        var updatedMedia = currentMessage.media
                        let timestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        for i in 0 ..< updatedMedia.count {
                            if let media = updatedMedia[i] as? TelegramMediaMap, let _ = media.liveBroadcastingTimeout {
                                updatedMedia[i] = TelegramMediaMap(latitude: media.latitude, longitude: media.longitude, heading: media.heading, accuracyRadius: media.accuracyRadius, geoPlace: media.geoPlace, venue: media.venue, liveBroadcastingTimeout: max(0, timestamp - currentMessage.timestamp - 1), liveProximityNotificationRadius: nil)
                            }
                        }
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: updatedMedia))
                    })
                }
            }).start()
        }
    }
    
    public func pollOnce() {
        if !self.broadcastToMessageIds.isEmpty {
            self.pollingOnceValue = true
        }
    }
    
    public func internalMessageForPeerId(_ peerId: PeerId) -> MessageId? {
        for id in self.broadcastToMessageIds.keys {
            if id.peerId == peerId {
                return id
            }
        }
        return nil
    }
}
