import SwiftUI
import WidgetKit

/// The home-screen widget: what the app last published, in four sizes.
///
/// Small: the cover with play/pause. Medium: cover, title and artist, the
/// three transport buttons. Large: the album line, a live progress bar with
/// times, shuffle and repeat beside the transport. Lock screen (rectangular):
/// cover, title, artist. The buttons work from iOS 17 (App Intents run in the
/// app's process); on iOS 16 the widget is a picture of the state, and a tap
/// anywhere opens the app through its URL scheme.
@main
struct NowPlayingWidgetBundle: WidgetBundle {
  var body: some Widget {
    NowPlayingWidget()
  }
}

struct NowPlayingEntry: TimelineEntry {
  let date: Date
  let snapshot: NowPlayingSnapshot
}

struct NowPlayingProvider: TimelineProvider {
  func placeholder(in context: Context) -> NowPlayingEntry {
    var s = NowPlayingSnapshot()
    s.hasTrack = true
    s.title = "mStream"
    s.artist = "Now Playing"
    return NowPlayingEntry(date: Date(), snapshot: s)
  }

  func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
    completion(NowPlayingEntry(date: Date(), snapshot: context.isPreview ? placeholder(in: context).snapshot : NowPlayingSnapshot.load()))
  }

  /// One entry, no refresh policy: the app reloads the timeline on every
  /// change it publishes, and the progress bar runs on its own.
  func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
    completion(Timeline(entries: [NowPlayingEntry(date: Date(), snapshot: NowPlayingSnapshot.load())], policy: .never))
  }
}

struct NowPlayingWidget: Widget {
  static let kind = "NowPlayingWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: NowPlayingWidget.kind, provider: NowPlayingProvider()) { entry in
      NowPlayingView(snapshot: entry.snapshot)
        .widgetURL(URL(string: "mstream://nowplaying"))
    }
    .configurationDisplayName("Now Playing")
    .description("Album art and controls for the track playing in mStream.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    .widgetBackground()
  }
}

extension WidgetConfiguration {
  /// iOS 17 draws the widget's background itself and asks for the content to
  /// opt in; the views below add it per platform.
  func widgetBackground() -> some WidgetConfiguration {
    if #available(iOS 17.0, *) {
      return self.contentMarginsDisabled()
    }
    return self
  }
}

// MARK: - Views

struct NowPlayingView: View {
  @Environment(\.widgetFamily) private var family
  let snapshot: NowPlayingSnapshot

  var body: some View {
    Group {
      switch family {
      case .accessoryRectangular:
        LockScreenRow(snapshot: snapshot)
      case .systemSmall:
        SmallCard(snapshot: snapshot)
      case .systemLarge:
        LargeCard(snapshot: snapshot)
      default:
        MediumCard(snapshot: snapshot)
      }
    }
    .modifier(CardBackground(family: family))
  }
}

/// The card fill, done the iOS 17 way (containerBackground) with the iOS 16
/// fallback; the lock screen draws its own.
struct CardBackground: ViewModifier {
  let family: WidgetFamily

  func body(content: Content) -> some View {
    if family == .accessoryRectangular {
      content
    } else if #available(iOS 17.0, *) {
      content
        .padding(family == .systemSmall ? 12 : 14)
        .containerBackground(for: .widget) { Color(.secondarySystemBackground) }
    } else {
      content
        .padding(family == .systemSmall ? 12 : 14)
        .background(Color(.secondarySystemBackground))
    }
  }
}

struct Cover: View {
  let snapshot: NowPlayingSnapshot
  var corner: CGFloat = 10

