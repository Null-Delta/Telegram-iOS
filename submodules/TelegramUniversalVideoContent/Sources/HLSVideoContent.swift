import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AVFoundation
import UniversalMediaPlayer
import TelegramAudio
import AccountContext
import PhotoResources
import RangeSet
import TelegramVoip

public final class HLSVideoContent: UniversalVideoContent {
    public let id: AnyHashable
    public let nativeId: PlatformVideoContentId
    let userLocation: MediaResourceUserLocation
    public let fileReference: FileMediaReference
    public let dimensions: CGSize
    public let duration: Double
    let streamVideo: Bool
    let loopVideo: Bool
    let enableSound: Bool
    let baseRate: Double
    let fetchAutomatically: Bool
    
    public init(id: PlatformVideoContentId, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool = false, loopVideo: Bool = false, enableSound: Bool = true, baseRate: Double = 1.0, fetchAutomatically: Bool = true) {
        self.id = id
        self.userLocation = userLocation
        self.nativeId = id
        self.fileReference = fileReference
        self.dimensions = self.fileReference.media.dimensions?.cgSize ?? CGSize(width: 480, height: 320)
        self.duration = self.fileReference.media.duration ?? 0.0
        self.streamVideo = streamVideo
        self.loopVideo = loopVideo
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.fetchAutomatically = fetchAutomatically
    }
    
    public func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return HLSVideoContentNode(postbox: postbox, audioSessionManager: audioSession, userLocation: self.userLocation, fileReference: self.fileReference, streamVideo: self.streamVideo, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically)
    }
    
    public func isEqual(to other: UniversalVideoContent) -> Bool {
        if let other = other as? HLSVideoContent {
            if case let .message(_, stableId, _) = self.nativeId {
                if case .message(_, stableId, _) = other.nativeId {
                    if self.fileReference.media.isInstantVideo {
                        return true
                    }
                }
            }
        }
        return false
    }
}

private final class HLSVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private final class HLSServerSource: SharedHLSServer.Source {
        let id: UUID
        let postbox: Postbox
        let userLocation: MediaResourceUserLocation
        let playlistFiles: [Int: FileMediaReference]
        let qualityFiles: [Int: FileMediaReference]
        
        private var playlistFetchDisposables: [Int: Disposable] = [:]
        
        init(id: UUID, postbox: Postbox, userLocation: MediaResourceUserLocation, playlistFiles: [Int: FileMediaReference], qualityFiles: [Int: FileMediaReference]) {
            self.id = id
            self.postbox = postbox
            self.userLocation = userLocation
            self.playlistFiles = playlistFiles
            self.qualityFiles = qualityFiles
        }
        
        deinit {
            for (_, disposable) in self.playlistFetchDisposables {
                disposable.dispose()
            }
        }
        
        func masterPlaylistData() -> Signal<String, NoError> {
            var playlistString: String = ""
            playlistString.append("#EXTM3U\n")
            
            for (quality, file) in self.qualityFiles.sorted(by: { $0.key > $1.key }) {
                let width = file.media.dimensions?.width ?? 1280
                let height = file.media.dimensions?.height ?? 720
                
                let bandwidth: Int
                if let size = file.media.size, let duration = file.media.duration, duration != 0.0 {
                    bandwidth = Int(Double(size) / duration) * 8
                } else {
                    bandwidth = 1000000
                }
                
                playlistString.append("#EXT-X-STREAM-INF:BANDWIDTH=\(bandwidth),RESOLUTION=\(width)x\(height)\n")
                playlistString.append("hls_level_\(quality).m3u8\n")
            }
            return .single(playlistString)
        }
        
