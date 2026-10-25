## Context
The builder reads saved image classifications for cards but only publishes author captions. Gallery and lightbox already render captions.

## Goals / Non-Goals
Deliver saved captions in the gallery according to existing preferences. Inline post enrichment, card selection and gallery filtering remain separate work.

## Decisions
Add nullable aiCaption beside caption. Resolve captions through one site helper: never or mod-page hide excludes AI; always prefers AI; whenMissing prefers author text. Mark generated text as AI description in display and accessible text. Read preferences at display time. Use the existing store lookup for URL normalization. Existing data remains valid.

## Risks / Trade-offs
Incomplete caption coverage → fall back to author text or no caption. Rebuilding site data is required to publish saved captions.

## Migration Plan
Regenerate mappers, test, then use the normal site rebuild and publication. Old clients ignore the optional field; rollback needs no data migration.
