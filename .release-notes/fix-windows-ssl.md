## Fix SSL handshake failure on Windows

SSL connections failed on Windows because no root CA certificates were loaded. The binary now loads root certificates from the Windows certificate store, so HTTPS connections work on Windows without any extra configuration.
