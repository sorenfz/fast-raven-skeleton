<?php

use FastRaven\Components\Core\Config;

// Main Configuration. siteName is not the subdomain.
$config = Config::new("main", false);

// Cookie Session Configuration.
$config->configureAuthorization("YOURSESSIONNAME", 7, false);

// Redirect settings: notFound path, unauthorized path, subdomain. (null == show error page)
$config->configureRedirects("/", "/", "");

// Define whether to register logs or restrict what data to register.
$config->configurePrivacy(true, true);

// Trust X-Forwarded-For / X-Forwarded-Proto from a reverse proxy you control. false = use the direct connection.
$config->configureProxy(false);

// Rate limits per authorized user and endpoint type (VIEW, API, CDN), requests per minute. -1 = disabled.
$config->configureRateLimits(200, 200, 200);

// Configure input/file size limits in KB. -1 = disabled.
$config->configureLengthLimits(256, 5120);

// File-based cache settings. Set gcProbability to 0 to disable framework GC.
$config->configureCache(1, 50);

return $config;