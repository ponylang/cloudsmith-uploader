# cloudsmith-uploader

A tool to upload archives to Cloudsmith, written in [Pony](https://www.ponylang.io/).

## Status

cloudsmith-uploader is an early stage project.

## Installation

cloudsmith-uploader is distributed as a pre-built binary via [GitHub Releases](https://github.com/ponylang/cloudsmith-uploader/releases). Download the archive for your platform and extract the `cloudsmith-uploader` binary.

Nightly builds are available via [GHCR](https://github.com/orgs/ponylang/packages).

### Supported platforms

- x86-64 Linux (glibc and musl)
- arm64 Linux (glibc and musl)
- x86-64 macOS
- arm64 macOS
- x86-64 Windows
- arm64 Windows

## Building from source

You'll need `ponyc`, `corral`, and LibreSSL installed.

On macOS and Windows, static LibreSSL libraries are vendored in `lib/` — no separate installation needed.

On Linux, use a distribution that ships LibreSSL or install it from source.

```bash
git clone https://github.com/ponylang/cloudsmith-uploader
cd cloudsmith-uploader
make
```

To build with OpenSSL instead of LibreSSL:

```bash
make ssl=3.0.x  # OpenSSL 3.x
make ssl=1.1.x  # OpenSSL 1.1.x
```

To run tests:

```bash
make test
```

To install:

```bash
make install
```
