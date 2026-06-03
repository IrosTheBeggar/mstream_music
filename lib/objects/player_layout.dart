/// Which "Now Playing" layout the expanded player uses, ordered by player
/// footprint (and inversely, how much room the queue gets):
///
///  * [small]  — slim pill + inline controls, queue dominates (design "Slim")
///  * [medium] — art-left banner + slim seek bar (design "Banner", the default)
///  * [large]  — centered medium art + waveform (design "Compact")
///  * [xl]     — full hero album art + waveform (design "Current")
///
/// Persisted by `.name` in settings.json.
enum PlayerLayout { small, medium, large, xl }
