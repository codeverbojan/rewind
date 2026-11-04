"""Bounded sequential host checks; no servers, browsers or device writes."""
import ast,json,subprocess,pathlib,sys
root=pathlib.Path(__file__).resolve().parent
version=next(ast.literal_eval(n.value) for n in ast.parse((root/'build.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='VERSION' for t in n.targets))
assert isinstance(version,str) and version.startswith('0.') and version[2:].isdigit()
build=root/'build';diag=root.parent/'diagnostics';base=['/usr/bin/clang','-fobjc-arc','-framework','Foundation']
# Compile the exact production snapshot method against deliberately absent startup services.
snapshot_source=(root/'RewindDiscoveryStore.inc').read_text()
a=snapshot_source.index('- (NSDictionary *)discoveryInputSnapshot {');b=snapshot_source.index('\n- (void)noteDiscoveryExposure:',a)
(build/'discovery-snapshot-under-test.inc').write_text(snapshot_source[a:b])
# Exercise exact production appearance + admission methods after modal/rotation.
def method(path, signature):
 text=(root/path).read_text(); start=text.index(signature); end=text.find('\n- (',start+len(signature)); return text[start:end if end>=0 else len(text)]
(build/'discovery-appearance-under-test.inc').write_text(method('RewindPreview.inc','- (void)viewDidAppear:')+'\n'+method('RewindDiscoveryScreens.inc','- (void)syncDiscoveryActivity'))
tracker_src=root.parent/'downloads/standalone-media-sources'
tracker_flags=['-std=c++14','-lc++','-DTORRENT_USE_OPENSSL','-DTORRENT_USE_I2P=0','-DTORRENT_DISABLE_LOGGING','-DBOOST_ASIO_HAS_STD_CHRONO','-DBOOST_ASIO_USE_TS_EXECUTOR_AS_DEFAULT','-DBOOST_EXCEPTION_DISABLE','-Wno-deprecated-declarations',
 '-I'+str(tracker_src/'libtorrent-rasterbar-1.2.20/include'),'-I'+str(tracker_src/'boost_1_84_0'),'-I'+str(build/'openssl-3.5.9-host/include'),
 str(build/'torrent-observer-261-host/libtorrent.a'),str(build/'openssl-3.5.9-host/libssl.a'),str(build/'openssl-3.5.9-host/libcrypto.a'),'-framework','SystemConfiguration','-framework','CoreFoundation','-lz']
suites=[
 ('stack-read-policy',['Tests/StackReadPolicyTests.cpp'],[],None),
 ('caption-clock',['Tests/CaptionClockTests.m','RWCaptionClock.m'],[],[]),
 ('frame-code',['Tests/FrameCodeTests.cpp'],[],None),
 ('font-lookup',['Tests/FontLookupProbeTests.m','RWFontLookupProbe.m'],[],['-framework','CoreText']),
 ('legacy-startup-trace',['Tests/LegacyStartupTraceTests.m'],[],[]),
 ('probe-connections',['Tests/ProbeConnectionsTests.cpp'],[],['-std=c++14','-lc++']),
 ('peer-transport',['Tests/PeerTransportTests.mm','Tests/PeerObserverSupport.mm'],[],tracker_flags),
 ('playback-lifetime',['Tests/PlaybackLifetimeTests.m','RWPlaybackLifetimeProbe.m'],[],[]), ('source-admission',['Tests/SourceAdmissionTests.m'],[],[]),
 ('codec-evidence',['Tests/CodecEvidenceTests.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWSourceExperience.m','RWMKVProbe.m'],[],['-framework','CoreMedia']),
 ('source-outcomes',['Tests/SourceOutcomeTests.m','RWSourceExperience.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWPlaybackMetrics.m'],[],[]),
 ('peer-evidence',['Tests/PeerEvidenceTests.mm'],[],tracker_flags),
 ('peer-metrics',['Tests/PeerMetricsTests.m','RWPlaybackMetrics.m'],[],[]),
 ('tracker-isolation',['Tests/TrackerIsolationTests.mm','Tests/PeerObserverSupport.mm'],[],tracker_flags),
 ('recovery-private',['Tests/RecoveryPrivateTests.mm','Tests/PeerObserverSupport.mm'],[str(root/'Resources/Rewind/recovery-275.torrent')],tracker_flags),
 ('tracker-policy',['Tests/TrackerPolicyTests.m','RWTrackerPolicy.m','RWSourcePolicy.m'],[],[]),
 ('subtitle-cadence',['Tests/SubtitleCadenceTests.m','RWSubtitleTicker.m','RWSubtitles.m'],[],['-I'+str(build)]),
 ('subtitle-load',['Tests/SubtitleLoadTests.m','RWSubtitleLoadProbe.m','RWSubtitles.m'],[],[]),
 ('audio-name-container',['Tests/AudioNameContainerTests.m','RWAudioPolicy.m','RWMKVProbe.m'],[str(root/'Resources/Rewind/audio-named.mp4'),str(root/'Resources/Rewind/audio-named.mkv')],['-framework','AVFoundation','-framework','CoreMedia','-Wno-deprecated-declarations']),
 ('audio-name',['Tests/AudioNameTests.m','RWAudioPolicy.m'],[],['-Wno-deprecated-declarations']),
 ('audio-fallback',['Tests/AudioFallbackTests.m','RWAudioPolicy.m','RWMKVProbe.m'],[str(root/'Resources/Rewind/audio-fallback.mp4'),str(root/'Resources/Rewind/audio-fallback.mkv')],['-framework','AVFoundation','-framework','CoreMedia','-Wno-deprecated-declarations']),
 ('subtitle-layout',['Tests/SubtitleLayoutTests.m','RWSubtitles.m'],[],['-framework','CoreGraphics']),
 ('subtitle-links',['Tests/SubtitleLinkTests.m','RWSubtitlePolicy.m','RWAudioPolicy.m','RWProfiles.m'],[],['-framework','Security']),
 ('subtitle-match',['Tests/SubtitleMatchTests.m','RWSubtitlePolicy.m','RWAudioPolicy.m'],[],[]),
 ('playback-profiles',['Tests/PlaybackProfileTests.m','RWProfiles.m'],[],['-framework','Security']),
 ('subtitle-mkv',['Tests/SubtitleMKVTests.m','RWSubtitlePolicy.m','RWMKVProbe.m'],[str(root/'Resources/Rewind/subtitle-check.mkv')],['-framework','CoreMedia']),
 ('subtitle-persistence',['Tests/SubtitlePersistenceTests.m','RWSubtitlePolicy.m','RWAudioPolicy.m'],[],[]),
 ('subtitle-policy',['Tests/SubtitlePolicyTests.m','RWSubtitlePolicy.m','RWAudioPolicy.m'],[],[]),
 ('subtitle-parser',['Tests/SubtitleParserTests.m','RWSubtitles.m'],[],[]),
 ('native-audio-metadata',['Tests/NativeAudioMetadataTests.m','RWAudioPolicy.m'],[str(root/'Resources/Rewind/audio-check.mp4')],['-framework','AVFoundation','-framework','CoreMedia','-Wno-deprecated-declarations']), ('mkv-audio-map',['Tests/MKVAudioMapTests.m','RWMKVAudioMap.m','RWAudioPolicy.m'],[],[]), ('audio-persistence',['Tests/AudioPersistenceTests.m','RWAudioPolicy.m'],[],[]), ('audio-policy',['Tests/AudioPolicyTests.m','RWAudioPolicy.m','RWMKVProbe.m'],[str(root/'Resources/Rewind/playback-test.mkv')],['-framework','CoreMedia']),
 ('credit-types',['Tests/CreditTypeTests.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('home-leading',['Tests/HomeLeadingTests.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWHomeCategoryPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('detail-related',['Tests/DetailRelatedTests.m'],[],[]),
 ('detail-navigation',['Tests/DetailNavigationTests.m'],[],[]),
 ('language-labels',['Tests/LanguageLabelsTests.m'],[str(root/'Resources/Rewind/language-labels.json'),str(root/'Research/languages-223')],[]),
 ('world-catalog',['Tests/WorldCatalogTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWHomeRailPolicy.m','RWHomeCategoryPolicy.m','RWRecommendationPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWAtomicWriter.m','RWCast.m'],[str(root/'Research/discovery-222')],[]),
 ('discovery-appearance',['Tests/DiscoveryAppearanceTests.m'],[],['-I'+str(build)]),
 ('discovery-startup',['Tests/DiscoveryStartupTests.m','RWHomeDelivery.m','RWDiscoveryMetadataPolicy.m'],[],['-I'+str(build)]),
 ('release-year',['Tests/ReleaseYearTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m','RWDiscoverySnapshot.m','RWDiscoveryEpisodes.m','RWTVPolicy.m','RWRatingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[str(root/'Resources/Rewind/discovery-metadata.json')],[]),
 ('title-artwork',['Tests/TitleArtworkTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m','RWArtworkPolicy.m'],[],[]),
 ('metadata-priority',['Tests/MetadataPriorityTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m'],[],[]),
 ('home-anchor-read',['Tests/HomeAnchorReadTests.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('visible-metadata-json',['Tests/VisibleMetadataJSONTests.m','RWRequestCoalescer.m','RWMetadataBudget.m','RWDiscoveryEpisodes.m'],[],['-I'+str(build)]),
 ('packed-episode-selection',['Tests/PackedEpisodeSelectionTests.m','RWDiscoveryEpisodes.m'],[],[]),
 ('home-catalog-cursor',['Tests/HomeCatalogCursorTests.m','RWHomeRailPolicy.m','RWHomeCategoryPolicy.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('home-feed-invalidation',['Tests/HomeFeedInvalidationTests.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('upcoming-selection',['Tests/UpcomingSelectionTests.m','RWDiscoveryEpisodes.m','RWUpcomingSelection.m','RWUpcomingPolicy.m','RWDiscoverySnapshot.m','RWRatingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('home-shelf-allocation',['Tests/HomeShelfAllocationTests.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('kids-audience',['Tests/KidsAudienceTests.m','RWDiscoverySnapshot.m','RWRecommendationPolicy.m','RWHomePreparation.m','RWHomeDelivery.m','RWRatingPolicy.m','RWDiscoveryMetadataPolicy.m'],[],['-I'+str(build)]),
 ('home-rail-prior',['Tests/HomeRailPriorTests.m','RWHomePreparation.m','RWHomeDelivery.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m'],[],['-I',str(build)]),
 ('home-shelf-consolidation',['Tests/HomeShelfConsolidationTests.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('home-position-history',['Tests/HomePositionHistoryTests.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('home-seed-refresh',['Tests/HomeSeedRefreshTests.m','RWHomeFeedCoordinator.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('home-anchor-lifecycle',['Tests/HomeAnchorLifecycleTests.m'],[],[]),
 ('home-feed-enrichment',['Tests/HomeFeedEnrichmentTests.m','RWHomeFeedCoordinator.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('home-categories',['Tests/HomeCategoryTests.m','RWHomeCategoryPolicy.m','RWHomeRailPolicy.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('store-rating-lookup',['Tests/StoreRatingLookupTests.m','RWRatings.m','RWRatingPolicy.m','RWApplePreviewPolicy.m','RWApplePreviewLookup.m','RWTrailerPolicy.m','RWAtomicWriter.m','RWMetadataBudget.m'],[str(root/'Research/catalog-199')],[]),
 ('rating-lookup',['Tests/RatingLookupTests.m','RWRatings.m','RWRatingPolicy.m','RWApplePreviewPolicy.m','RWApplePreviewLookup.m','RWTrailerPolicy.m','RWAtomicWriter.m','RWMetadataBudget.m'],[str(root/'Research/ratings-166'),str(root/'Research/ratings-174'),str(root/'Research/ratings-186')],[]),
 ('publisher-rating',['Tests/PublisherRatingTests.m','RWPublisherRatingPolicy.m','RWRatingPolicy.m','RWApplePreviewPolicy.m','RWApplePreviewLookup.m','RWTrailerPolicy.m','RWMetadataBudget.m'],[str(root/'Research/ratings-166'),str(root/'Research/ratings-174'),str(root/'Research/ratings-186')],[]),
 ('poster-feed-position',['Tests/PosterFeedPositionTests.m'],[],['-framework','CoreGraphics']),
 ('home-continuation-jobs',['Tests/HomeContinuationJobsTests.m','RWHomeRailPolicy.m','RWHomePreparation.m','RWHomeDelivery.m','RWDiscoverySnapshot.m','RWRatingPolicy.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('home-feed-coordinator',['Tests/HomeFeedCoordinatorTests.m','RWHomeFeedCoordinator.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('home-feed-store',['Tests/HomeFeedStoreTests.m','RWHomeFeedStore.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('collection-identity',['Tests/CollectionIdentityTests.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('rating-surface',['Tests/RatingSurfaceTests.m'],[],['-I'+str(build)]),
 ('artwork-binding',['Tests/ArtworkBindingTests.m','RWArtworkPolicy.m'],[],['-I'+str(build)]),
 ('related-context',['Tests/RelatedContextTests.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('entity-photo-cache',['Tests/EntityPhotoCacheTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m'],[],[]),
 ('search-identity',['Tests/SearchIdentityTests.m','RWTVPolicy.m'],[],[]),
 ('catalog-search',['Tests/CatalogSearchTests.m','RWCatalogSearch.m','RWMetadataBudget.m'],[],[]),
 ('list-anchor',['Tests/ListAnchorTests.m','RWListAnchor.m'],[],[]),
 ('notification-route',['Tests/NotificationRouteTests.m','RWReminderPolicy.m','RWTVPolicy.m','RWRatingPolicy.m'],[],[]),
 ('apple-movie-policy',['Tests/AppleMoviePreviewTests.m','RWApplePreviewPolicy.m'],[str(root/'Research/previews-130')],[]),
 ('apple-movie-lookup',['Tests/AppleMovieLookupTests.m','RWTrailers.m','RWTrailerPolicy.m','RWAtomicWriter.m'],[str(root/'Research/previews-132')],[]),
 ('film-preview-identity',['Tests/FilmPreviewIdentityTests.m','RWTrailers.m','RWTrailerPolicy.m','RWAtomicWriter.m'],[str(root/'Research/previews-130')],[]),
 ('torrent-selection',['Tests/TorrentSelectionTests.m'],[],[]),
 ('source-identity',['Tests/SourceIdentityTests.m'],[],[]),
 ('native-buffer-recovery',['Tests/NativeBufferRecoveryTests.cpp'],[],None),
 ('native-seek',['Tests/NativeSeekTests.m'],[],['-framework','CoreMedia']),
 ('paused-subtitle-refresh',['Tests/PausedSubtitleRefreshTests.m'],[],[]),
 ('feed-continuation',['Tests/FeedContinuationTests.m'],[],['-framework','CoreGraphics','-I',str(build)]),
 ('episode-progress',['Tests/EpisodeProgressTests.m','RWTVPolicy.m'],[],[]),
 ('subtitle-download',['Tests/SubtitleDownloadTests.m','RWSubtitleDownload.m'],[],[]),
 ('probe-timing',['Tests/ProbeTimingTests.cpp'],[],None),
 ('probe-focus',['Tests/ProbeFocusTests.cpp'],[],None),
 ('opening-estimate',['Tests/OpeningEstimateTests.cpp'],[],None),
 ('stream-health',['Tests/StreamHealthTests.cpp'],[],None),
 ('media-duration',['Tests/MediaDurationTests.cpp'],[],None),
 ('episode-store',['Tests/EpisodeStoreTests.m','RWEpisodeFetcher.m','RWMetadataBudget.m','RWDiscoveryEpisodes.m','RWTVPolicy.m','RWRatingPolicy.m','RWAtomicWriter.m'],[],[]),
 ('episode-fetcher',['Tests/EpisodeFetcherTests.m','RWEpisodeFetcher.m','RWReminderPolicy.m','RWMetadataBudget.m','RWDiscoveryEpisodes.m','RWTVPolicy.m','RWSourceWork.m'],[],[]),
 ('upcoming-store',['Tests/UpcomingStoreTests.m','RWUpcomingPolicy.m','RWAtomicWriter.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('upcoming',['Tests/UpcomingTests.m','RWUpcomingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWDiscoveryMetadataPolicy.m'],[str(root/'Tests/Fixtures/upcoming-entities.json'),str(root/'Tests/Fixtures/tv-schedule.json')],[]),
 ('person-identity',['Tests/PersonIdentityTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m'],[str(root/'Research/person-86')],[]),
 ('home-content-scheduling',['Tests/HomeContentSchedulingTests.m'],[],[]),
 ('cast-content-scheduling',['Tests/CastContentSchedulingTests.m'],[],[]),
 ('home-validation',['Tests/HomeValidationTests.m','RWHomePreparation.m','RWHomeDelivery.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('home-deferred',['Tests/HomeDeferredTests.m','RWHomeDeferredPreparation.m','RWHomePreparation.m','RWHomeDelivery.m','RWDiscoverySnapshot.m','RWDiscoveryEpisodes.m','RWRatingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('home-deferred-lifecycle',['Tests/HomeDeferredLifecycleTests.m'],[],[]),
 ('navigation-reuse',['Tests/NavigationReuseTests.m'],[],['-framework','CoreGraphics']),
 ('owned-state',['Tests/OwnedStateTests.m','RWAtomicWriter.m','RWAvailabilityCache.m'],[],[]),
 ('recommendation-selection',['Tests/RecommendationSelectionTests.m','Tests/RecommendationSelectionReference72.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('availability-cache',['Tests/AvailabilityCacheTests.m','RWAvailabilityCache.m','RWAtomicWriter.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWTrailerPolicy.m'],[],[]),
 ('home-preparation',['Tests/HomePreparationTests.m','RWHomePreparation.m','RWHomeDelivery.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('source-work',['Tests/SourceWorkTests.m','RWSourceWork.m'],[],[]),
 ('caption-snapshot',['Tests/CaptionSnapshotTests.m','RWSourceWork.m'],[],['-I'+str(build)]),
 ('source-lookup',['Tests/SourceLookupIntegrationTests.m','RWSourceWork.m','RWSourceCache.m','RWRequestCoalescer.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWAvailability.m','RWRatingPolicy.m','RWTVPolicy.m'],[],[]),
 ('source-analysis',['Tests/SourceAnalysisTests.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWAvailability.m'],[str(root/'Research/providers'/n) for n in ['current-spiderman-streams.json','older-film-streams.json','series-episode-streams.json']],[]),
 ('poster-artwork',['Tests/PosterArtworkTests.m'],[],[]),
 ('state-save-scheduler',['Tests/StateSaveSchedulerTests.m','RWStateSaveScheduler.m'],[],[]),
 ('state-writer',['Tests/StateWriterTests.m','RWAtomicWriter.m'],[],[]),
 ('recovery-fixture',['Tests/RecoveryFixtureTests.m','RWDeviceExercise.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('device-exercise',['Tests/DeviceExerciseTests.m','RWDeviceExercise.m'],[],[]),
 ('poster-content',['Tests/PosterContentTests.m','RWHomePresentation.m','RWArtworkPolicy.m'],[],['-framework','CoreGraphics']),
 ('poster-binding',['Tests/PosterBindingTests.m','RWHomePresentation.m'],[],['-framework','CoreGraphics']),
 ('home-residency',['Tests/HomeResidencyTests.m','RWDiscoveryMetadataPolicy.m'],[],['-framework','CoreGraphics']),
 ('preview-decoder',['Tests/PreviewDecoderTests.mm','RWPreviewDecoder.mm','RWPreviewTrace.mm'],[],['-std=c++14','-lc++','-I'+str(root/'Tests/PreviewDecoderHarness')]),
 ('apple-preview-policy',['Tests/ApplePreviewPolicyTests.m','RWApplePreviewPolicy.m'],[str(root/'Research/previews-54')],[]),
 ('apple-preview-lookup',['Tests/ApplePreviewLookupTests.m','RWTrailers.m','RWTrailerPolicy.m','RWAtomicWriter.m','RWApplePreviewLookup.m','RWApplePreviewPolicy.m','RWMetadataBudget.m'],[str(root/'Research/previews-54')],[]),
 ('discovery-candidate-jobs',['Tests/DiscoveryCandidateJobsTests.m','RWDiscoveryCandidatePolicy.m','RWRecommendationSignals.m'],[],[]),
 ('discovery-candidates',['Tests/DiscoveryCandidateTests.m','RWDiscoveryCandidatePolicy.m','RWDiscoveryMetadataPolicy.m'],[str(root/'Research/candidates-53')],[]),
 ('discovery-jobs',['Tests/DiscoveryJobsTests.m','RWDiscoverySnapshot.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWDiscoveryEpisodes.m','RWTVPolicy.m','RWRatingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('discovery-preparation',['Tests/DiscoveryPreparationTests.m','RWDiscoverySnapshot.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWDiscoveryEpisodes.m','RWTVPolicy.m','RWRatingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('recommendation-interests',['Tests/RecommendationInterestsTests.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWDiscoveryCatalog.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWViewingSignals.m'],[],[]),
 ('entity-credit-policy',['Tests/EntityCreditPolicyTests.m','RWDiscoveryMetadataPolicy.m'],[str(root/'Research/company-50')],[]),
 ('credit-role-transport',['Tests/CreditRoleTransportTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m'],[],[]),
 ('feed-archive',['Tests/FeedArchiveTests.m','RWFeedArchive.m'],[],['-lz']),
 ('feed-residency',['Tests/FeedResidencyTests.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('entity-search-feed',['Tests/EntitySearchFeedTests.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('entity-search',['Tests/EntitySearchTests.m','RWEntitySearchPolicy.m','RWDiscoveryMetadataPolicy.m'],[str(root/'Research/entity-search-48')],[]),
 ('entity-search-transport',['Tests/EntitySearchTransportTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m'],[],[]),
 ('entity-details',['Tests/EntityDetailsTests.m','RWEntityDetailsPolicy.m','RWDiscoveryMetadataPolicy.m'],[str(root/'Research/entities-47')],[]),
 ('entity-metadata',['Tests/EntityMetadataTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m'],[],[]),
 ('home-presentation',['Tests/HomePresentationTests.m','RWHomePresentation.m'],[],[]),
 ('detail-presentation',['Tests/DetailPresentationTests.m','RWDetailPresentation.m','RWPreviewSession.m'],[],['-framework','CoreGraphics']),
 ('trailer-lookup',['Tests/TrailerLookupTests.m','RWTrailers.m','RWTrailerPolicy.m','RWAtomicWriter.m'],[],[]),
 ('artwork-loader',['Tests/ArtworkLoaderTests.m','RWArtworkLoader.m','RWArtworkDecode.m','RWArtworkPolicy.m'],[str(root/'Research/experience-next')],['-framework','ImageIO','-framework','CoreGraphics']),
 ('download-inventory',['Tests/DownloadInventoryTests.m','RWDownloadInventory.m','RWOfflineMedia.m','RWDiscoverySnapshot.m','RWDiscoveryEpisodes.m','RWTVPolicy.m','RWRatingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('explore-index',['Tests/ExploreIndexTests.m','RWExploreIndex.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('interaction-metrics',['Tests/InteractionMetricsTests.m','RWInteractionMetrics.m'],[],[]),
 ('feed-store',['Tests/FeedStoreTests.m','RWFeedStore.m'],[],['-lsqlite3']),
 ('discovery-snapshot',['Tests/DiscoverySnapshotTests.m','RWDiscoverySnapshot.m','RWDiscoveryEpisodes.m','RWTVPolicy.m','RWRatingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('local-catalog',['Tests/LocalCatalogTests.m','RWLocalCatalog.m'],[],[]),
 ('home-lifecycle',['Tests/HomeLifecycleTests.m','RWSourceWork.m','RWHomeDelivery.m','RWDiscoveryMetadataPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWSourceCache.m','RWRequestCoalescer.m'],[],[]),
 ('home-recommendation-recovery',['Tests/HomeRecommendationRecoveryTests.m','RWHomeDelivery.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('home-delivery',['Tests/HomeDeliveryTests.m','RWHomeDelivery.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('metadata-budget',['Tests/MetadataBudgetTests.m','RWMetadataBudget.m'],[],[]),
 ('metadata-transport',['Tests/MetadataTransportTests.m','RWMetadataBudget.m'],[],[]),
 ('episode-catalog',['Tests/EpisodeCatalogTests.m','RWEpisodeCatalog.m','RWHomeDeferredPreparation.m','RWHomePreparation.m','RWHomeDelivery.m','RWDiscoverySnapshot.m','RWRatingPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m'],[],[]),
 ('discovery-episodes',['Tests/DiscoveryEpisodesTests.m','RWDiscoveryEpisodes.m','RWTVPolicy.m'],[],[]),
 ('discovery-catalog',['Tests/DiscoveryCatalogTests.m','RWDiscoveryCatalog.m'],[],[]),
 ('discovery-metadata',['Tests/DiscoveryMetadataTests.m','RWDiscoveryMetadata.m','RWDiscoveryMetadataPolicy.m','RWAtomicWriter.m','RWCast.m'],[],[]),
 ('offline-media',['Tests/OfflineMediaTests.m','RWOfflineMedia.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[],[]),
 ('imdb-index',['Tests/IMDbIndexTests.m','RWIMDbIndex.m'],[],['-lsqlite3','-lz']),
 ('imdb-update',['Tests/IMDbUpdateTests.m','RWIMDbIndex.m'],[str(root/'Research/discovery-34/title.ratings.tsv.gz'),str(root/'Resources/Rewind/imdb-ratings.sqlite')],['-lsqlite3','-lz']),
 ('discovery-recommendations',['Tests/DiscoveryRecommendationTests.m','RWRecommendationPolicy.m','RWDiscoveryMetadataPolicy.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWViewingSignals.m','RWProfiles.m'],[str(root/'Research/discovery-34')],['-framework','Security']),
 ('viewing-signals',['Tests/ViewingSignalsTests.m','RWViewingSignals.m'],[],[]),
 ('availability',['Tests/AvailabilityTests.m','RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWProfiles.m'],[],['-framework','Security']),
 ('remote-mkv',['Tests/RemoteMKVTests.m','RWRemoteMKVProbe.m','RWMKVProbe.m'],[str(root/'Resources/Rewind/playback-test.mkv')],['-framework','CoreMedia']),
 ('source-experience',['Tests/SourceExperienceTests.m','RWSourceExperience.m'],[],[]),
 ('playback-window',['Tests/PlaybackWindowTests.cpp'],[],None),
 ('source-hints',['Tests/SourceHintsTests.m'],[],[]),
 ('preparation-policy',['Tests/PreparationPolicyTests.cpp'],[],None),
 ('preparation-lifecycle',['Tests/PreparationLifecycleTests.m','RWPlaybackPreparation.m'],[],['-Wno-incomplete-implementation']),
 ('source-cache',['Tests/SourceCacheTests.m','RWSourceCache.m'],[],[]),
 ('public-cast',['Tests/PublicCastTests.m','RWCast.m','RWAtomicWriter.m'],[str(root/'Research/experience/details-29/social-reckoning-cast.html')],[]),
 ('artwork-policy',['Tests/ArtworkPolicyTests.m','RWArtworkPolicy.m'],[],[]),
 ('cast-recovery',['Tests/CastRecoveryTests.m','RWCast.m','RWAtomicWriter.m'],[str(root/'Research/experience/details-26')],[]),
 ('viewport',['Tests/ViewportTests.m','RWViewport.m'],[],[]),
 ('cast',['Tests/CastTests.m','RWCast.m','RWAtomicWriter.m'],[str(root/'Research/experience/details-26')],[]),
 ('atomic-writer',['Tests/AtomicWriterTests.m','RWAtomicWriter.m'],[],[]),
 ('request-coalescer',['Tests/RequestCoalescerTests.m','RWRequestCoalescer.m'],[],[]),
 ('playback-metrics',['Tests/PlaybackMetricsTests.m','RWPlaybackMetrics.m'],[],[]),
 ('discovery-policy',['Tests/DiscoveryPolicyTests.cpp'],[],None),
 ('catalog-mkv',['Tests/CatalogAndMKVTests.m','RWCatalogPolicy.m','RWMKVProbe.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[str(root/'Resources/Rewind/playback-test.mkv'),str(root/'Resources/Rewind/surround-check.mkv')],['-framework','CoreMedia']),
 ('source-policy',['Tests/SourcePolicyTests.m','RWSourcePolicy.m','RWTrackerPolicy.m'],[str(root/'Research/providers'/n) for n in ['current-spiderman-streams.json','older-film-streams.json','series-episode-streams.json']],[]),
 ('player-state',['Tests/PlayerStateTests.cpp'],[],None),
 ('library-subtitle',['Tests/LibraryAndSubtitlesTests.m','RWLibraryPolicy.m','RWSubtitles.m','RWMediaCache.m'],[],[]),
 ('profile-rating',['Tests/ProfilesAndRatingsTests.m','RWProfiles.m','RWRatingPolicy.m'],[str(root/'Resources/Rewind/rating-entities.json')],['-framework','Security']),
 ('skip-policy',['Tests/SkipPolicyTests.m','RWSkipPolicy.m'],[],[]),
 ('trailer-tv',['Tests/TrailerAndTVTests.m','RWTVPolicy.m','RWTrailerPolicy.m'],[str(root/'Research/experience')],[])]
if len(sys.argv)>1:suites=[s for s in suites if s[0] in sys.argv[1:]]
summary={'checks':0,'failures':0,'suites':{}}
for name,sources,args,extra in suites:
 if "RWHomeFeedStore.m" in sources and "RWHomeCategoryPolicy.m" not in sources:sources.append("RWHomeCategoryPolicy.m")
 if name=='visible-metadata-json':
  actual=(root/'RewindStore.m').read_text();start=actual.index('- (void)JSON:(NSString *)url done:');end=actual.index('- (void)browse:(NSString *)type sort:',start)
  (build/'VisibleMetadataJSONUnderTest.inc').write_text(actual[start:end])
 if name=='feed-continuation':
  actual=(root/'RWPosterCollection.m').read_text();start=actual.index('- (void)scrollViewWillBeginDragging:');end=actual.index('- (void)scrollViewDidEndDragging:',start)
  (build/'PosterScrollUnderTest.inc').write_text(actual[start:end])
 if name=='home-rail-prior':
  actual=(root/'RewindHomeContinuation.inc').read_text();start=actual.index('- (BOOL)homeRailRecordAllowed:');end=actual.index('// Initial shelf membership',start)
  (build/'HomeRailPriorUnderTest.inc').write_text(actual[start:end])
 if name=='caption-snapshot':
  import re
  expression=re.search(r'@"real_captions":(.*?),@"subtitle_refresh_active"',(root/'RewindPlayer.m').read_text()).group(1)
  (build/'CaptionSnapshotUnderTest.inc').write_text('return @{@"real_captions":'+expression+'};\n')
 if name=='subtitle-cadence':
  actual=(root/'RewindSubtitles.inc').read_text();start=actual.index('- (BOOL)shouldRefreshExternalSubtitles');end=actual.index('- (void)subtitleSettings',start)
  (build/'subtitle-cadence-under-test.inc').write_text(actual[start:end])
 if name=='kids-audience':
  actual=(root/'RewindStore.m').read_text();start=actual.index('- (BOOL)allowed:(NSDictionary *)meta {');end=actual.index('- (NSArray *)allowedItems:',start)
  (build/'KidsAdmissionUnderTest.inc').write_text(actual[start:end])
 if name=='rating-surface':
  actual=(root/'RewindPreview.inc').read_text();start=actual.index('- (void)ratingsChanged {');end=actual.index('- (void)feedbackMenu',start)
  (build/'RatingSurfaceUnderTest.inc').write_text(actual[start:end])
 if name=='artwork-binding':
  actual=(root/'RewindStore.m').read_text();start=actual.index('- (void)artwork:(NSArray *)urls role:');end=actual.index('    CGFloat scale=',start)
  (build/'ArtworkBindingUnderTest.inc').write_text(actual[start:end]+'}\n')
 if 'RWMKVProbe.m' in sources:sources=sources+['RWAudioPolicy.m']
 if 'RWHomeDelivery.m' in sources:sources=sources+['RWAvailability.m','RWSourcePolicy.m','RWTrackerPolicy.m','RWDiscoveryEpisodes.m','RWTVPolicy.m']
 if 'RWDiscoverySnapshot.m' in sources and 'RWDiscoveryCatalog.m' not in sources:sources=sources+['RWDiscoveryCatalog.m']
 if any(p in sources for p in ['RWRecommendationPolicy.m','RWDiscoverySnapshot.m']):sources=sources+['RWRecommendationSignals.m','RWHomeCategoryPolicy.m']
 if 'RWRecommendationSignals.m' in sources and 'RWViewingSignals.m' not in sources:sources=sources+['RWViewingSignals.m']
 if 'RWFeedStore.m' in sources:sources=sources+['RWFeedArchive.m'];extra=extra+['-lz']
 if 'RWReminderPolicy.m' in sources:sources=sources+['RWTVPolicy.m','RWRatingPolicy.m']
 if 'Tests/EpisodeStoreTests.m' in sources:sources=sources+['RWReminderPolicy.m']
 if 'RWTrailers.m' in sources:sources=sources+['RWApplePreviewLookup.m','RWApplePreviewPolicy.m']
 if 'RWApplePreviewLookup.m' in sources:sources=sources+['RWPublisherRatingPolicy.m','RWRatingPolicy.m']
 if 'RWHomeRailPolicy.m' in sources:sources=sources+['RWRatingPolicy.m']
 if 'RWDiscoveryMetadata.m' in sources:sources=sources+['RWEntityDetailsPolicy.m','RWEntitySearchPolicy.m']
 if 'RWDiscoverySnapshot.m' in sources and 'RWDiscoveryMetadataPolicy.m' not in sources:sources=sources+['RWDiscoveryMetadataPolicy.m']
 if any(p in sources for p in ['RWDiscoveryMetadataPolicy.m','RWEntityDetailsPolicy.m','RWExploreIndex.m']):sources=sources+['RWEntityCreditPolicy.m']
 if any(p in sources for p in ['RWCast.m','RWDiscoveryMetadata.m','RWIMDbIndex.m','RWTrailers.m','RWRatings.m']):sources=sources+['RWMetadataBudget.m']
 if 'RWLocalCatalog.m' in sources or 'Tests/EpisodeStoreTests.m' in sources:sources=sources+['RWEpisodeCatalog.m']
 if 'RWEpisodeCatalog.m' in sources:sources=sources+['RWDiscoveryEpisodes.m']
 if 'RWDiscoveryEpisodes.m' in sources:sources=sources+['RWSourceWork.m','RWTVPolicy.m','RWPackedEpisodes.m']
 sources=list(dict.fromkeys(sources))
 output=build/(name+'-tests');compiler=base+extra if extra is not None else ['/usr/bin/clang++','-std=c++14']
 compiled=subprocess.run(compiler+[str(root/p) for p in sources]+['-o',str(output)],timeout=30,capture_output=True,text=True)
 if compiled.returncode:print(compiled.stderr);compiled.check_returncode()
 run=subprocess.run([str(output)]+args,text=True,capture_output=True,timeout=60 if name=='imdb-update' else 42 if name=='credit-role-transport' else 20)
 (diag/(name+'-tests-'+version+'.json')).write_text(run.stdout)
 if run.stderr:print(run.stderr)
 result=json.loads(run.stdout);summary['suites'][name]=result;summary['checks']+=result['checks'];summary['failures']+=result['failures']
 if run.returncode and not result['failures']:raise RuntimeError(name+' exited without a reported test failure')
bridge=subprocess.run(['node','--expose-internals',str(root/'Tests/TrailerBridgeTests.js'),str(root/'Resources/Rewind/trailer-bridge.js')],capture_output=True,text=True,timeout=10)
if bridge.returncode:print(bridge.stderr);bridge.check_returncode()
result=json.loads(bridge.stdout);summary['suites']['trailer-bridge']=result;summary['checks']+=result['checks'];summary['failures']+=result['failures']
(diag/('trailer-bridge-tests-'+version+'.json')).write_text(bridge.stdout)
(diag/('checks-'+version+('-focused' if len(sys.argv)>1 else '')+'.json')).write_text(json.dumps(summary,indent=2));print(json.dumps({'checks':summary['checks'],'failures':summary['failures']}))

if summary['failures']:raise SystemExit(1)