        func playlistData(quality: Int) -> Signal<String, NoError> {
            guard let playlistFile = self.playlistFiles[quality] else {
                return .never()
            }
            if self.playlistFetchDisposables[quality] == nil {
                self.playlistFetchDisposables[quality] = freeMediaFileResourceInteractiveFetched(postbox: self.postbox, userLocation: self.userLocation, fileReference: playlistFile, resource: playlistFile.media.resource).startStrict()
            }
            
            return self.postbox.mediaBox.resourceData(playlistFile.media.resource)
            |> filter { data in
                return data.complete
            }
            |> map { data -> String in
                guard data.complete else {
                    return ""
                }
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                    return ""
                }
                guard var playlistString = String(data: data, encoding: .utf8) else {
                    return ""
                }
                let partRegex = try! NSRegularExpression(pattern: "mtproto:([\\d]+)", options: [])
                let results = partRegex.matches(in: playlistString, range: NSRange(playlistString.startIndex..., in: playlistString))
                for result in results.reversed() {
                    if let range = Range(result.range, in: playlistString) {
                        if let fileIdRange = Range(result.range(at: 1), in: playlistString) {
                            let fileId = String(playlistString[fileIdRange])
                            playlistString.replaceSubrange(range, with: "partfile\(fileId).mp4")
                        }
                    }
                }
                return playlistString
            }
        }
        
        func partData(index: Int, quality: Int) -> Signal<Data?, NoError> {
            return .never()
        }
        
        func fileData(id: Int64, range: Range<Int>) -> Signal<(Data, Int)?, NoError> {
            guard let file = self.qualityFiles.values.first(where: { $0.media.fileId.id == id }) else {
                return .single(nil)
            }
            guard let size = file.media.size else {
                return .single(nil)
            }
            
            let postbox = self.postbox
            let userLocation = self.userLocation
            
            let mappedRange: Range<Int64> = Int64(range.lowerBound) ..< Int64(range.upperBound)
            
            return Signal { subscriber in
                if let fetchResource = postbox.mediaBox.fetchResource {
                    let location = MediaResourceStorageLocation(userLocation: userLocation, reference: file.resourceReference(file.media.resource))
                    let params = MediaResourceFetchParameters(
                        tag: TelegramMediaResourceFetchTag(statsCategory: .video, userContentType: .video),
                        info: TelegramCloudMediaResourceFetchInfo(reference: file.resourceReference(file.media.resource), preferBackgroundReferenceRevalidation: true, continueInBackground: true),
                        location: location,
                        contentType: .video,
                        isRandomAccessAllowed: true
                    )
                    
                    final class StoredState {
                        let range: Range<Int64>
                        var data: Data
                        var ranges: RangeSet<Int64>
                        
                        init(range: Range<Int64>) {
                            self.range = range
                            self.data = Data(count: Int(range.upperBound - range.lowerBound))
                            self.ranges = RangeSet(range)
                        }
                    }
                    let storedState = Atomic<StoredState>(value: StoredState(range: mappedRange))
                    
                    return fetchResource(file.media.resource, .single([(mappedRange, .elevated)]), params).start(next: { result in
                        switch result {
                        case let .dataPart(resourceOffset, data, _, _):
                            if !data.isEmpty {
                                let partRange = resourceOffset ..< (resourceOffset + Int64(data.count))
                                var isReady = false
                                storedState.with { storedState in
                                    let overlapRange = partRange.clamped(to: storedState.range)
                                    guard !overlapRange.isEmpty else {
                                        return
                                    }
                                    let innerRange = (overlapRange.lowerBound - storedState.range.lowerBound) ..< (overlapRange.upperBound - storedState.range.lowerBound)
                                    let dataStart = overlapRange.lowerBound - partRange.lowerBound
                                    let dataEnd = overlapRange.upperBound - partRange.lowerBound
                                    let innerData = data.subdata(in: Int(dataStart) ..< Int(dataEnd))
                                    storedState.data.replaceSubrange(Int(innerRange.lowerBound) ..< Int(innerRange.upperBound), with: innerData)
                                    storedState.ranges.subtract(RangeSet(overlapRange))
                                    if storedState.ranges.isEmpty {
                                        isReady = true
                                    }
                                }
                                if isReady {
                                    subscriber.putNext((storedState.with({ $0.data }), Int(size)))
                                    subscriber.putCompletion()
                                }
                            }
                        default:
                            break
                        }
                    })
                } else {
                    return EmptyDisposable
                }
                
                /*let fetchDisposable = freeMediaFileResourceInteractiveFetched(postbox: postbox, userLocation: userLocation, fileReference: file, resource: file.media.resource, range: (mappedRange, .elevated)).startStandalone()
                
                let dataDisposable = postbox.mediaBox.resourceData(file.media.resource, size: size, in: mappedRange).startStandalone(next: { value, isComplete in
                    if isComplete {
                        subscriber.putNext((value, Int(size)))
                        subscriber.putCompletion()
                    }
                })
                return ActionDisposable {
                    fetchDisposable.dispose()
                    dataDisposable.dispose()
                }*/
            }
        }
    }
    
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let approximateDuration: Double
    private let intrinsicDimensions: CGSize

    private let audioSessionManager: ManagedAudioSession
    private let audioSessionDisposable = MetaDisposable()
    private var hasAudioSession = false
    
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private var statusValue = MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
    private var isBuffering = false
    private var seekId: Int = 0
    private let _status = ValuePromise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let _preloadCompleted = ValuePromise<Bool>()
    var preloadCompleted: Signal<Bool, NoError> {
        return self._preloadCompleted.get()
    }
    
    private var playerSource: HLSServerSource?
    private var serverDisposable: Disposable?
    
    private let imageNode: TransformImageNode
    
    private var playerItem: AVPlayerItem?
    private let player: AVPlayer
    private let playerNode: ASDisplayNode
    
    private var loadProgressDisposable: Disposable?
    private var statusDisposable: Disposable?
    
    private var didPlayToEndTimeObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var willResignActiveObserver: NSObjectProtocol?
    private var failureObserverId: NSObjectProtocol?
    private var errorObserverId: NSObjectProtocol?
    private var playerItemFailedToPlayToEndTimeObserver: NSObjectProtocol?
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: CGSize?
    
    private var statusTimer: Foundation.Timer?
    
    private var preferredVideoQuality: UniversalVideoContentVideoQuality = .auto
    
    init(postbox: Postbox, audioSessionManager: ManagedAudioSession, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, streamVideo: Bool, loopVideo: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool) {
        self.postbox = postbox
        self.fileReference = fileReference
        self.approximateDuration = fileReference.media.duration ?? 0.0
        self.audioSessionManager = audioSessionManager
        self.userLocation = userLocation
        
        self.imageNode = TransformImageNode()
        
        var startTime = CFAbsoluteTimeGetCurrent()
        
        let player = AVPlayer(playerItem: nil)
        self.player = player
        if !enableSound {
            player.volume = 0.0
        }
        
        print("Player created in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        
        self.playerNode = ASDisplayNode()
        self.playerNode.setLayerBlock({
            return AVPlayerLayer(player: player)
        })
        
        self.intrinsicDimensions = fileReference.media.dimensions?.cgSize ?? CGSize(width: 480.0, height: 320.0)
        
        self.playerNode.frame = CGRect(origin: CGPoint(), size: self.intrinsicDimensions)
        
        var qualityFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in fileReference.media.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                for attribute in alternativeFile.attributes {
                    if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                        let _ = size
                        if let videoCodec, NativeVideoContent.isVideoCodecSupported(videoCodec: videoCodec) {
                            qualityFiles[Int(size.height)] = fileReference.withMedia(alternativeFile)
                        }
                    }
                }
            }
        }
        /*for key in Array(qualityFiles.keys) {
            if key != 144 && key != 720 {
                qualityFiles.removeValue(forKey: key)
            }
        }*/
        var playlistFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in fileReference.media.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                if alternativeFile.mimeType == "application/x-mpegurl" {
                    if let fileName = alternativeFile.fileName {
                        if fileName.hasPrefix("mtproto:") {
                            let fileIdString = String(fileName[fileName.index(fileName.startIndex, offsetBy: "mtproto:".count)...])
                            if let fileId = Int64(fileIdString) {
                                for (quality, file) in qualityFiles {
                                    if file.media.fileId.id == fileId {
                                        playlistFiles[quality] = fileReference.withMedia(alternativeFile)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if !playlistFiles.isEmpty && playlistFiles.keys == qualityFiles.keys {
            self.playerSource = HLSServerSource(id: UUID(), postbox: postbox, userLocation: userLocation, playlistFiles: playlistFiles, qualityFiles: qualityFiles)
        }
        
        
        super.init()

        self.imageNode.setSignal(internalMediaGridMessageVideo(postbox: postbox, userLocation: self.userLocation, videoReference: fileReference) |> map { [weak self] getSize, getData in
            Queue.mainQueue().async {
                if let strongSelf = self, strongSelf.dimensions == nil {
                    if let dimensions = getSize() {
                        strongSelf.dimensions = dimensions
                        strongSelf.dimensionsPromise.set(dimensions)
                        if let size = strongSelf.validLayout {
                            strongSelf.updateLayout(size: size, transition: .immediate)
                        }
                    }
                }
            }
            return getData
        })
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        self.player.actionAtItemEnd = .pause
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
        
        self.player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
        
        self._bufferingStatus.set(.single(nil))
        
        startTime = CFAbsoluteTimeGetCurrent()
        
        if let playerSource = self.playerSource {
            self.serverDisposable = SharedHLSServer.shared.registerPlayer(source: playerSource)
            
            let playerItem: AVPlayerItem
            let assetUrl = "http://127.0.0.1:\(SharedHLSServer.shared.port)/\(playerSource.id)/master.m3u8"
            #if DEBUG
            print("HLSVideoContentNode: playing \(assetUrl)")
            #endif
            playerItem = AVPlayerItem(url: URL(string: assetUrl)!)
            print("Player item created in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
            
            if #available(iOS 14.0, *) {
                playerItem.startsOnFirstEligibleVariant = true
            }
            
            startTime = CFAbsoluteTimeGetCurrent()
            self.setPlayerItem(playerItem)
            print("Set player item in \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        }
        
        self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: nil, using: { [weak self] notification in
            self?.performActionAtEnd()
        })
        
        self.failureObserverId = NotificationCenter.default.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: self.player.currentItem, queue: .main, using: { notification in
            print("Player Error: \(notification.description)")
        })
        self.errorObserverId = NotificationCenter.default.addObserver(forName: AVPlayerItem.newErrorLogEntryNotification, object: self.player.currentItem, queue: .main, using: { notification in
            print("Player Error: \(notification.description)")
        })
        
        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let strongSelf = self, let layer = strongSelf.playerNode.layer as? AVPlayerLayer else {
                return
            }
            layer.player = strongSelf.player
        })
        self.willResignActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil, using: { [weak self] _ in
            guard let strongSelf = self, let layer = strongSelf.playerNode.layer as? AVPlayerLayer else {
                return
            }
            layer.player = nil
        })
        if let currentItem = self.player.currentItem {
            currentItem.addObserver(self, forKeyPath: "presentationSize", options: [], context: nil)
        }
    }
    
    deinit {
        self.player.removeObserver(self, forKeyPath: "rate")
        if let currentItem = self.player.currentItem {
            currentItem.removeObserver(self, forKeyPath: "presentationSize")
        }
        
        self.setPlayerItem(nil)
        
        self.audioSessionDisposable.dispose()
        
        self.loadProgressDisposable?.dispose()
        self.statusDisposable?.dispose()
        
        if let didPlayToEndTimeObserver = self.didPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(didPlayToEndTimeObserver)
        }
        if let didBecomeActiveObserver = self.didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let willResignActiveObserver = self.willResignActiveObserver {
            NotificationCenter.default.removeObserver(willResignActiveObserver)
        }
        if let failureObserverId = self.failureObserverId {
            NotificationCenter.default.removeObserver(failureObserverId)
        }
        if let errorObserverId = self.errorObserverId {
            NotificationCenter.default.removeObserver(errorObserverId)
        }
        
        self.serverDisposable?.dispose()
        
        self.statusTimer?.invalidate()
    }
    
    private func setPlayerItem(_ item: AVPlayerItem?) {
        if let playerItem = self.playerItem {
            playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty")
            playerItem.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            playerItem.removeObserver(self, forKeyPath: "playbackBufferFull")
            playerItem.removeObserver(self, forKeyPath: "status")
            if let playerItemFailedToPlayToEndTimeObserver = self.playerItemFailedToPlayToEndTimeObserver {
                NotificationCenter.default.removeObserver(playerItemFailedToPlayToEndTimeObserver)
                self.playerItemFailedToPlayToEndTimeObserver = nil
            }
        }
        
        self.playerItem = item
        
        if let playerItem = self.playerItem {
            playerItem.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
            playerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            self.playerItemFailedToPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: OperationQueue.main, using: { [weak self] _ in
                guard let self else {
                    return
                }
                let _ = self
            })
        }
        
        self.player.replaceCurrentItem(with: self.playerItem)
    }
    
    private func updateStatus() {
        let isPlaying = !self.player.rate.isZero
        let status: MediaPlayerPlaybackStatus
        if self.isBuffering {
            status = .buffering(initial: false, whilePlaying: isPlaying, progress: 0.0, display: true)
        } else {
            status = isPlaying ? .playing : .paused
        }
        var timestamp = self.player.currentTime().seconds
        if timestamp.isFinite && !timestamp.isNaN {
        } else {
            timestamp = 0.0
        }
        self.statusValue = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: timestamp, baseRate: Double(self.player.rate), seekId: self.seekId, status: status, soundEnabled: true)
        self._status.set(self.statusValue)
        
        if case .playing = status {
            if self.statusTimer == nil {
                self.statusTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateStatus()
                })
            }
        } else if let statusTimer = self.statusTimer {
            self.statusTimer = nil
            statusTimer.invalidate()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            let isPlaying = !self.player.rate.isZero
            if isPlaying {
               self.isBuffering = false
            }
            self.updateStatus()
        } else if keyPath == "playbackBufferEmpty" {
            self.isBuffering = true
            self.updateStatus()
        } else if keyPath == "playbackLikelyToKeepUp" || keyPath == "playbackBufferFull" {
            self.isBuffering = false
            self.updateStatus()
        } else if keyPath == "presentationSize" {
            if let currentItem = self.player.currentItem {
                print("Presentation size: \(Int(currentItem.presentationSize.height))")
            }
        }
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updatePosition(node: self.playerNode, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformScale(node: self.playerNode, scale: size.width / self.intrinsicDimensions.width)
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let makeImageLayout = self.imageNode.asyncLayout()
        let applyImageLayout = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: size, boundingSize: size, intrinsicInsets: UIEdgeInsets()))
        applyImageLayout()
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        if !self.initializedStatus {
            self._status.set(MediaPlayerStatus(generationTimestamp: 0.0, duration: Double(self.approximateDuration), dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: self.seekId, status: .buffering(initial: true, whilePlaying: true, progress: 0.0, display: true), soundEnabled: true))
        }
        if !self.hasAudioSession {
            if self.player.volume != 0.0 {
                self.audioSessionDisposable.set(self.audioSessionManager.push(audioSessionType: .play(mixWithOthers: false), activate: { [weak self] _ in
                    self?.hasAudioSession = true
                    self?.player.play()
                }, deactivate: { [weak self] _ in
                    self?.hasAudioSession = false
                    self?.player.pause()
                    return .complete()
                }))
            } else {
                self.player.play()
            }
        } else {
            self.player.play()
        }
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        if self.player.rate.isZero {
            self.play()
        } else {
            self.pause()
        }
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if value {
            if !self.hasAudioSession {
                self.audioSessionDisposable.set(self.audioSessionManager.push(audioSessionType: .play(mixWithOthers: false), activate: { [weak self] _ in
                    self?.hasAudioSession = true
                    self?.player.volume = 1.0
                }, deactivate: { [weak self] _ in
                    self?.hasAudioSession = false
                    self?.player.pause()
                    return .complete()
                }))
            }
        } else {
            self.player.volume = 0.0
            self.hasAudioSession = false
            self.audioSessionDisposable.set(nil)
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.seekId += 1
        self.player.seek(to: CMTime(seconds: timestamp, preferredTimescale: 30))
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        self.player.volume = 1.0
        self.play()
    }
    
    func setSoundMuted(soundMuted: Bool) {
        self.player.volume = soundMuted ? 0.0 : 1.0
    }
    
    func continueWithOverridingAmbientMode(isAmbient: Bool) {
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        self.player.volume = 0.0
        self.hasAudioSession = false
        self.audioSessionDisposable.set(nil)
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {   
    }
    
    func setBaseRate(_ baseRate: Double) {
        self.player.rate = Float(baseRate)
    }
    
    func setVideoQuality(_ videoQuality: UniversalVideoContentVideoQuality) {
        self.preferredVideoQuality = videoQuality
        
        guard let currentItem = self.player.currentItem else {
            return
        }
        guard let playerSource = self.playerSource else {
            return
        }
        
        switch videoQuality {
        case .auto:
            currentItem.preferredPeakBitRate = 0.0
        case let .quality(qualityValue):
            if let file = playerSource.qualityFiles[qualityValue] {
                if let size = file.media.size, let duration = file.media.duration, duration != 0.0 {
                    let bandwidth = Int(Double(size) / duration) * 8
                    currentItem.preferredPeakBitRate = Double(bandwidth)
                }
            }
        }
        
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        guard let currentItem = self.player.currentItem else {
            return nil
        }
        guard let playerSource = self.playerSource else {
            return nil
        }
        let current = Int(currentItem.presentationSize.height)
        var available: [Int] = Array(playerSource.qualityFiles.keys)
        available.sort(by: { $0 > $1 })
        return (current, self.preferredVideoQuality, available)
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
    }
    
    func notifyPlaybackControlsHidden(_ hidden: Bool) {
    }

    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
    }
}
