import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/singletons/browser_list.dart';

// Covers the in-flight load tracking that backs the browser's tap-guard and
// Back-to-cancel behavior (the fix for the folder-load race where a second tap
// kicked off a second request and the screen showed whichever finished last).
//
// BrowserManager is a singleton, so the load token / cancelledThrough state is
// shared across the isolate. Tokens and the cancel watermark are monotonic, so
// this runs as ONE ordered test rather than fighting cross-test state.
void main() {
  test('load tokens: tracking, cancellation, and late-endLoad safety', () {
    final bm = BrowserManager();
    expect(bm.isLoading, isFalse);

    // 1. Concurrent loads are tracked independently; isLoading stays true until
    //    the last one ends. Tokens are monotonic.
    final a = bm.beginLoading();
    expect(bm.isLoading, isTrue);
    final b = bm.beginLoading();
    expect(b, greaterThan(a));
    bm.endLoading(a);
    expect(bm.isLoading, isTrue, reason: 'b is still in flight');
    bm.endLoading(b);
    expect(bm.isLoading, isFalse);

    // 2. Cancel fires the registered canceler, clears the loading state, and
    //    marks the in-flight token cancelled (so its late result is dropped).
    var cancelerFired = false;
    final c = bm.beginLoading(onCancel: () => cancelerFired = true);
    expect(bm.isLoadCancelled(c), isFalse);
    expect(bm.cancelLoading(), isTrue);
    expect(cancelerFired, isTrue);
    expect(bm.isLoadCancelled(c), isTrue);
    expect(bm.isLoading, isFalse);

    // 3. A load started AFTER a cancel is NOT considered cancelled, and the
    //    cancelled load's late endLoading() must not zero out the newer one
    //    (the bug a bare counter would have: cancel sets count 0, then the old
    //    finally decrements the new load's count).
    final d = bm.beginLoading();
    expect(bm.isLoadCancelled(d), isFalse);
    expect(bm.isLoading, isTrue);
    bm.endLoading(c); // the cancelled load's late finally
    expect(bm.isLoading, isTrue, reason: 'd must remain in flight');
    bm.endLoading(d);
    expect(bm.isLoading, isFalse);

    // 4. Cancelling with nothing in flight is a no-op (Back then falls through
    //    to normal navigation).
    expect(bm.cancelLoading(), isFalse);

    // 5. cancelable: false path — a load registered WITHOUT a canceler (a
    //    mutation like playlist create/rename/delete) is not aborted by Back:
    //    cancelLoading fires only registered cancelers, so the mutation's
    //    request runs to completion.
    var cancelerFires = 0;
    bm.beginLoading(onCancel: () => cancelerFires++); // cancelable read/nav
    bm.beginLoading(); // non-cancelable mutation — no canceler registered
    expect(bm.cancelLoading(), isTrue);
    expect(cancelerFires, 1, reason: 'only the cancelable load is aborted');
  });
}
