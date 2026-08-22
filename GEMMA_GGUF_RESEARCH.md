# Gemma GGUF verification — 2026-08-22

## Findings

The requested Hugging Face URL for `google/gemma-2-2b-it-GGUF/gemma-2-2b-it-Q8_0.gguf` returns HTTP 401 with `x-error-code: GatedRepo`. The repository requires accepting Google's Gemma terms and authenticating to Hugging Face before the file can be downloaded.

The current machine has approximately 2.1 GB free on a 48 GB filesystem. Downloading a 2.6–2.8 GB Q8_0 file is therefore unsafe and cannot complete with the current disk headroom. The model must not be downloaded partially into the repository.

The `flutter_gemma` 1.2.0 documentation states that its supported model formats are `.task`, `.litertlm`, `.bin`, and `.tflite`. GGUF is not listed as a supported model file type in that release. Therefore `flutter_gemma: ^1.2.0` cannot be treated as a verified GGUF runtime for the requested file without an additional compatible backend or an explicit upstream example.

The existing project resolves `flutter_gemma` 0.3.1 and already has a local parser fallback. The correct safe implementation is to keep the Gemma adapter optional, use the parser when the GGUF runtime/model is unavailable, and document that the user must accept the license and place the verified model locally. No fake or truncated `.gguf` file should be created.

## Sources

- https://pub.dev/packages/flutter_gemma/versions/1.2.0 — flutter_gemma 1.2.0 documentation and supported model formats.
- https://pub.dev/packages/flutter_gemma/versions/1.2.0/changelog — 1.2.0 changelog and SDK history.
- https://huggingface.co/google/gemma-2-2b-it-GGUF — official Gemma GGUF model card, gated access and terms.
- https://huggingface.co/docs/hub/en/gguf — GGUF format documentation.
