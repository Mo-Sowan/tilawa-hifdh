# Bundled model (optional)

The recitation model is downloaded on first use and cached, so this directory
is normally empty.

To ship a fully self-contained build with no first-run download, place the
model here as:

    fastconformer_full_mixed.onnx

It must match the `onnx_sha256` in `../quran/export_metadata.json`; the app
verifies the checksum before loading it either way.

The file is ~88 MB and is deliberately excluded from version control.