  var body: some View {
    GeometryReader { geo in
      ZStack {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
          .fill(Color.accentColor.opacity(0.18))
        if let image = snapshot.art {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        } else {
          Image(systemName: "music.note")
            .font(.system(size: min(geo.size.width, geo.size.height) * 0.4, weight: .medium))
            .foregroundStyle(Color.accentColor.opacity(0.7))
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

struct TitleLines: View {
  let snapshot: NowPlayingSnapshot
  var titleFont: Font = .headline
  var subtitleFont: Font = .subheadline
  var showAlbum = false

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if snapshot.hasTrack {
        Text(snapshot.title).font(titleFont).lineLimit(1)
        if !snapshot.subtitle.isEmpty {
          Text(snapshot.subtitle).font(subtitleFont).foregroundStyle(.secondary).lineLimit(1)
        }
        if showAlbum, !snapshot.artist.isEmpty, !snapshot.album.isEmpty {
          Text(snapshot.album).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
        }
      } else {
        Text("Nothing playing").font(titleFont).lineLimit(1)
        Text("Tap to open mStream").font(subtitleFont).foregroundStyle(.secondary).lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A transport button: an App Intent on iOS 17+, a glyph before that (the
/// whole widget then opens the app).
struct TransportButton: View {
  enum Kind { case playPause, next, previous, shuffle, repeatMode }
  let kind: Kind
  let snapshot: NowPlayingSnapshot
  var size: CGFloat = 22
  var filled = false

  private var symbol: String {
    switch kind {
    case .playPause: return snapshot.playing ? "pause.fill" : "play.fill"
    case .next: return "forward.end.fill"
    case .previous: return "backward.end.fill"
    case .shuffle: return "shuffle"
    case .repeatMode: return snapshot.repeatMode == "one" ? "repeat.1" : "repeat"
    }
  }

  private var dimmed: Bool {
    switch kind {
    case .shuffle: return !snapshot.shuffle
    case .repeatMode: return snapshot.repeatMode == "none"
    default: return false
    }
  }

  private var label: some View {
    Image(systemName: symbol)
      .font(.system(size: size, weight: .semibold))
      .foregroundStyle(filled ? Color(.secondarySystemBackground) : (dimmed ? Color.secondary : Color.accentColor))
      .frame(width: size * 2, height: size * 2)
      .background(filled ? Color.accentColor : Color.clear, in: Circle())
      .contentShape(Rectangle())
  }

  var body: some View {
    if #available(iOS 17.0, *) {
      switch kind {
      case .playPause:
        if snapshot.playing {
          Button(intent: NowPlayingPauseIntent()) { label }.buttonStyle(.plain)
        } else {
          Button(intent: NowPlayingPlayIntent()) { label }.buttonStyle(.plain)
        }
      case .next: Button(intent: NowPlayingNextIntent()) { label }.buttonStyle(.plain)
      case .previous: Button(intent: NowPlayingPreviousIntent()) { label }.buttonStyle(.plain)
      case .shuffle: Button(intent: NowPlayingShuffleIntent()) { label }.buttonStyle(.plain)
      case .repeatMode: Button(intent: NowPlayingRepeatIntent()) { label }.buttonStyle(.plain)
      }
    } else {
      label
    }
  }
}

struct ProgressLine: View {
  let snapshot: NowPlayingSnapshot

  var body: some View {
    VStack(spacing: 3) {
      if snapshot.playing, let interval = snapshot.progressInterval {
        // Runs on its own between publishes; the app only sends a new fix on a jump.
        ProgressView(timerInterval: interval, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
          .tint(Color.accentColor)
      } else {
        ProgressView(value: Double(snapshot.position()), total: Double(max(snapshot.durationMs, 1)))
          .tint(Color.accentColor)
      }
      HStack {
        Text(NowPlayingSnapshot.formatTime(snapshot.position())).monospacedDigit()
        Spacer()
        Text(NowPlayingSnapshot.formatTime(snapshot.durationMs)).monospacedDigit()
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
    }
  }
}

struct SmallCard: View {
  let snapshot: NowPlayingSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ZStack(alignment: .bottomTrailing) {
        Cover(snapshot: snapshot, corner: 12)
        if snapshot.hasTrack {
          TransportButton(kind: .playPause, snapshot: snapshot, size: 16, filled: true).padding(6)
        }
      }
      TitleLines(snapshot: snapshot, titleFont: .subheadline.weight(.semibold), subtitleFont: .caption)
    }
  }
}

struct MediumCard: View {
  let snapshot: NowPlayingSnapshot

  var body: some View {
    HStack(spacing: 14) {
      Cover(snapshot: snapshot, corner: 12)
      VStack(alignment: .leading, spacing: 8) {
        TitleLines(snapshot: snapshot)
        if snapshot.hasTrack {
          HStack(spacing: 4) {
            TransportButton(kind: .previous, snapshot: snapshot, size: 18)
            TransportButton(kind: .playPause, snapshot: snapshot, size: 20, filled: true)
            TransportButton(kind: .next, snapshot: snapshot, size: 18)
          }
        }
      }
    }
  }
}

struct LargeCard: View {
  let snapshot: NowPlayingSnapshot

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 14) {
        Cover(snapshot: snapshot, corner: 14).frame(maxHeight: 130)
        TitleLines(snapshot: snapshot, titleFont: .title3.weight(.semibold), showAlbum: true)
      }
      if snapshot.hasTrack {
        if snapshot.durationMs > 0 { ProgressLine(snapshot: snapshot) }
        HStack {
          TransportButton(kind: .shuffle, snapshot: snapshot, size: 18)
          Spacer()
          TransportButton(kind: .previous, snapshot: snapshot, size: 22)
          Spacer()
          TransportButton(kind: .playPause, snapshot: snapshot, size: 24, filled: true)
          Spacer()
          TransportButton(kind: .next, snapshot: snapshot, size: 22)
          Spacer()
          TransportButton(kind: .repeatMode, snapshot: snapshot, size: 18)
        }
      } else {
        Spacer()
      }
    }
  }
}

struct LockScreenRow: View {
  let snapshot: NowPlayingSnapshot

  var body: some View {
    HStack(spacing: 8) {
      if let image = snapshot.art {
        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
          .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
      } else {
        Image(systemName: snapshot.playing ? "play.fill" : "music.note").font(.title3)
      }
      VStack(alignment: .leading) {
        Text(snapshot.hasTrack ? snapshot.title : "Nothing playing").font(.headline).lineLimit(1)
        Text(snapshot.hasTrack ? snapshot.subtitle : "mStream").font(.caption).lineLimit(1)
      }
    }
  }
}
