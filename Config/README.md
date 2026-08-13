# OpenRouter configuration

Set `OPENROUTER_API_KEY` in the Xcode scheme used to run Eon:

1. Select the `Eon-Y` scheme.
2. Open **Edit Scheme… → Run → Arguments → Environment Variables**.
3. Add `OPENROUTER_API_KEY` and paste the key there.
4. Add `OPENROUTER_MODEL` with `~deepseek/deepseek-v4-flash-latest` if you want to pin the model explicitly.

The key is read at runtime and is not stored in the repository. Requests are capped at 1,000 characters in and out. If the key is absent or the request fails, Eon uses its deterministic Swedish fallback and continues operating.
