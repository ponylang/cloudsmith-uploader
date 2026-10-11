"""
Uploads archives to Cloudsmith via the REST API.

Handles the full upload flow: request an upload slot, upload file
chunks, complete the upload, create the package record, and wait
for sync.
"""
