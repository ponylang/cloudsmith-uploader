## Fix TLS certificate verification failing on some Linux distributions

TLS connections failed with "SSL handshake failed" on Linux distributions where CA certificates are installed at a non-default path. Certificate verification now works across Alpine, Debian/Ubuntu, RHEL/Fedora, and SUSE.

