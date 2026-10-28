# Installer payload

The Windows installer embeds this directory (`//go:embed payload` in `main.go`). Two files are already here:

| File | Role |
| --- | --- |
| `manifest.json` | AppLoad manifest. The id stays `rm-comics`. The name shown in AppLoad is FourColour. Same contents as [`app/manifest.json`](../../app/manifest.json). |
| `icon.png` | App icon (128×128). The same file is [`assets/icon.png`](../../assets/icon.png). AppLoad shows it next to the app name. |

Two further files are required before an install can succeed. They are listed in `.gitignore` because they are build products.

| File | Ignored path |
| --- | --- |
| `resources.rcc` | `installer/payload/resources.rcc` |
| `backend/entry` | `installer/payload/backend/` |

Do not put secrets in this directory. The installer compiles everything here into the executable. `go vet` and `go test` also need these four paths to exist, because of `//go:embed payload`. Placeholders are enough to compile; they are not a working app, and they must not be committed.

On install, the program copies `manifest.json`, `resources.rcc`, `icon.png` and `backend/entry` to `/home/root/xovi/exthome/appload/rm-comics/` and runs `backend/entry --selftest` on the tablet. That self-test prints `ok`.

## 1. `resources.rcc` (Qt 6 `rcc --binary`)

Install Qt 6's resource compiler. On Debian or Ubuntu the package is `qt6-base-dev-tools`, and the compiler is often `/usr/lib/qt6/libexec/rcc`. It must report Qt 6. Do not use a Qt 5 `rcc`.

`app/application.qrc` lists `ui/main.qml` as a relative path, so run `rcc` from `app/`:

```sh
cd app
/usr/lib/qt6/libexec/rcc --binary -o ../installer/payload/resources.rcc application.qrc
```

If `rcc` is already on `PATH`, the same command is `rcc --binary -o ../installer/payload/resources.rcc application.qrc`.

`rcc` only packs the QML file. The `import net.asivery.AppLoad 1.0` line is resolved on the tablet, when AppLoad loads the resource.

Leave `installer/payload/icon.png` and `installer/payload/manifest.json` as they are in this repository.

## 2. `backend/entry` (static musl build)

Build the Rust backend in `app/backend` as a static binary for `aarch64-unknown-linux-musl`. The crate is `rmcomics-backend`. AppLoad expects the binary at `backend/entry`.

A musl static build avoids the glibc mismatch that a normal `aarch64-unknown-linux-gnu` cross-compile can hit on the tablet. The release profile in `Cargo.toml` uses `opt-level = "s"`, link-time optimisation, a stripped binary, and `panic = "abort"`.

The `unrar` dependency compiles UnRAR from C++ sources (through `unrar_sys`), so the build needs a C++ compiler. A host `cargo check` uses the system compiler. The tablet command below is `cargo zigbuild`.

Install a current Rust toolchain, [Zig](https://ziglang.org/download/), and [cargo-zigbuild](https://github.com/rust-cross/cargo-zigbuild). From `app/backend`:

```sh
rustup target add aarch64-unknown-linux-musl
cargo install cargo-zigbuild
cargo zigbuild --release --target aarch64-unknown-linux-musl
mkdir -p ../../installer/payload/backend
cp target/aarch64-unknown-linux-musl/release/rmcomics-backend \
   ../../installer/payload/backend/entry
chmod 755 ../../installer/payload/backend/entry
```

`cargo zigbuild --release --target aarch64-unknown-linux-musl` is the release build. Add `--locked` to use `Cargo.lock` as it is in this repository.

Check the result:

```sh
file installer/payload/backend/entry
```

You want an ELF 64-bit ARM aarch64 executable, statically linked against musl, not a dynamically linked glibc binary. `--selftest` prints `ok` when that binary runs on the tablet. It will not run on a PC of another architecture.
