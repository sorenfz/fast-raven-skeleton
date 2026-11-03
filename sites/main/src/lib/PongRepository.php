<?php

namespace Site;

/**
 * Site-level shared logic lives in src/lib/ under the Site\ namespace (autoloaded by the framework).
 * Keep endpoints thin: move queries and business rules here so several endpoints can reuse them.
 */
final class PongRepository {
    public static function answer(?string $question): ?string {
        return $question === "What time is it?" ? date("H:i:s") : null;
    }
}
