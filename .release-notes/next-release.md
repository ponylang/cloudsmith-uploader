## Fix SSL handshake failure on Windows

SSL connections failed on Windows because no root CA certificates were loaded. The binary now loads root certificates from the Windows certificate store, so HTTPS connections work on Windows without any extra configuration.

## Fix macOS binaries requiring LibreSSL to be installed on the host

Pre-built macOS binaries were dynamically linked against LibreSSL from Homebrew. Running them on a machine without LibreSSL installed crashed at startup with "Library not loaded: libssl.60.dylib". The macOS binaries now statically link LibreSSL and run without any separate installation.

