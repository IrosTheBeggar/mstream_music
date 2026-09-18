# windows/iroh — prebuilt iroh tunnel library

`iroh_tunnel.dll` is the Windows build of the `rust/iroh_tunnel` crate (the
remote-access QUIC tunnel client). It is committed here as a prebuilt artifact,
mirroring the Android `android/app/src/main/jniLibs/<abi>/libiroh_tunnel.so`
convention — the C ABI (`rust/iroh_tunnel/src/c_api.rs`) is identical across
platforms, so the same Dart FFI wrapper (`lib/native/iroh_tunnel.dart`) loads it.

`windows/CMakeLists.txt` installs the DLL next to `mstream_music.exe`, where
`DynamicLibrary.open("iroh_tunnel.dll")` finds it. The install is `OPTIONAL`, so
a checkout without the DLL still builds — `IrohTunnel.isSupported` just reports
false and iroh degrades to unavailable.

## Rebuilding

```sh
cd rust/iroh_tunnel
cargo build --release            # → target/release/iroh_tunnel.dll
cp target/release/iroh_tunnel.dll ../../windows/iroh/iroh_tunnel.dll
```

The crate is already cross-platform: its Android-only deps (`jni`,
`ndk-context`) and `android_init` module are `cfg(target_os = "android")`-gated,
so a host `cargo build` on Windows produces a working `cdylib` with no changes.
The `[profile.release]` in `Cargo.toml` is size-optimized (`opt-level = "z"`,
thin LTO, stripped) — keep release builds for the committed artifact.
