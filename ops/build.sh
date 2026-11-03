#!/bin/bash

# FastRaven Framework - Build Script

# This script automates the build process of a FastRaven site.
#
# Usage: 
#   ./build.sh <site-name>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "$1"
}

print_success() {
    echo -e "${GREEN}OK${NC} $1"
}

print_error() {
    echo -e "${RED}X${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

if [ -z "$1" ]; then
    print_error "Site name argument is required"
    echo "Usage: $0 <site-name>"
    exit 1
fi

SITE_NAME="$1"
SITE_PATH="$PROJECT_ROOT/sites/$SITE_NAME"

if [ -d "$SITE_PATH" ]; then
    print_error "Site folder already exists: $SITE_PATH"
    exit 1
fi

# ----------------------------------------------------------------------------

print_step "Creating new site: $SITE_NAME"

mkdir -p "$SITE_PATH"
mkdir -p "$SITE_PATH/config/env"
mkdir -p "$SITE_PATH/config/router"
mkdir -p "$SITE_PATH/src/api"
mkdir -p "$SITE_PATH/src/cdn"
mkdir -p "$SITE_PATH/src/lib"
mkdir -p "$SITE_PATH/src/views"
mkdir -p "$SITE_PATH/src/web/templates/pages"
mkdir -p "$SITE_PATH/src/web/templates/fragments"
mkdir -p "$SITE_PATH/src/web/templates/mails"
mkdir -p "$SITE_PATH/src/web/assets/scss"
mkdir -p "$SITE_PATH/src/web/assets/js"
mkdir -p "$SITE_PATH/src/web/assets/lang"
mkdir -p "$SITE_PATH/public/assets/css"
mkdir -p "$SITE_PATH/public/assets/js"
mkdir -p "$SITE_PATH/public/assets/fonts"
mkdir -p "$SITE_PATH/public/assets/img"
mkdir -p "$SITE_PATH/storage/cache"
mkdir -p "$SITE_PATH/storage/logs"
mkdir -p "$SITE_PATH/storage/uploads"

touch "$SITE_PATH/public/assets/css/.gitkeep"
touch "$SITE_PATH/public/assets/js/.gitkeep"
touch "$SITE_PATH/public/assets/fonts/.gitkeep"
touch "$SITE_PATH/public/assets/img/.gitkeep"
touch "$SITE_PATH/storage/cache/.gitkeep"
touch "$SITE_PATH/storage/logs/.gitkeep"
touch "$SITE_PATH/storage/uploads/.gitkeep"

cat > "$SITE_PATH/.gitignore" <<'EOF'
/config/env/env.php
/storage/cache/*
/storage/logs/*
/storage/uploads/*
!/storage/*/.gitkeep
EOF

cat > "$SITE_PATH/.htaccess" <<'EOF'
RewriteEngine On
RewriteBase /

Options -Indexes -MultiViews

RewriteRule ^public/ - [L]
RewriteRule ^(favicon\.ico|robots\.txt|sitemap\.xml)$ public/$1 [L]

RewriteRule \.php$ index.php [QSA,L]
RewriteRule ^ index.php [QSA,L]

<Files "index.php">
    Require all granted
</Files>
EOF

cat > "$SITE_PATH/index.php" <<'EOF'
<?php
declare(strict_types=1);
require __DIR__ . "/../../vendor/autoload.php";

use FastRaven\Server;

// Server initialization. sitePath SHOULD ALWAYS BE __DIR__ unless you know what you are doing.
$server = Server::initialize(__DIR__);

// Server configuration.
$server->configure(
    Server::getConfiguration(),
    Server::getTemplate(),
    Server::getMiddleware(),
    Server::getViewRouter(),
    Server::getApiRouter(),
    Server::getCdnRouter()
);

// This is where the magic happens.
$server->run();
EOF

cat > "$SITE_PATH/config/config.php" <<'EOF'
<?php

use FastRaven\Components\Core\Config;

// Main Configuration. siteName is not the subdomain.
$config = Config::new("${SITE_NAME}", false);

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
EOF

sed -i "s/\${SITE_NAME}/$SITE_NAME/g" "$SITE_PATH/config/config.php" 2>/dev/null || \
perl -pi -e "s/\\\${SITE_NAME}/$SITE_NAME/g" "$SITE_PATH/config/config.php"

cat > "$SITE_PATH/config/template.php" <<'EOF'
<?php

use FastRaven\Components\Core\Template;

use FastRaven\Bee;

// Default template for all views. Pages render in the client's preferred language (cookie, then Accept-Language).
$template = Template::new("main.php", "Fast Raven Site", Bee::env("VERSION", "0.0.1"));
$template->setLangFile("global")
         ->setDefaultLang("en")
         ->setFavicon("favicon.png")
         ->addMeta("description", "A site powered by Fast Raven.")
         ->setBeforeFragments(["header.php"])
         ->addStyle("style.css")
         ->addScript("main.js");

return $template;
EOF

cat > "$SITE_PATH/config/middleware.php" <<'EOF'
<?php

use FastRaven\Services\LogService;

use FastRaven\Components\Http\Request;
use FastRaven\Components\Routing\Middleware;

// Create a new middleware holder instance.
$middleware = Middleware::new();

// Add a new available to use middleware.
$middleware->add("alwaysPass", function(Request $request): bool {
    LogService::log("This gets executed BEFORE endpoint execution -- Check config/middleware.php to remove this line.");
    // You can limit it to request types. 
    // if($request->getType() === EndpointType::API)
    // Or use Shared methods for more complex operations.
    // Shared\HelperClass::log("test");

    return true; // Return false to deny request processing
});

return $middleware;
EOF

cat > "$SITE_PATH/config/router/views.php" <<'EOF'
<?php

use FastRaven\Components\Routing\Endpoint;
use FastRaven\Components\Routing\Router;

use FastRaven\Types\EndpointType;

// View Router configuration. Remember to return a template from each view.
$viewRouter = Router::new(EndpointType::VIEW)
    ->add(Endpoint::view(false, "/", "Home.php"))
    ->add(Endpoint::view(false, "/ping", "Ping.php", "alwaysPass"));

return $viewRouter;
EOF

cat > "$SITE_PATH/config/router/api.php" <<'EOF'
<?php

use FastRaven\Components\Routing\Endpoint;
use FastRaven\Components\Routing\Router;

use FastRaven\Types\EndpointType;

// API Router configuration. /api/ prefix is automatically added.
$apiRouter = Router::new(EndpointType::API)
    ->add(Endpoint::api(false, "GET", "/health", "Health.php"))
    ->add(Endpoint::api(false, "POST", "/pong", "Pong.php"));

return $apiRouter;
EOF

cat > "$SITE_PATH/config/router/cdn.php" <<'EOF'
<?php

use FastRaven\Components\Routing\Endpoint;
use FastRaven\Components\Routing\Router;

use FastRaven\Types\EndpointType;

// CDN Router configuration. /cdn/ prefix is automatically added.
$cdnRouter = Router::new(EndpointType::CDN)
    ->add(Endpoint::cdn(false, "GET", "/logo", "Logo.php"));

return $cdnRouter;
EOF

ENV_CONTENT=$(cat <<'EOF'
<?php

use FastRaven\Bee;

Bee::defineEnv("STATE", "dev");
Bee::defineEnv("VERSION", "0.0.1");

// VARIABLES FOR DEVELOPMENT
if(Bee::isDev()) {
    // Globals
    Bee::defineEnv("SITE_ADDRESS", "fastraven.loc");
    Bee::defineEnv("AUTH_DOMAIN", ".fastraven.loc");

    // Database
    Bee::defineEnv("DB_HOST", "localhost");
    Bee::defineEnv("DB_PORT", "3306");
    Bee::defineEnv("DB_NAME", "test");
    Bee::defineEnv("DB_USER", "raven");
    Bee::defineEnv("DB_PASS", "secret");
    Bee::defineEnv("DB_SSL", "false");
    Bee::defineEnv("DB_SSL_CA", "/path/to/ca.pem");
    Bee::defineEnv("DB_PERSISTENT", "true");
    // Named connections: DB_<NAME>_* keys, missing ones inherit from DB_*. Select with DataService::use("logs").
    // Bee::defineEnv("DB_LOGS_NAME", "test_logs");

    // SMTP
    Bee::defineEnv("SMTP_HOST", "smtp.fastraven.loc");
    Bee::defineEnv("SMTP_ENCRYPTION", "tls");
    Bee::defineEnv("SMTP_PORT", "587");
    Bee::defineEnv("SMTP_USER", "raven@fastraven.loc");
    Bee::defineEnv("SMTP_PASS", "secret");

    // SHMOP
    Bee::defineEnv("SHMOP_MAX_SIZE", "1024"); // In KB
}

// VARIABLES FOR PRODUCTION
else {
    // Globals
    Bee::defineEnv("SITE_ADDRESS", "fastraven.loc");
    Bee::defineEnv("AUTH_DOMAIN", ".fastraven.loc");

    // Database
    Bee::defineEnv("DB_HOST", "localhost");
    Bee::defineEnv("DB_PORT", "3306");
    Bee::defineEnv("DB_NAME", "test");
    Bee::defineEnv("DB_USER", "raven");
    Bee::defineEnv("DB_PASS", "secret");
    Bee::defineEnv("DB_SSL", "false");
    Bee::defineEnv("DB_SSL_CA", "/path/to/ca.pem");
    Bee::defineEnv("DB_PERSISTENT", "true");
    // Named connections: DB_<NAME>_* keys, missing ones inherit from DB_*. Select with DataService::use("logs").
    // Bee::defineEnv("DB_LOGS_NAME", "test_logs");

    // SMTP
    Bee::defineEnv("SMTP_HOST", "smtp.fastraven.loc");
    Bee::defineEnv("SMTP_ENCRYPTION", "tls");
    Bee::defineEnv("SMTP_PORT", "587");
    Bee::defineEnv("SMTP_USER", "raven@fastraven.loc");
    Bee::defineEnv("SMTP_PASS", "secret");

    // SHMOP
    Bee::defineEnv("SHMOP_MAX_SIZE", "1024"); // In KB
}
EOF
)

echo "$ENV_CONTENT" > "$SITE_PATH/config/env/env.php"
echo "$ENV_CONTENT" > "$SITE_PATH/config/env/env.php-example"

cat > "$SITE_PATH/src/views/Home.php" <<'EOF'
<?php

use FastRaven\Components\Core\Template;
use FastRaven\Components\Http\Request;

return function(Request $request, Template $baseTemplate): Template {
    $page = Template::new("main.php", $baseTemplate->getTitle());
    return $page;
};
EOF

cat > "$SITE_PATH/src/views/Ping.php" <<'EOF'
<?php

use FastRaven\Components\Core\Template;
use FastRaven\Components\Http\Request;

return function(Request $request, Template $baseTemplate): Template {
    $page = Template::new("ping.php", $baseTemplate->getTitle()." - Ping test");
    $page->addData("test", "This is a test");
    return $page;
};
EOF

cat > "$SITE_PATH/src/web/templates/pages/main.php" <<'EOF'
<h1>Fast Raven is working hard to launch this site...</h1>
EOF

cat > "$SITE_PATH/src/web/templates/pages/ping.php" <<'EOF'
<h2 data-lang="FR_PING_EXAMPLE"><?= $template->lang("FR_PING_EXAMPLE"); ?></h2>
<h4>PING -> <span id="pong-answer"></span></h4>
<p><?= $template->getData("test"); ?></p>
<button onclick="Lib.changeLanguage(Lib.CURRENT_LANGUAGE === 'en' ? 'es' : 'en')">Switch language</button>

<script nonce="<?= $template->getNonce(); ?>">
    // Avoid using inline-scripts, this is just an example.
    // If needed, always use the nonce provided by the template.

    Lib.request("/api/pong", "POST", {"question": "What time is it?"}).then(function(res){
        $("#pong-answer").text(res.data.answer);
    }).catch(function(err){
        $("#pong-answer").text(err.message);
    });
</script>
EOF

cat > "$SITE_PATH/src/web/templates/fragments/header.php" <<'EOF'
<div style="display: flex; justify-content: space-between;">
<h3>This is a test fragment / </h3>
<h3>This can be added to templates so it gets reused</h3>
</div>
EOF

cat > "$SITE_PATH/src/web/templates/mails/welcome.php" <<'EOF'
<h1>This is a test email</h1>
<p>Thank you for using Fast Raven!</p>
EOF

cat > "$SITE_PATH/src/api/Health.php" <<'EOF'
<?php

use FastRaven\Components\Http\Request;
use FastRaven\Components\Http\Response;

use FastRaven\Services\LogService;

return function(Request $request): Response {
    LogService::log("Health API call was processed successfully");
    return Response::new(true, 200);
};
EOF

cat > "$SITE_PATH/src/api/Pong.php" <<'EOF'
<?php

use FastRaven\Components\Http\Request;
use FastRaven\Components\Http\Response;
use FastRaven\Types\SanitizeType;

use Site\PongRepository;

return function(Request $request): Response {
    $question = $request->post("question", SanitizeType::SANITIZED);

    if($question === null) return Response::new(false, 400, "Missing question.");

    $answer = PongRepository::answer($question);
    if($answer === null) return Response::new(false, 400, "Invalid question.");

    return Response::new(true, 200, "Valid question.", ["answer" => $answer]);
};
EOF

cat > "$SITE_PATH/src/lib/PongRepository.php" <<'EOF'
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
EOF

cat > "$SITE_PATH/src/cdn/Logo.php" <<'EOF'
<?php

use FastRaven\Components\Http\Request;
use FastRaven\Components\Http\Response;

return function(Request $request): Response {
    return Response::file(true, "logo.png");
};
EOF

# Placeholder 16x16 PNG served by the /cdn/logo example.
echo "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAGUlEQVR4nGPgFrP4TwlmGDVg1IBRA4aLAQBt51gQxYRs8gAAAABJRU5ErkJggg==" | base64 -d > "$SITE_PATH/storage/uploads/logo.png"

touch "$SITE_PATH/src/web/assets/scss/style.scss"
cat > "$SITE_PATH/src/web/assets/js/main.js" <<'EOF'
$(document).ready(function() {

});
EOF
cat > "$SITE_PATH/src/web/assets/lang/global.csv" <<'EOF'
key,en,es
FR_PING_EXAMPLE,the stylish pong,el pong elegante
EOF

print_success "Site Created Successfully! Proceed with deploy.sh."

exit 0
