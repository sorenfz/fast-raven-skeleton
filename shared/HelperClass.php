<?php

namespace Shared;

use FastRaven\Services\LogService;

/**
 * You can create custom classes in the shared folder that are available in all sites.
 * For logic belonging to a single site, use its src/lib/ folder (Site\ namespace) instead.
 */
final class HelperClass {
    public static function log(string $message): void {
        LogService::log("[HelloWorld!] $message");
    }
}
