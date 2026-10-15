## Fix macOS binaries requiring LibreSSL to be installed on the host

Pre-built macOS binaries were dynamically linked against LibreSSL from Homebrew. Running them on a machine without LibreSSL installed crashed at startup with "Library not loaded: libssl.60.dylib". The macOS binaries now statically link LibreSSL and run without any separate installation.
